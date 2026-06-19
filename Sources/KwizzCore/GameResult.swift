import Foundation

/// The outcome of a finished game. Produced by `QuizSession.makeResult`.
public struct GameResult: Identifiable, Sendable {
    public let id: UUID
    public let mode: GameMode
    public let difficulty: Difficulty
    public let categoryID: String?
    public let score: Int
    public let maxScore: Int
    public let correctCount: Int
    public let total: Int
    public let bestStreak: Int
    public let coinsEarned: Int
    public let xpEarned: Int
    public let isNewRecord: Bool
    public let duelWon: Bool?

    public init(mode: GameMode, difficulty: Difficulty, categoryID: String?, score: Int,
                maxScore: Int, correctCount: Int, total: Int, bestStreak: Int,
                coinsEarned: Int, xpEarned: Int, isNewRecord: Bool, duelWon: Bool?) {
        self.id = UUID()
        self.mode = mode
        self.difficulty = difficulty
        self.categoryID = categoryID
        self.score = score
        self.maxScore = maxScore
        self.correctCount = correctCount
        self.total = total
        self.bestStreak = bestStreak
        self.coinsEarned = coinsEarned
        self.xpEarned = xpEarned
        self.isNewRecord = isNewRecord
        self.duelWon = duelWon
    }

    public var scoreFraction: Double {
        maxScore > 0 ? Double(score) / Double(maxScore) : 0
    }

    public var accuracy: Double {
        total > 0 ? Double(correctCount) / Double(total) : 0
    }
}
