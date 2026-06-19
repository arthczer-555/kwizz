import SwiftUI
import Observation

/// Orchestrates one synchronised online duel: it owns the `DuelTransport`, the pure
/// `DuelMatch`, and the per-question timing. The host coordinates progression
/// (opens each question, decides the winner, advances); every client renders the
/// shared state. The views read its observable state and call `localAnswer`.
@MainActor
@Observable
final class DuelController: Identifiable {
    nonisolated let id = UUID()

    enum Role { case host, guest }
    enum Status: Equatable { case connecting, connected, error(String) }

    let store: PlayerStore
    let role: Role
    private(set) var match: DuelMatch
    private let transport: DuelTransport
    weak var router: Router?

    var status: Status = .connecting
    /// 3·2·1 shown before the first question; nil when not counting down.
    var countdown: Int?
    /// Per-question timer bar, 1 -> 0, animated by SwiftUI.
    var barFraction: Double = 1
    /// The answer the local player tapped for the current question (for highlight).
    var localSelectedIndex: Int?
    /// The local player's rewards once the duel ends.
    private(set) var localResult: GameResult?
    private(set) var localApplied: AppliedResult?

    private let questionSeconds: Double = GameMode.timePerQuestion
    private let revealSeconds: Double = 3.5
    private var questionStartedAt = Date()
    private var deadlineTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var barTask: Task<Void, Never>?
    private var didFinalize = false

    init(store: PlayerStore, router: Router, role: Role, roomCode: String) {
        self.store = store
        self.router = router
        self.role = role
        let me = store.duelPlayer(isHost: role == .host)
        self.match = DuelMatch(roomCode: roomCode, localClientID: store.clientID, host: me)
        self.transport = DuelTransportFactory.make(roomCode: roomCode)
        wire()
    }

    // MARK: Derived for the UI

    var roomCode: String { match.roomCode }
    var players: [DuelPlayer] { match.players }
    var isHost: Bool { role == .host }
    var canStart: Bool { role == .host && status == .connected && match.canStart }
    var isLiveBackend: Bool { DuelTransportFactory.isLive }
    var localClientID: String { store.clientID }

    /// Whether the local player has already answered the current question.
    var localAnswered: Bool {
        guard let i = match.currentIndex else { return false }
        return match.answer(of: store.clientID, at: i) != nil
    }

    // MARK: Lifecycle

    private func wire() {
        transport.onEvent = { [weak self] event in self?.handle(event) }
        transport.onPresence = { [weak self] roster in self?.reconcile(roster) }
        transport.onError = { [weak self] message in self?.status = .error(message) }
    }

