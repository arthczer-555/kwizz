import Foundation

/// A row in the live scoreboard or the final podium: a player with their points and
/// rank. Players with the same number of points share a rank.
public struct DuelScore: Codable, Hashable, Sendable, Identifiable {
    public let player: DuelPlayer
    public let points: Int
    public let rank: Int
    /// Total correct answers over the round (tiebreak + recap stat).
    public let correctCount: Int
    /// Whether the player has answered the current question (live only).
    public let answeredCurrent: Bool

    public init(player: DuelPlayer, points: Int, rank: Int, correctCount: Int, answeredCurrent: Bool) {
        self.player = player
        self.points = points
        self.rank = rank
        self.correctCount = correctCount
        self.answeredCurrent = answeredCurrent
    }

    public var id: String { player.clientID }
}

/// The pure state machine for a synchronised online duel (2 to 6 players). Everyone
/// faces the same question at the same time; the point for a question goes to the
/// fastest correct answer (1 point), everyone else 0. Progression is host-coordinated
/// (the app's `DuelController` drives the timers and broadcasts), but all the rules
/// live here and are fully deterministic and testable.
///
/// Lifecycle: `.lobby` → `.countdown` → `.question(0)` → `.reveal(0)` → `.question(1)`
/// → … → `.finished`.
public struct DuelMatch: Sendable {
    public enum Phase: Sendable, Equatable {
        case lobby
        case countdown
        case question(index: Int)   // answering window open
        case reveal(index: Int)     // showing the result of question `index`
        case finished
    }

    public static let minPlayers = 2
    public static let maxPlayers = 16
    /// Au-delà de ce nombre, les écrans passent en présentation compacte (grille
    /// à deux colonnes dans le salon, classement tronqué en cours de partie) :
    /// une liste pleine largeur de 16 lignes ne tient nulle part.
    public static let compactRosterThreshold = 6
    public static let pointForWin = 1

    public let roomCode: String
    public let localClientID: String
    public private(set) var hostClientID: String

    public private(set) var players: [DuelPlayer]      // ordered by join
    public private(set) var phase: Phase
    public private(set) var questions: [Question]
    public private(set) var roundID: String
    /// answers[questionIndex][clientID] = that player's answer.
    public private(set) var answers: [Int: [String: DuelAnswer]]
    /// winners[questionIndex] = clientID who took the point (absent if nobody correct).
    public private(set) var winners: [Int: String]
    /// points[clientID] = questions won.
    public private(set) var points: [String: Int]
    /// Les réglages annoncés par l'hôte (mise + règle de score). nil tant qu'un
    /// invité ne les a pas reçus : on ne peut ni afficher un montant ni refuser
    /// l'entrée avant de les connaître.
    public private(set) var announcedSettings: DuelSettings?
    /// Nombre de joueurs présents au lancement : la cagnotte est figée là, un
    /// départ en cours de manche ne la rétrécit pas.
    public private(set) var stakedPlayerCount: Int = 0

    public init(roomCode: String, localClientID: String, host: DuelPlayer, settings: DuelSettings? = nil) {
        self.roomCode = roomCode
        self.localClientID = localClientID
        self.hostClientID = host.clientID
        self.players = [host]
        self.phase = .lobby
        self.questions = []
        self.roundID = ""
        self.answers = [:]
        self.winners = [:]
        self.points = [:]
        self.announcedSettings = settings
    }

    // MARK: Derived

    public var isHost: Bool { localClientID == hostClientID }
    public var isFull: Bool { players.count >= Self.maxPlayers }
    public var canStart: Bool { isHost && phase == .lobby && players.count >= Self.minPlayers }
    public var totalQuestions: Int { questions.count }

    /// Les réglages effectifs, en retombant sur les valeurs par défaut tant que
    /// l'hôte ne les a pas annoncés (l'UI se fie à `settingsKnown` avant d'afficher
    /// un montant).
    public var settings: DuelSettings { announcedSettings ?? .default }
    /// La mise en pièces que chaque joueur paie pour entrer.
    public var stake: Int { settings.stake }
    /// La règle de score de la partie.
    public var scoring: DuelScoring { settings.scoring }

