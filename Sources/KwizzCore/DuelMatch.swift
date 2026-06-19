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
    public static let maxPlayers = 6
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

    public init(roomCode: String, localClientID: String, host: DuelPlayer) {
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
    }

    // MARK: Derived

    public var isHost: Bool { localClientID == hostClientID }
    public var isFull: Bool { players.count >= Self.maxPlayers }
    public var canStart: Bool { isHost && phase == .lobby && players.count >= Self.minPlayers }
    public var totalQuestions: Int { questions.count }

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

    /// The player's answer to a given question, if recorded.
    public func answer(of clientID: String, at index: Int) -> DuelAnswer? {
        answers[index]?[clientID]
    }

    /// Total correct answers a player has given across the round.
    public func correctCount(of clientID: String) -> Int {
        answers.values.reduce(0) { $0 + (($1[clientID]?.correct == true) ? 1 : 0) }
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

    // MARK: Presence (driven by the app's Realtime layer)

    /// Records who the host is, once a guest discovers it from the presence roster.
    public mutating func setHost(_ clientID: String) {
        guard phase == .lobby else { return }
        hostClientID = clientID
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
        if let winner {
            winners[index] = winner
            points[winner, default: 0] += Self.pointForWin
        }
        phase = .reveal(index: index)
    }

    public mutating func finishMatch() {
        guard phase != .finished else { return }
        phase = .finished
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