    func connect() {
        status = .connecting
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.transport.connect(as: self.store.duelPlayer(isHost: self.role == .host))
                if case .error = self.status {} else { self.status = .connected }
            } catch {
                self.status = .error("Connexion impossible")
            }
        }
    }

    func leave() {
        deadlineTask?.cancel(); revealTask?.cancel(); countdownTask?.cancel(); barTask?.cancel()
        let transport = self.transport
        Task { await transport.disconnect() }
    }

    // MARK: Host starts the round

    func startRound() {
        guard canStart else { return }
        let seed = UInt64.random(in: .min ... .max)
        let questions = store.makeDuelQuestions(seed: seed)
        emit(.start(questions: questions, roundID: UUID().uuidString))
        beginCountdown()
    }

    // MARK: Local answer (from the game view)

    func localAnswer(_ answerIndex: Int?) {
        guard case .question(let index) = match.phase else { return }
        guard match.answer(of: store.clientID, at: index) == nil else { return }
        let q = match.questions[index]
        let correct = answerIndex == q.correctIndex
        let elapsedMs = max(0, Int(Date().timeIntervalSince(questionStartedAt) * 1000))
        localSelectedIndex = answerIndex
        Haptics.impact(correct ? .light : .rigid)
        emit(.answer(clientID: store.clientID,
                     index: index,
                     answer: DuelAnswer(answerIndex: answerIndex, correct: correct, elapsedMs: elapsedMs)))
        if role == .host { hostMaybeClose(index) }
    }

    // MARK: Incoming events / presence

    private func handle(_ event: DuelEvent) {
        match.apply(event)
        switch event {
        case .start: beginCountdown()
        case .beginQuestion: onQuestionOpened()
        case .answer(_, let index, _): if role == .host { hostMaybeClose(index) }
        case .reveal: break
        case .finish: finalizeIfNeeded()
        case .hello: break
        }
    }

    private func reconcile(_ roster: [DuelPlayer]) {
        if let host = roster.first(where: { $0.isHost }) { match.setHost(host.clientID) }
        let known = Set(match.players.map(\.clientID))
        let present = Set(roster.map(\.clientID))
        for player in roster where !known.contains(player.clientID) { match.playerJoined(player) }
        for id in known.subtracting(present) { match.playerLeft(clientID: id) }
        if role == .guest, status == .connected, case .lobby = match.phase,
           !present.contains(match.hostClientID), match.hostClientID != store.clientID {
            status = .error("L'hôte a quitté la partie")
        }
        // A departure may complete the current question.
        if role == .host, let i = match.currentIndex { hostMaybeClose(i) }
    }

    // MARK: Countdown -> first question

    private func beginCountdown() {
        guard countdown == nil else { return }
        countdown = 3
        countdownTask = Task { [weak self] in
            for n in stride(from: 3, through: 1, by: -1) {
                guard let self else { return }
                self.countdown = n
                try? await Task.sleep(for: .seconds(1))
            }
            guard let self else { return }
            self.countdown = nil
            if self.role == .host { self.hostBeginQuestion(0) }
        }
    }

    // MARK: Per-question lifecycle

    private func onQuestionOpened() {
        questionStartedAt = Date()
        localSelectedIndex = nil
        barFraction = 1
        // Drive the bar from real elapsed time, not a single withAnimation. The
        // TimerBar is mounted/unmounted across phases (countdown -> question, and
        // hidden during reveal); a withAnimation fired before it mounts would set
        // the value to 0 instantly, leaving no visible countdown. A periodic tick
        // shows the correct fraction whenever the bar (re)appears.
        barTask?.cancel()
        barTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.questionStartedAt)
                self.barFraction = max(0, min(1, (self.questionSeconds - elapsed) / self.questionSeconds))
                if self.barFraction <= 0 { return }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func hostBeginQuestion(_ index: Int) {
        emit(.beginQuestion(index: index))
        onQuestionOpened()
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.questionSeconds ?? 15))
            guard let self else { return }
            self.hostCloseQuestion(index)
        }
    }

    private func hostMaybeClose(_ index: Int) {
        guard role == .host, match.allAnswered(index) else { return }
        hostCloseQuestion(index)
    }

    private func hostCloseQuestion(_ index: Int) {
        guard role == .host, case .question(let cur) = match.phase, cur == index else { return }
        deadlineTask?.cancel()
        let winner = match.computeWinner(index)
        emit(.reveal(index: index, answers: match.snapshot(index), winner: winner))
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.revealSeconds ?? 3.5))
            guard let self else { return }
            self.hostAfterReveal(index)
        }
    }

    private func hostAfterReveal(_ index: Int) {
        if index + 1 < match.totalQuestions {
            hostBeginQuestion(index + 1)
        } else {
            emit(.finish)
            finalizeIfNeeded()
        }
    }

    // MARK: Rewards

    /// Applies the local player's coins/XP once, when the duel is over, by replaying
    /// its own answers through the existing scoring/economy pipeline. `duelWon` is
    /// true for the player(s) ranked first.
    private func finalizeIfNeeded() {
        guard !didFinalize, case .finished = match.phase else { return }
        didFinalize = true
        let myRank = match.scoreboard.first { $0.player.clientID == store.clientID }?.rank ?? 99
        let won = myRank == 1

        var session = QuizSession(mode: .duel, difficulty: .normal,
                                  categoryID: Category.melange.id, questions: match.questions)
        let totalMs = questionSeconds * 1000
        for i in 0..<match.totalQuestions {
            let answer = match.answer(of: store.clientID, at: i)
            let elapsed = Double(answer?.elapsedMs ?? Int(totalMs))
            let frac = max(0, min(1, (totalMs - elapsed) / totalMs))
            session.submit(answerIndex: answer.flatMap { $0.answerIndex }, remainingFraction: frac)
            session.advance()
        }
        let prev = store.profile.bestScore(mode: .duel, categoryID: Category.melange.id, difficulty: .normal)
        let result = session.makeResult(previousBest: prev, duelWon: won)
        localResult = result
        localApplied = store.finish(result: result)
        if won { Haptics.notify(.success) }
    }

    // MARK: Transport helper

    private func emit(_ event: DuelEvent) {
        match.apply(event)
        let transport = self.transport
        Task { await transport.send(event) }
    }
}
