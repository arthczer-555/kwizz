import Foundation

/// Builds the Daily Challenge grid. Deterministic: the same calendar day yields
/// the same questions for everyone, with no server involved.
public enum DailyChallenge {
    public static let questionCount = 10

    /// A compact integer key for a calendar day, e.g. 2026_06_05 -> 20260605.
    public static func day(year: Int, month: Int, day: Int) -> Int {
        year * 10000 + month * 100 + day
    }

    public static func seed(day: Int) -> UInt64 {
        let base = UInt64(bitPattern: Int64(day))
        return (base &* 0x9E3779B97F4A7C15) ^ 0xD1B54A32D192ED03
    }

    public static func questions(from all: [Question], day: Int, count: Int = questionCount) -> [Question] {
        guard !all.isEmpty else { return [] }
        var gen = SeededGenerator(seed: seed(day: day))
        let shuffled = all.shuffled(using: &gen).map { $0.shuffledAnswers(using: &gen) }
        if shuffled.count >= count { return Array(shuffled.prefix(count)) }
        var out = shuffled
        var i = 0
        while out.count < count {
            out.append(shuffled[i % shuffled.count])
            i += 1
        }
        return out
    }
}
