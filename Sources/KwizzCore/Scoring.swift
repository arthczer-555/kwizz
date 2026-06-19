import Foundation

/// Arcade scoring. A correct answer is worth 100 points, plus up to +100 of
/// speed bonus depending on the time left (only when the mode has a per-question
/// timer). A perfect, all-fast 20-question Classique game tops out at 4000.
public enum Scoring {
    public static let baseCorrect = 100
    public static let maxSpeedBonus = 100

    /// `remainingFraction` is timeLeft / timeAllowed, clamped to 0...1.
    public static func questionScore(correct: Bool, remainingFraction: Double, hasSpeedBonus: Bool) -> Int {
        guard correct else { return 0 }
        guard hasSpeedBonus else { return baseCorrect }
        let f = min(max(remainingFraction, 0), 1)
        let bonus = Int((Double(maxSpeedBonus) * f).rounded())
        return baseCorrect + bonus
    }

    /// Highest reachable score for a given number of questions. Modes without a
    /// per-question timer have no speed bonus, so their ceiling is lower.
    public static func maxScore(questionCount: Int, hasSpeedBonus: Bool = true) -> Int {
        max(0, questionCount) * (baseCorrect + (hasSpeedBonus ? maxSpeedBonus : 0))
    }
}
