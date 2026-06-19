import Foundation

/// Competitive rating for the ranked 1v1 league (Système A). Pure and testable.
/// The authoritative update runs server-side (Edge Function); this mirrors it so
/// the client can preview a rating change and derive the displayed tier.
public enum Elo {
    /// K=20 -> exactly +10 / -10 at equal rating; more/less with the rating gap
    /// (beat a stronger opponent = more points), like chess.com.
    public static let kFactor = 20
    public static let start = 1000

    /// Probability that `rating` beats `opponent` (logistic, 400-point scale).
    public static func expectedScore(rating: Int, opponent: Int) -> Double {
        1.0 / (1.0 + pow(10.0, Double(opponent - rating) / 400.0))
    }

    /// New rating after a decided match (`won` = victory). Floored at 0.
    public static func updatedRating(rating: Int, opponent: Int, won: Bool, k: Int = kFactor) -> Int {
        let actual = won ? 1.0 : 0.0
        let delta = Double(k) * (actual - expectedScore(rating: rating, opponent: opponent))
        return max(0, Int((Double(rating) + delta).rounded()))
    }
}

/// The seven visible ranks, derived from an Elo rating.
public enum RankTier: Int, CaseIterable, Sendable {
    case bronze, argent, or, platine, diamant, master, grandMaster

    public var title: String {
        switch self {
        case .bronze: return "Bronze"
        case .argent: return "Argent"
        case .or: return "Or"
        case .platine: return "Platine"
        case .diamant: return "Diamant"
        case .master: return "Master"
        case .grandMaster: return "Grand Master"
        }
    }

    /// Inclusive rating floor of the tier.
    public var minRating: Int {
        switch self {
        case .bronze: return 0
        case .argent: return 1200
        case .or: return 1400
        case .platine: return 1600
        case .diamant: return 1800
        case .master: return 2000
        case .grandMaster: return 2200
        }
    }

    public var colorHex: String {
        switch self {
        case .bronze: return "#cd7f32"
        case .argent: return "#c0c0c0"
        case .or: return "#ffb000"
        case .platine: return "#38d6ff"
        case .diamant: return "#00ff88"
        case .master: return "#c084fc"
        case .grandMaster: return "#fb7185"
        }
    }

    /// The tier a rating falls into.
    public static func tier(forRating rating: Int) -> RankTier {
        allCases.last { rating >= $0.minRating } ?? .bronze
    }

    /// Progress (0...1) through the current tier toward the next; 1 at the top tier.
    public func progress(rating: Int) -> Double {
        guard let next = RankTier(rawValue: rawValue + 1) else { return 1 }
        let span = Double(next.minRating - minRating)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(rating - minRating) / span))
    }
}
