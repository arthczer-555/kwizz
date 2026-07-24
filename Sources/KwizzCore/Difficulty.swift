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

    /// Multiplier applied to coin gains. Doubled vs the original 1 / 1.5 / 2.5 so
    /// every mode pays roughly twice as much (the ratios between difficulties are
    /// preserved).
    public var coinMultiplier: Double {
        switch self {
        case .facile: 2.0
        case .normal: 3.0
        case .difficile: 5.0
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

    /// Short "x2 / x3 / x5" label used on the difficulty screen.
    public var gainLabel: String {
        switch self {
        case .facile: "x2"
        case .normal: "x3"
        case .difficile: "x5"
        }
    }
}
