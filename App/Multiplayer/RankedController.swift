import SwiftUI
import Observation

/// Drives one ranked 1v1 match. Unlike `DuelController` (peer-broadcast, host
/// arbitrates), this is **server-authoritative**: the client only POSTs its answer
/// and reads the authoritative `ranked_matches` row (by polling). Scores, the
/// per-question winner and the ELO are decided by the Edge Functions; the client
/// reuses the pure `DuelMatch` purely to render the synchronised question flow.
@MainActor
@Observable
final class RankedController: Identifiable {
    nonisolated let id = UUID()

    enum Stage: Equatable { case searching, active, error(String) }
    enum Outcome: Equatable { case won, lost, draw }

    let store: PlayerStore
    weak var router: Router?

    private(set) var stage: Stage = .searching
    private(set) var match: DuelMatch?
    private(set) var me: DuelPlayer?
    private(set) var opponent: DuelPlayer?

    /// 3·2·1 before the first question; nil otherwise.
    var countdown: Int?
    var barFraction: Double = 1
    var localSelectedIndex: Int?

    /// Authoritative scores from the latest row, mapped to me/opponent.
    private(set) var scoreMe = 0
    private(set) var scoreOpponent = 0

    /// Rating + tier movement, for the results screen.
    private(set) var ratingBefore = Elo.start
    private(set) var ratingAfter: Int?
    private(set) var ratingDelta: Int?
    var tierBefore: RankTier { RankTier.tier(forRating: ratingBefore) }
    var tierAfter: RankTier? { ratingAfter.map { RankTier.tier(forRating: $0) } }

    private(set) var localResult: GameResult?
    private(set) var localApplied: AppliedResult?
    private(set) var outcome: Outcome = .lost

    private let localClientID: String
    private let myPseudo: String
    private let myAccentHex: String
    private var matchId: String?
    private var role: String = "a"   // "a" = player_a, "b" = player_b

    private let questionSeconds: Double = GameMode.timePerQuestion
    private let revealSeconds: Double = 3.5
    private var questionStartedAt = Date()
    private var localIndex = -1       // question currently shown locally
    /// Question the server is on when we first read the row. Normally 0, mais si
    /// on rejoint un match déjà entamé (poll tardif, reprise), ouvrir la question 0
    /// faisait rejeter toutes nos réponses par `ranked-answer` (« stale, ignore »)
    /// et l'écran restait figé sur une question morte.
    private var joinIndex = 0
    private var started = false
    private var revealing = false
    private var didFinalize = false

    private var matchmakingTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var barTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?

    init(store: PlayerStore, router: Router) {
        self.store = store
        self.router = router
        self.localClientID = SupabaseService.shared.userID ?? store.clientID
        self.myPseudo = store.profile.pseudo
        self.myAccentHex = store.accent.hex
    }

    // MARK: Derived for the UI

    var isFinished: Bool { if case .finished = match?.phase { return true }; return false }
    var isReveal: Bool { if case .reveal = match?.phase { return true }; return false }
    var currentIndex: Int { match?.currentIndex ?? 0 }
    var totalQuestions: Int { match?.totalQuestions ?? 7 }
    var currentQuestion: Question? { match?.currentQuestion }
    var iWon: Bool { localResult?.duelWon == true }

    var localAnswered: Bool {
        guard let match, let i = match.currentIndex else { return false }
        return match.answer(of: localClientID, at: i) != nil
    }

    // MARK: Matchmaking

    func startSearch() {
        stage = .searching
        matchmakingTask = Task { [weak self] in
            guard let self else { return }
            await SupabaseService.shared.start()
            if let stats = await SupabaseService.shared.myRankedStats() {
                self.ratingBefore = stats.rating
            }
            // Poll the enqueue function until matched, or give up after ~60 s.
            for _ in 0..<30 {
                if Task.isCancelled { return }
                let result = await SupabaseService.shared.enqueueRanked(pseudo: self.myPseudo, accentHex: self.myAccentHex)
                switch result {
                case .matched(let id, let role):
                    self.beginMatch(id: id, role: role)
                    return
                case .queued:
                    try? await Task.sleep(for: .seconds(2))
                case .failed(let reason):
                    self.stage = .error("Connexion impossible\n\(reason)")
                    return
                }
            }
            await SupabaseService.shared.cancelRanked()
            self.stage = .error("Aucun adversaire trouvé")
        }
    }