    /// Le thème des questions annoncé par l'hôte (`Category.melange.id` = tous).
    public var categoryID: String { settings.categoryID }
    /// Vrai dès que les réglages de la partie sont connus de ce client.
    public var settingsKnown: Bool { announcedSettings != nil }
    /// La longueur annoncée de la manche. Avant le lancement c'est la seule
    /// source (les questions n'existent pas encore) ; une fois lancée,
    /// `totalQuestions` fait foi.
    public var plannedQuestionCount: Int { settings.questionCount }
    /// La cagnotte : ce que le vainqueur rafle. Dans le salon elle suit le nombre
    /// de joueurs présents, une fois la manche lancée elle est figée.
    public var pot: Int { stake * max(stakedPlayerCount, players.count, 1) }

    /// Le règlement de fin de partie : mise, joueurs ayant misé, et nombre de
    /// premiers ex æquo qui se partagent la cagnotte.
    public var finalWager: DuelWager {
        let winners = scoreboard.filter { $0.rank == 1 }.count
        return DuelWager(stake: stake,
                         playerCount: max(stakedPlayerCount, 1),
                         winnerCount: max(winners, 1))
    }

    /// The question currently being answered or revealed, if any.
    public var currentIndex: Int? {
        switch phase {
        case .question(let i), .reveal(let i): return i
        default: return nil
        }
    }
    public var currentQuestion: Question? {
        guard let i = currentIndex, questions.indices.contains(i) else { return nil }
        return questions[i]
    }

    public func player(id: String) -> DuelPlayer? { players.first { $0.clientID == id } }

    /// Vrai quand la salle est trop peuplée pour un affichage ligne par ligne.
    public var needsCompactRoster: Bool { players.count > Self.compactRosterThreshold }

    /// The player's answer to a given question, if recorded.
    public func answer(of clientID: String, at index: Int) -> DuelAnswer? {
        answers[index]?[clientID]
    }

    /// Total correct answers a player has given across the round.
    public func correctCount(of clientID: String) -> Int {
        answers.values.reduce(0) { $0 + (($1[clientID]?.correct == true) ? 1 : 0) }
    }

    /// Temps cumulé des bonnes réponses (ms). Départage un classement où tout le
    /// monde marque : à points et bonnes réponses égaux, le plus rapide sur la
    /// manche passe devant, plutôt qu'un tri alphabétique arbitraire.
    public func totalCorrectMs(of clientID: String) -> Int {
        answers.values.reduce(0) { total, round in
            guard let answer = round[clientID], answer.correct else { return total }
            return total + answer.elapsedMs
        }
    }

    /// Live scoreboard (during play) and final podium (when finished): ordered best
    /// first, with shared ranks on equal points.
    public var scoreboard: [DuelScore] {
        let cur = currentIndex
        let ordered = players.sorted { a, b in
            let pa = points[a.clientID] ?? 0, pb = points[b.clientID] ?? 0
            if pa != pb { return pa > pb }
            let ca = correctCount(of: a.clientID), cb = correctCount(of: b.clientID)
            if ca != cb { return ca > cb }
            let ta = totalCorrectMs(of: a.clientID), tb = totalCorrectMs(of: b.clientID)
            if ta != tb { return ta < tb }
            return a.pseudo < b.pseudo
        }
        return ordered.map { p in
            let pts = points[p.clientID] ?? 0
            let rank = 1 + ordered.filter { (points[$0.clientID] ?? 0) > pts }.count
            let answered = cur != nil && answers[cur!]?[p.clientID] != nil
            return DuelScore(player: p, points: pts, rank: rank,
                             correctCount: correctCount(of: p.clientID), answeredCurrent: answered)
        }
    }

    /// Les `limit` meilleurs du classement, en garantissant la présence du joueur
    /// donné : s'il n'est pas dans la tranche, il remplace le dernier affiché. Sert
    /// au tableau de bord en cours de partie, qui ne peut pas tenir 16 lignes sans
    /// pousser la question hors de l'écran.
    public func topScores(limit: Int, alwaysInclude clientID: String) -> [DuelScore] {
        let board = scoreboard
        guard limit > 0, board.count > limit else { return board }
        var top = Array(board.prefix(limit))
        if !top.contains(where: { $0.player.clientID == clientID }),
           let mine = board.first(where: { $0.player.clientID == clientID }) {
            top[top.count - 1] = mine
        }
        return top
    }

    // MARK: Presence (driven by the app's Realtime layer)

    /// Records who the host is, once a guest discovers it from the presence roster.
    public mutating func setHost(_ clientID: String) {
        guard phase == .lobby else { return }
        hostClientID = clientID
    }

    /// Enregistre les réglages décidés par l'hôte. Verrouillés dès le lancement.
    public mutating func setSettings(_ value: DuelSettings) {
        guard phase == .lobby else { return }
        announcedSettings = value
    }

