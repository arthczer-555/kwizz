import Foundation

/// The three difficulty levels. Difficulty changes the reward multipliers (and,
/// in Entraînement, which questions are drawn), but never the time pressure nor
/// the raw score scale (score stays comparable).
public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case facile
    case normal
    case difficile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .facile: "Facile"
        case .normal: "Normal"
        case .difficile: "Difficile"
        }
    }

    /// Multiplier applied to coin gains.
    public var coinMultiplier: Double {
        switch self {
        case .facile: 1.0
        case .normal: 1.5
        case .difficile: 2.5
        }
    }

    /// XP granted per correct answer.
    public var xpPerCorrect: Int {
        switch self {
        case .facile: 5
        case .normal: 10
        case .difficile: 20
        }
    }

    /// Short "x1 / x1.5 / x2.5" label used on the difficulty screen.
    public var gainLabel: String {
        switch self {
        case .facile: "x1"
        case .normal: "x1.5"
        case .difficile: "x2.5"
        }
    }
}
