import Foundation

/// Daily play streak rewards. The streak is held by finishing any game on a given
/// calendar day (handled in `PlayerProfile.apply`); reaching a milestone grants
/// chests. Mirrors the reward-table style of `Economy.defiReward`.
public enum StreakMilestone {
    /// Chests granted when the streak first reaches `n` days: exactly one per
    /// milestone (D3, D7, D14, D30, then every 30 days).
    public static func chests(forStreak n: Int) -> Int {
        switch n {
        case 3, 7, 14, 30: return 1
        default:
            if n > 30, n % 30 == 0 { return 1 }
            return 0
        }
    }

    /// The next milestone day strictly after `n` (for the "prochain palier" display).
    public static func next(after n: Int) -> Int {
        for m in [3, 7, 14, 30] where m > n { return m }
        return ((n / 30) + 1) * 30
    }
}