    public mutating func playerJoined(_ p: DuelPlayer) {
        guard phase == .lobby, !isFull else { return }
        guard !players.contains(where: { $0.clientID == p.clientID }) else { return }
        players.append(p)
    }

    public mutating func playerLeft(clientID: String) {
        guard clientID != hostClientID else { return }
        players.removeAll { $0.clientID == clientID }
    }

    // MARK: Events

    public mutating func apply(_ event: DuelEvent) {
        switch event {
        case .hello(let p):
            playerJoined(p)
        case .settings(let value):
            setSettings(value)
        case .start(let questions, let roundID):
            beginRound(questions: questions, roundID: roundID)
        case .beginQuestion(let index):
            openQuestion(index)
        case .answer(let clientID, let index, let answer):
            recordAnswer(clientID: clientID, index: index, answer: answer)
        case .reveal(let index, let snapshot, let winner):
            applyReveal(index: index, snapshot: snapshot, winner: winner)
        case .finish:
            finishMatch()
        case .rematch:
            resetForRematch()
        }
    }

    /// Locks the room and seeds the round. Used by the host (it applies its own
    /// `.start`) and by guests receiving it: a single code path.
    public mutating func beginRound(questions: [Question], roundID: String) {
        guard phase == .lobby else { return }
        self.questions = questions
        self.roundID = roundID
        self.answers = [:]
        self.winners = [:]
        self.points = Dictionary(uniqueKeysWithValues: players.map { ($0.clientID, 0) })
        self.stakedPlayerCount = players.count
        self.phase = .countdown
    }

    /// Opens the answering window for `index`. Reachable from the countdown (first
    /// question) or from the previous reveal (subsequent questions).
    public mutating func openQuestion(_ index: Int) {
        switch phase {
        case .countdown, .reveal:
            guard questions.indices.contains(index) else { return }
            phase = .question(index: index)
        default:
            break
        }
    }

    /// Records a player's answer, once, while its question is open.
    public mutating func recordAnswer(clientID: String, index: Int, answer: DuelAnswer) {
        guard case .question(let cur) = phase, cur == index else { return }
        guard players.contains(where: { $0.clientID == clientID }) else { return }
        if answers[index]?[clientID] != nil { return }
        answers[index, default: [:]][clientID] = answer
    }

    /// Closes a question with the authoritative answer snapshot and winner, and
    /// awards the point. Applied once (guarded by being in `.question(index)`).
    public mutating func applyReveal(index: Int, snapshot: [String: DuelAnswer], winner: String?) {
        guard case .question(let cur) = phase, cur == index else { return }
        answers[index] = snapshot
        // La couronne va toujours à la bonne réponse la plus rapide ; ce sont les
        // points qui dépendent de la règle choisie par l'hôte.
        if let winner { winners[index] = winner }
        for (clientID, answer) in snapshot where answer.correct {
            points[clientID, default: 0] += scoring.pointsPerCorrect
        }
        if let winner { points[winner, default: 0] += scoring.speedBonus }
        phase = .reveal(index: index)
    }

    public mutating func finishMatch() {
        guard phase != .finished else { return }
        phase = .finished
    }

    /// Renvoie la salle au salon pour une revanche : mêmes joueurs, même code,
    /// mêmes réglages, et tout ce qui appartenait à la manche écoulée est effacé.
    /// `stakedPlayerCount` retombe à zéro : entre deux manches plus personne n'a
    /// misé, quitter le salon ne doit donc plus rien coûter.
    public mutating func resetForRematch() {
        guard phase == .finished else { return }
        questions = []
        roundID = ""
        answers = [:]
        winners = [:]
        points = [:]
        stakedPlayerCount = 0
        phase = .lobby
    }

    // MARK: Host-side helpers (used to decide a question's outcome)

    /// Whether every present player has answered `index`.
    public func allAnswered(_ index: Int) -> Bool {
        guard !players.isEmpty else { return false }
        return players.allSatisfy { answers[index]?[$0.clientID] != nil }
    }

    /// The fastest correct answer for `index`, or nil if nobody was correct.
    public func computeWinner(_ index: Int) -> String? {
        let entries = (answers[index] ?? [:]).filter { $0.value.correct }
        return entries.min { a, b in
            if a.value.elapsedMs != b.value.elapsedMs { return a.value.elapsedMs < b.value.elapsedMs }
            return a.key < b.key
        }?.key
    }

    public func snapshot(_ index: Int) -> [String: DuelAnswer] { answers[index] ?? [:] }
}