    private func beginMatch(id: String, role: String) {
        matchId = id
        self.role = role
        stage = .active
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let mid = self.matchId else { return }
                if let row = await SupabaseService.shared.fetchRankedMatch(id: mid) {
                    self.reconcile(row)
                    if row.status != "playing" { return }   // finished/forfeit: stop polling
                }
                try? await Task.sleep(for: .milliseconds(1200))
            }
        }
    }

    // MARK: Reconcile the authoritative row -> local DuelMatch

    private func reconcile(_ row: SupabaseService.RankedMatchRow) {
        // Map authoritative scores to me/opponent.
        if role == "a" { scoreMe = row.score_a; scoreOpponent = row.score_b }
        else { scoreMe = row.score_b; scoreOpponent = row.score_a }

        if !started {
            started = true
            buildMatch(from: row)
            beginCountdown()
            return
        }

        if row.status == "playing" {
            if row.current_index > localIndex, !revealing {
                revealThenAdvance(to: row.current_index)
            }
        } else if !didFinalize {  // finished or forfeit
            revealThenFinish(row)
        }
    }

    private func buildMatch(from row: SupabaseService.RankedMatchRow) {
        let a = DuelPlayer(clientID: row.player_a, pseudo: row.pseudo_a ?? "Joueur 1", accentHex: row.accent_a, isHost: true)
        let b = DuelPlayer(clientID: row.player_b, pseudo: row.pseudo_b ?? "Joueur 2", accentHex: row.accent_b, isHost: false)
        var m = DuelMatch(roomCode: row.id, localClientID: localClientID, host: a)
        m.playerJoined(b)
        m.beginRound(questions: row.questions, roundID: row.id)
        match = m
        joinIndex = min(max(0, row.current_index), max(0, row.questions.count - 1))
        me = localClientID == row.player_a ? a : b
        opponent = localClientID == row.player_a ? b : a
    }

    // MARK: Countdown -> first question

    private func beginCountdown() {
        countdown = 3
        countdownTask = Task { [weak self] in
            for n in stride(from: 3, through: 1, by: -1) {
                guard let self else { return }
                self.countdown = n
                try? await Task.sleep(for: .seconds(1))
            }
            guard let self else { return }
            self.countdown = nil
            self.openQuestion(self.joinIndex)
        }
    }

    private func openQuestion(_ index: Int) {
        guard var m = match, m.questions.indices.contains(index) else { return }
        m.openQuestion(index)
        match = m
        localIndex = index
        questionStartedAt = Date()
        localSelectedIndex = nil
        startBar()
    }

    private func startBar() {
        barFraction = 1
        barTask?.cancel()
        barTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.questionStartedAt)
                self.barFraction = max(0, min(1, (self.questionSeconds - elapsed) / self.questionSeconds))
                if self.barFraction <= 0 {
                    // Local timeout: report a null answer so the server can resolve.
                    if !self.localAnswered { self.localAnswer(nil) }
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    // MARK: Local answer

    func localAnswer(_ answerIndex: Int?) {
        guard var m = match, case .question(let index) = m.phase, index == localIndex else { return }
        guard m.answer(of: localClientID, at: index) == nil else { return }
        let q = m.questions[index]
        let correct = answerIndex == q.correctIndex
        let elapsedMs = max(0, Int(Date().timeIntervalSince(questionStartedAt) * 1000))
        localSelectedIndex = answerIndex
        // Tap = retour neutre : le verdict est joué à la révélation (cf.
        // `applyRevealForLocal`), sinon la vibration devance la correction.
        if answerIndex != nil { Haptics.impact(.soft) }
        m.recordAnswer(clientID: localClientID, index: index,
                       answer: DuelAnswer(answerIndex: answerIndex, correct: correct, elapsedMs: elapsedMs))
        match = m
        let mid = matchId
        Task {
            if let mid {
                await SupabaseService.shared.submitRankedAnswer(
                    matchId: mid, questionIndex: index, answerIndex: answerIndex, elapsedMs: elapsedMs)
            }
        }
    }

    // MARK: Reveal -> advance / finish

    private func revealThenAdvance(to newIndex: Int) {
        revealing = true
        revealTask = Task { [weak self] in
            guard let self, let mid = self.matchId else { return }
            await self.applyRevealForLocal(matchId: mid)
            try? await Task.sleep(for: .seconds(self.revealSeconds))
            guard !Task.isCancelled else { return }
            self.revealing = false
            self.openQuestion(newIndex)
        }
    }

    private func revealThenFinish(_ row: SupabaseService.RankedMatchRow) {
        revealing = true
        revealTask = Task { [weak self] in
            guard let self, let mid = self.matchId else { return }
            await self.applyRevealForLocal(matchId: mid)
            try? await Task.sleep(for: .seconds(self.revealSeconds))
            guard !Task.isCancelled else { return }
            self.finalize(row)
        }
    }

    /// Fetches the authoritative answers for the locally-shown question and applies
    /// the reveal (winner = fastest correct), so the recap matches the server.
    private func applyRevealForLocal(matchId mid: String) async {
        guard var m = match, case .question(let index) = m.phase else { return }
        let rows = await SupabaseService.shared.fetchRankedAnswers(matchId: mid)
        var snapshot: [String: DuelAnswer] = [:]
        for r in rows where r.question_index == index {
            snapshot[r.user_id] = DuelAnswer(answerIndex: r.answer_index, correct: r.correct, elapsedMs: r.elapsed_ms)
        }
        let winner = snapshot.filter { $0.value.correct }.min { lhs, rhs in
            lhs.value.elapsedMs != rhs.value.elapsedMs ? lhs.value.elapsedMs < rhs.value.elapsedMs : lhs.key < rhs.key
        }?.key
        m.applyReveal(index: index, snapshot: snapshot, winner: winner)
        match = m
        // La correction s'affiche maintenant : c'est ici que le verdict se sent.
        if let mine = m.answer(of: localClientID, at: index) {
            Haptics.impact(mine.correct ? .light : .rigid)
        }
        barTask?.cancel()
    }

    // MARK: Finalize (rewards + rating)

    private func finalize(_ row: SupabaseService.RankedMatchRow) {
        guard !didFinalize, var m = match else { return }
        didFinalize = true
        m.finishMatch()
        match = m

        let myDelta = role == "a" ? (row.delta_a ?? 0) : (row.delta_b ?? 0)
        ratingDelta = myDelta
        ratingAfter = max(0, ratingBefore + myDelta)
        let isDraw = row.winner == nil && row.score_a == row.score_b
        let won = row.winner == localClientID
        outcome = isDraw ? .draw : (won ? .won : .lost)
        // nil on a draw so the economy applies no stake (win/loss only otherwise).
        let duelWon: Bool? = isDraw ? nil : won

        // Replay the local answers through the economy, like the friend duel.
        var session = QuizSession(mode: .duel, difficulty: .normal,
                                  categoryID: Category.melange.id, questions: m.questions)
        let totalMs = questionSeconds * 1000
        for i in 0..<m.totalQuestions {
            let answer = m.answer(of: localClientID, at: i)
            let elapsed = Double(answer?.elapsedMs ?? Int(totalMs))
            let frac = max(0, min(1, (totalMs - elapsed) / totalMs))
            session.submit(answerIndex: answer.flatMap { $0.answerIndex }, remainingFraction: frac)
            session.advance()
        }
        let prev = store.profile.bestScore(mode: .duel, categoryID: Category.melange.id, difficulty: .normal)
        // La ligue se joue SANS mise : ce qui est en jeu, c'est l'ELO, pas le
        // porte-monnaie. Une mise à 0 (plutôt que `duelWon: nil`, qui signifie
        // « match nul ») annule le règlement en pièces tout en gardant la
        // victoire/défaite exacte pour l'écran de résultats.
        let noWager = DuelWager(stake: 0, playerCount: 2, winnerCount: 1)
        let result = session.makeResult(previousBest: prev, duelWon: duelWon, duelWager: noWager)
        localResult = result
        localApplied = store.finish(result: result)
        Haptics.notify(outcome == .won ? .success : .warning)
    }

    // MARK: Leave / forfeit

    func forfeit() {
        let mid = matchId
        let active = stage == .active && !isFinished
        cleanup()
        Task {
            if active, let mid { await SupabaseService.shared.forfeitRanked(matchId: mid) }
            else { await SupabaseService.shared.cancelRanked() }
        }
    }

    func cleanup() {
        matchmakingTask?.cancel()
        pollTask?.cancel()
        barTask?.cancel()
        countdownTask?.cancel()
        revealTask?.cancel()
    }
}
