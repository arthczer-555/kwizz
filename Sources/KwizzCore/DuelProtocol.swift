import Foundation

/// Identity of a player in an online duel room. The `pseudo` comes from the local
/// profile and `clientID` is a per-device UUID generated at launch, so duels need
/// no account. `accentHex` lets the live scoreboard colour each player.
public struct DuelPlayer: Identifiable, Codable, Hashable, Sendable {
    public let clientID: String
    public let pseudo: String
    public let accentHex: String?
    /// True for the player who created the room. Carried in presence so guests can
    /// discover who the host is (and detect the host leaving).
    public let isHost: Bool

    public init(clientID: String, pseudo: String, accentHex: String? = nil, isHost: Bool = false) {
        self.clientID = clientID
        self.pseudo = pseudo
        self.accentHex = accentHex
        self.isHost = isHost
    }

    public var id: String { clientID }
}

/// One player's answer to one question. `answerIndex` is nil on a timeout. `elapsedMs`
/// is the time from the question appearing to the tap, used to find who was fastest.
public struct DuelAnswer: Codable, Hashable, Sendable {
    public let answerIndex: Int?
    public let correct: Bool
    public let elapsedMs: Int

    public init(answerIndex: Int?, correct: Bool, elapsedMs: Int) {
        self.answerIndex = answerIndex
        self.correct = correct
        self.elapsedMs = elapsedMs
    }
}

/// Messages broadcast on the room channel. Progression is host-coordinated so the
/// round stays in lock-step (everyone faces the same question at the same time) and
/// the "first correct" winner is decided once, by the host, then mirrored to all.
public enum DuelEvent: Codable, Sendable, Equatable {
    /// Sent on entry to announce identity (enriches presence).
    case hello(player: DuelPlayer)
    /// Host only: announces the room's settings (stake and scoring rule). Re-sent on
    /// every roster change so a player joining late learns what the party costs and
    /// how points are won.
    case settings(DuelSettings)
    /// Host only: locks the room and hands everyone the exact same questions.
    case start(questions: [Question], roundID: String)
    /// Host only: opens the answering window for question `index` for everyone.
    case beginQuestion(index: Int)
    /// A player answered question `index`. Broadcast live so others see who has played.
    case answer(clientID: String, index: Int, answer: DuelAnswer)
    /// Host only: closes question `index`. Carries the authoritative snapshot of every
    /// player's answer and the winner (the fastest correct one, nil if nobody).
    case reveal(index: Int, answers: [String: DuelAnswer], winner: String?)
    /// Host only: the last question is done; go to the podium.
    case finish
    /// Hôte seulement : on repart pour une manche. La salle revient au salon avec
    /// les joueurs encore connectés et les mêmes réglages ; rien n'est recréé,
    /// c'est le même canal et le même code qui resservent.
    case rematch
}
