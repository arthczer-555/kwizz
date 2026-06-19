import Foundation

public struct AnswerOutcome: Sendable, Equatable {
    public let wasCorrect: Bool
    public let correctIndex: Int
    public let gainedScore: Int
    public let wasFast: Bool
    /// True when this answer ends the game (last question, or a wrong answer in Survie).
    public let endsGame: Bool
}

/// The pure quiz engine: it owns the score/streak state machine and is fully
/// deterministic given the answers and the remaining-time fractions passed in.
/// All real-time timing lives in the app layer, which keeps this testable.
public struct QuizSession: Sendable {
    public let mode: GameMode
    public let difficulty: Difficulty
    public let categoryID: String?
    public let questions: [Question]

    public private(set) var index = 0
    public private(set) var score = 0
    public private(set) var correctCount = 0
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    public private(set) var fastCount = 0
    public private(set) var perfect = true
    public private(set) var answered = 0
    public private(set) var isOver = false

    /// XP earned so far, accumulated per correct answer using *that question's own*
    /// difficulty. In mixed modes a hard question is worth more than an easy one.
    public private(set) var xpEarned = 0
    /// Sum of the coin multipliers of every correctly answered question, used to
    /// derive an effective (averaged) multiplier for the round's coin reward.
    private var coinMultiplierSum = 0.0

    public init(mode: GameMode, difficulty: Difficulty, categoryID: String?, questions: [Question]) {
        self.mode = mode
        self.difficulty = difficulty
        self.categoryID = categoryID
        self.questions = questions
    }

    public var current: Question? {
        questions.indices.contains(index) ? questions[index] : nil
    }
    public var total: Int { questions.count }
    public var questionNumber: Int { min(index + 1, max(total, 1)) }
    public var progress: Double {
        guard total > 0 else { return 0 }
        return Double(index) / Double(total)
    }

    /// Submit an answer (nil = timed out). `remainingFraction` is timeLeft/timeAllowed.
    @discardableResult
    public mutating func submit(answerIndex: Int?, remainingFraction: Double) -> AnswerOutcome {
        guard let q = current, !isOver else {
            return AnswerOutcome(wasCorrect: false, correctIndex: -1, gainedScore: 0, wasFast: false, endsGame: true)
        }
        answered += 1
        let correct = answerIndex == q.correctIndex
        let fast = remainingFraction > 0.5
        let gained = Scoring.questionScore(correct: correct, remainingFraction: remainingFraction, hasSpeedBonus: mode.hasPerQuestionTimer)
        if correct {
            score += gained
            correctCount += 1
            xpEarned += q.difficulty.xpPerCorrect
            coinMultiplierSum += q.difficulty.coinMultiplier
            streak += 1
            bestStreak = max(bestStreak, streak)
            if fast { fastCount += 1 }
        } else {
            streak = 0
            perfect = false
        }
        let isLast = index >= questions.count - 1
        let ends = (mode.endsOnFirstWrong && !correct) || isLast
        return AnswerOutcome(wasCorrect: correct, correctIndex: q.correctIndex, gainedScore: gained, wasFast: fast, endsGame: ends)
    }

    public mutating func advance() {
        guard !isOver else { return }
        index += 1
        if index >= questions.count { isOver = true }
    }

    public mutating func finish() { isOver = true }

    public func makeResult(previousBest: Int, duelWon: Bool? = nil) -> GameResult {
        let displayTotal = mode.questionCount ?? max(answered, 1)
        let maxS = Scoring.maxScore(questionCount: displayTotal, hasSpeedBonus: mode.hasPerQuestionTimer)
        let frac = maxS > 0 ? Double(score) / Double(maxS) : 0
        // Effective coin multiplier = average of the answered questions' own
        // multipliers, so mixed-difficulty rounds pay out fairly.
        let effectiveMultiplier = correctCount > 0
            ? coinMultiplierSum / Double(correctCount)
            : difficulty.coinMultiplier
        let input = Economy.Input(
            mode: mode, coinMultiplier: effectiveMultiplier, correctCount: correctCount,
            total: displayTotal, perfect: perfect && correctCount > 0, bestStreak: bestStreak,
            fastCount: fastCount, scoreFraction: frac, duelWon: duelWon
        )
        let coins = Economy.coins(input)
        let xp = xpEarned
        let record = mode.tracksRecord && score > previousBest
        return GameResult(
            mode: mode, difficulty: difficulty, categoryID: categoryID,
            score: score, maxScore: maxS, correctCount: correctCount,
            total: displayTotal, bestStreak: bestStreak,
            coinsEarned: coins, xpEarned: xp, isNewRecord: record, duelWon: duelWon
        )
    }
}
