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
    private let revealSeconds: Double = GameMode.duelRevealSeconds
    private var questionStartedAt = Date()
    private var deadlineTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var barTask: Task<Void, Never>?
    private var didFinalize = false
    /// L'hôte a disparu de la présence. La manche ne peut plus avancer (c'est lui
    /// qui pilote les timers), donc quitter ne doit pas coûter la mise.
    private var hostGone = false
    /// La mise est engagée en connaissance de cause. L'hôte a fixé le montant
    /// lui-même sur l'écran de configuration : la sienne est confirmée d'office.
    /// Un invité, lui, découvre la mise en entrant dans le salon et doit la
    /// confirmer avant que la partie puisse l'engager.
    private(set) var stakeConfirmed: Bool

    /// `settings` vient de l'écran de configuration pour l'hôte ; un invité passe
    /// nil et les apprend par l'événement `.settings` que l'hôte diffuse.
    init(store: PlayerStore, router: Router, role: Role, roomCode: String, settings: DuelSettings? = nil) {
        self.store = store
        self.router = router
        self.role = role
        self.stakeConfirmed = role == .host
        let me = store.duelPlayer(isHost: role == .host)
        let initial: DuelSettings? = role == .host
            ? (settings ?? DuelSettings(stake: DuelWager.suggestedStake(coins: store.profile.coins),
                                        scoring: DuelSettings.default.scoring))
            : nil
        self.match = DuelMatch(roomCode: roomCode, localClientID: store.clientID, host: me, settings: initial)
        self.transport = DuelTransportFactory.make(roomCode: roomCode)
        wire()
    }

    // MARK: Derived for the UI

    var roomCode: String { match.roomCode }
    var players: [DuelPlayer] { match.players }
    var isHost: Bool { role == .host }
    var canStart: Bool { role == .host && status == .connected && match.canStart && canAffordStake }
    var isLiveBackend: Bool { DuelTransportFactory.isLive }
    var localClientID: String { store.clientID }

    /// Le porte-monnaie local, lu par le salon pour griser les mises trop chères.
    var coins: Int { store.profile.coins }
    /// La mise par joueur choisie par l'hôte.
    var stake: Int { match.stake }
    /// Faux tant qu'un invité n'a pas reçu les réglages de l'hôte.
    var settingsKnown: Bool { match.settingsKnown }
    /// La règle de score choisie par l'hôte.
    var scoring: DuelScoring { match.scoring }
    /// Le thème des questions choisi par l'hôte (`Category.melange.id` = tous).
    var categoryID: String { match.categoryID }
    /// Ce thème, tel qu'on l'affiche dans le salon et la partie.
    var themeLabel: String { match.settings.themeLabel }
    /// La longueur de la manche : celle réellement distribuée si elle est lancée,
    /// sinon celle annoncée dans les réglages.
    var questionCount: Int { match.totalQuestions > 0 ? match.totalQuestions : match.plannedQuestionCount }
    /// L'hôte peut relancer une manche avec la salle telle qu'elle est.
    var canRematch: Bool { role == .host && status == .connected && match.phase == .finished }
    /// La cagnotte que le vainqueur rafle : mise × nombre de joueurs.
    var pot: Int { match.pot }
    /// Le joueur local a-t-il de quoi payer la mise annoncée ?
    var canAffordStake: Bool { coins >= match.stake }
    /// Pièces manquantes pour entrer dans la partie (0 si elle est payable).
    var missingCoins: Int { max(0, match.stake - coins) }
    /// Le solde une fois la mise payée, tel qu'annoncé dans la confirmation.
    var coinsAfterStake: Int { max(0, coins - match.stake) }
    /// Faut-il demander à l'invité de confirmer sa mise ? Seulement dans le salon,
    /// une fois les réglages de l'hôte reçus, et si la partie coûte des pièces :
    /// une partie amicale n'engage rien, il n'y a rien à confirmer.
    var needsStakeConfirmation: Bool {
        role == .guest && !stakeConfirmed && status == .connected
            && match.phase == .lobby && match.settingsKnown && match.stake > 0 && canAffordStake
    }

    /// L'invité accepte d'engager sa mise : le salon lui est rendu.
    func confirmStake() {
        guard !stakeConfirmed else { return }
        stakeConfirmed = true
        Haptics.impact(.light)
    }

    /// L'invité refuse la mise : il sort du salon avant d'avoir rien engagé
    /// (personne n'a misé tant que la manche n'est pas lancée).
    func declineStake() {
        leave()
        router?.activeDuel = nil
    }

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
                // L'hôte diffuse les réglages arrêtés à la création dès qu'il est
                // en ligne, puis à chaque arrivée : ils ne changent plus, mais un
                // invité qui arrive doit encore les apprendre.
                if self.role == .host { await self.transport.send(.settings(self.match.settings)) }
            } catch {
                self.status = .error("Connexion impossible")
            }
        }
    }

    func leave() {
        deadlineTask?.cancel(); revealTask?.cancel(); countdownTask?.cancel(); barTask?.cancel()
        forfeitIfNeeded()
        let transport = self.transport
        Task { await transport.disconnect() }
    }

    // MARK: Host starts the round

    func startRound() {
        guard canStart else { return }
        // Dernier rappel de la mise avant de verrouiller : un invité dont le
        // `.settings` se serait perdu joue sinon avec un mauvais montant en tête.
        emit(.settings(match.settings))
        let seed = UInt64.random(in: .min ... .max)
        let questions = store.makeDuelQuestions(seed: seed, count: match.settings.questionCount,
                                                categoryID: match.categoryID)
        emit(.start(questions: questions, roundID: UUID().uuidString))
        beginCountdown()
    }

    // MARK: Revanche

    /// L'hôte renvoie la salle au salon : même code, même canal, mêmes joueurs
    /// encore connectés. Rien n'est recréé, donc personne n'a de code à ressaisir ;
    /// il ne reste qu'à relancer. Les réglages sont réannoncés dans la foulée pour
    /// que chacun revérifie qu'il peut encore payer la mise.
    func requestRematch() {
        guard canRematch else { return }
        emit(.rematch)
        // `emit` ne repasse pas par `handle`, donc l'hôte remet lui-même son état
        // local à neuf, comme les invités le feront en recevant l'événement.
        resetForRematch()
        emit(.settings(match.settings))
        Haptics.impact(.light)
    }

    /// Remet l'état local à neuf après une revanche : la manche précédente a déjà
    /// été payée et créditée, celle qui vient repart de zéro.
    private func resetForRematch() {
        deadlineTask?.cancel(); revealTask?.cancel(); countdownTask?.cancel(); barTask?.cancel()
        countdown = nil
        barFraction = 1
        localSelectedIndex = nil
        localResult = nil
        localApplied = nil
        didFinalize = false
        // La manche a pu retirer du salon un joueur sur un simple hoquet de
        // présence. On se réannonce pour forcer une resynchro : la revanche doit
        // repartir avec la salle réellement connectée, pas avec ce qu'il en restait.
        let transport = self.transport
        let me = store.duelPlayer(isHost: role == .host)
        Task { await transport.updatePresence(me) }
        // Une revanche est une nouvelle mise : l'invité la reconfirme, il doit
        // pouvoir s'arrêter là plutôt que d'enchaîner les paris par inertie.
        stakeConfirmed = role == .host
        enforceStakeAffordability()
    }

    // MARK: Local answer (from the game view)

    func localAnswer(_ answerIndex: Int?) {
        guard case .question(let index) = match.phase else { return }
        guard match.answer(of: store.clientID, at: index) == nil else { return }
        let q = match.questions[index]
        let correct = answerIndex == q.correctIndex
        let elapsedMs = max(0, Int(Date().timeIntervalSince(questionStartedAt) * 1000))
        localSelectedIndex = answerIndex
        // Tap = retour neutre. Le verdict (léger si bon, sec si faux) attend la
        // révélation, sinon la vibration spoile la correction.
        if answerIndex != nil { Haptics.impact(.soft) }
        emit(.answer(clientID: store.clientID,
                     index: index,
                     answer: DuelAnswer(answerIndex: answerIndex, correct: correct, elapsedMs: elapsedMs)))
        if role == .host { hostMaybeClose(index) }
    }

    // MARK: Incoming events / presence

    private func handle(_ event: DuelEvent) {
        // Manche lancée avant que l'invité ait confirmé sa mise : il sort du salon
        // sans rien payer plutôt que d'être embarqué dans un pari qu'il n'a pas
        // accepté. L'événement n'est pas appliqué, donc rien n'est misé de son côté.
        if case .start = event, needsStakeConfirmation {
            eject("La manche a été lancée avant que tu confirmes ta mise")
            return
        }
        match.apply(event)
        switch event {
        case .settings: enforceStakeAffordability()
        case .start: beginCountdown()
        case .beginQuestion: onQuestionOpened()
        case .answer(_, let index, _): if role == .host { hostMaybeClose(index) }
        case .reveal(let index, _, _): hapticForLocalReveal(index)
        case .finish: finalizeIfNeeded()
        case .rematch: resetForRematch()
        case .hello: break
        }
    }

    private func reconcile(_ roster: [DuelPlayer]) {
        if let host = roster.first(where: { $0.isHost }) { match.setHost(host.clientID) }
        let known = Set(match.players.map(\.clientID))
        let present = Set(roster.map(\.clientID))
        for player in roster where !known.contains(player.clientID) { match.playerJoined(player) }
        for id in known.subtracting(present) { match.playerLeft(clientID: id) }
        if role == .guest, status == .connected,
           !present.contains(match.hostClientID), match.hostClientID != store.clientID {
            hostGone = true
            if case .lobby = match.phase { status = .error("L'hôte a quitté la partie") }
        }
        // Salle déjà pleine : ce client est le joueur de trop, les autres ne le
        // verront jamais. Mieux vaut le dire que le laisser jouer dans le vide.
        let others = roster.filter { $0.clientID != store.clientID }.count
        if role == .guest, case .lobby = match.phase, others >= DuelMatch.maxPlayers {
            eject("La partie est complète (\(DuelMatch.maxPlayers) joueurs maximum)")
            return
        }
        // A departure may complete the current question.
        if role == .host, let i = match.currentIndex { hostMaybeClose(i) }
        // Réannonce à chaque mouvement du salon : un joueur qui arrive après coup
        // apprend ainsi combien coûte la partie et comment on y marque.
        if role == .host, case .lobby = match.phase, status != .connecting {
            let transport = self.transport
            let settings = match.settings
            Task { await transport.send(.settings(settings)) }
        }
    }

    /// Un invité qui n'a pas les pièces de la mise ne peut pas participer : on le
    /// sort du salon avec un message clair plutôt que de le laisser jouer à crédit.
    private func enforceStakeAffordability() {
        guard role == .guest, case .lobby = match.phase, match.settingsKnown else { return }
        guard !canAffordStake else { return }
        eject("Pas assez de pièces : cette partie coûte \(match.stake) pièces, il t'en manque \(missingCoins)")
    }

    /// Sort le joueur du salon avec un motif affiché en clair. Le salon rend le
    /// message en panneau rouge avec un bouton « Quitter ».
    private func eject(_ reason: String) {
        guard case .error = status else {
            status = .error(reason)
            Haptics.notify(.error)
            let transport = self.transport
            Task { await transport.disconnect() }
            return
        }
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
        // `emit` applique l'événement sans passer par `handle` : l'hôte doit
        // déclencher son propre retour haptique de révélation ici.
        hapticForLocalReveal(index)
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.revealSeconds ?? 3.5))
            guard let self else { return }
            self.hostAfterReveal(index)
        }
    }

    /// Retour haptique de la correction, joué au moment où elle s'affiche.
    private func hapticForLocalReveal(_ index: Int) {
        guard let mine = match.answer(of: store.clientID, at: index) else { return }
        Haptics.impact(mine.correct ? .light : .rigid)
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
        let wager = match.finalWager

        // Le thème joué, pas « mélange » par défaut : les records et les stats par
        // thème du profil doivent créditer la catégorie réellement jouée.
        var session = QuizSession(mode: .duel, difficulty: .normal,
                                  categoryID: match.categoryID, questions: match.questions)
        let totalMs = questionSeconds * 1000
        for i in 0..<match.totalQuestions {
            let answer = match.answer(of: store.clientID, at: i)
            let elapsed = Double(answer?.elapsedMs ?? Int(totalMs))
            let frac = max(0, min(1, (totalMs - elapsed) / totalMs))
            session.submit(answerIndex: answer.flatMap { $0.answerIndex }, remainingFraction: frac)
            session.advance()
        }
        let prev = store.profile.bestScore(mode: .duel, categoryID: match.categoryID, difficulty: .normal)
        let result = session.makeResult(previousBest: prev, duelWon: won, duelWager: wager)
        localResult = result
        localApplied = store.finish(result: result)
        if won { Haptics.notify(.success) }
    }

    /// Quitter une manche en cours coûte la mise : sans ça, il suffirait de sortir
    /// avant le podium pour ne jamais perdre de pièces.
    private func forfeitIfNeeded() {
        guard !didFinalize, match.stakedPlayerCount > 0, match.stake > 0 else { return }
        guard match.phase != .finished else { return }
        // Manche abandonnée par l'hôte : personne ne peut plus la finir, ce serait
        // punir l'invité pour un départ qui n'est pas le sien.
        guard !hostGone else { return }
        didFinalize = true
        store.addCoins(-match.stake)
    }

    // MARK: Transport helper

    private func emit(_ event: DuelEvent) {
        match.apply(event)
        let transport = self.transport
        Task { await transport.send(event) }
    }
}
