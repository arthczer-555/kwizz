import Foundation

/// Coin rewards per mode. The economy is deliberately tight (~8-14 coins/min on
/// active modes) so every shop item stays a real goal. See PLAN.md section 5.3.
public enum Economy {
    public static let trainingDailyCap = 20
    public static let duelStake = 15

    /// Coin floor a brand-new player is topped up to after their first game, so
    /// the cheapest cosmetic (200) is buyable in session 1. See `welcomeTopUp`.
    public static let welcomeFloor = 200

    /// Coins to add so the wallet reaches `welcomeFloor` (never negative).
    public static func welcomeTopUp(currentCoins: Int) -> Int {
        max(0, welcomeFloor - currentCoins)
    }

    // MARK: Chests by score

    /// In open-ended modes (no fixed total), correct answers needed for a full
    /// chest chance. Below ~60% of this, no chest can drop.
    public static let chestTargetCorrect = 20

    /// Probability of winning a chest from a finished game, as a function of how
    /// well the player did. 0 below 60% of performance, scaling up to 0.60 at a
    /// flawless game. Training is excluded.
    public static func chestChance(mode: GameMode, correctCount: Int, total: Int) -> Double {
        guard !mode.isTraining else { return 0 }
        let p: Double
        if total > 0, mode != .survie, mode != .contreLaMontre {
            p = Double(correctCount) / Double(total)            // fixed-total modes: accuracy
        } else {
            p = min(1.0, Double(correctCount) / Double(chestTargetCorrect))  // open modes: progress to target
        }
        guard p >= 0.6 else { return 0 }
        return (p - 0.6) / 0.4 * 0.60
    }

    /// Deterministic, seeded chest roll for a finished game (no system RNG).
    public static func chestAwarded(mode: GameMode, correctCount: Int, total: Int, seed: UInt64) -> Bool {
        let chance = chestChance(mode: mode, correctCount: correctCount, total: total)
        guard chance > 0 else { return false }
        var gen = SeededGenerator(seed: seed)
        let roll = Double(gen.next() >> 11) * (1.0 / 9_007_199_254_740_992.0)  // uniform [0,1)
        return roll < chance
    }

    public struct Input: Sendable {
        public let mode: GameMode
        /// Effective coin multiplier for the round. In single-difficulty modes this
        /// is that difficulty's multiplier; in mixed modes it is the average of the
        /// answered questions' own multipliers.
        public let coinMultiplier: Double
        public let correctCount: Int
        public let total: Int
        public let perfect: Bool
        public let bestStreak: Int
        public let fastCount: Int
        public let scoreFraction: Double
        public let duelWon: Bool?

        public init(mode: GameMode, coinMultiplier: Double, correctCount: Int, total: Int, perfect: Bool,
                    bestStreak: Int, fastCount: Int, scoreFraction: Double, duelWon: Bool?) {
            self.mode = mode
            self.coinMultiplier = coinMultiplier
            self.correctCount = correctCount
            self.total = total
            self.perfect = perfect
            self.bestStreak = bestStreak
            self.fastCount = fastCount
            self.scoreFraction = scoreFraction
            self.duelWon = duelWon
        }
    }

    /// Raw coins earned by a finished game. The training (entraînement) daily cap
    /// and the duel wallet floor are applied by `PlayerProfile.apply(result:day:)`.
    public static func coins(_ i: Input) -> Int {
        switch i.mode {
        case .entrainement:
            return i.correctCount / 10   // training: very reduced, capped at 20/day by the store
        case .classique, .contreLaMontre:
            return scaled(i.correctCount, i.coinMultiplier)
        case .survie:
            return scaled(i.correctCount + i.bestStreak / 5, i.coinMultiplier)
        case .duel:
            // duelWon nil = match nul (ligue 1v1) : ni mise gagnée ni perdue.
            guard let won = i.duelWon else { return 0 }
            return won ? duelStake : -duelStake
        case .defi:
            return defiReward(errors: i.total - i.correctCount)
        }
    }

    /// Daily-challenge payout. Heavily front-loaded to reward a flawless run: a
    /// no-mistake grid pays 150, then it drops off sharply with each error so the
    /// "sans faute" stays the real goal.
    public static func defiReward(errors: Int) -> Int {
        switch max(0, errors) {
        case 0: return 150
        case 1: return 50
        case 2: return 30
        case 3: return 20
        case 4: return 10
        default: return 0
        }
    }

    private static func scaled(_ base: Int, _ multiplier: Double) -> Int {
        Int((Double(base) * multiplier).rounded())
    }
}
