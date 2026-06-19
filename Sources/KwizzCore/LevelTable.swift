import Foundation

public struct LevelProgress: Sendable, Equatable {
    public let level: Int
    public let title: String
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int   // 0 when max level
    public let fraction: Double      // 0...1
    public let isMax: Bool
}

public struct LevelReward: Sendable, Equatable {
    public let level: Int
    public let coins: Int
    public let itemRarity: Rarity?
}

/// The 20-level progression. Hardened curve: ~239 000 XP to reach level 20
/// ("Émilien"), which should stay a rare achievement.
public enum LevelTable {
    public static let maxLevel = 20

    public static let titles: [String] = [
        "L'américain moyen",
        "Le pilier gauche",
        "Le cancre",
        "Roi du quiz de comptoir",
        "Bachelier (mention pas de mention)",
        "Pilier de PMU cultivé",
        "Le gars qui a appris toutes les capitales",
        "Tête de classe",
        "Crack du Trivial Pursuit",
        "Cerveau de la bande",
        "Bac +5 en culture G",
        "Bête de concours",
        "Encyclopédie ambulante",
        "Champion de Burger Quiz",
        "Mentaliste",
        "Génie incompris",
        "Membre du Mensa",
        "La daronne au jeu des mille euros",
        "Wikipedia",
        "Émilien",
    ]

    /// XP needed to go from level i (1-based) to level i+1. 19 entries.
    public static let xpToNext: [Int] = [
        150, 300, 500, 800, 1200, 1700, 2400, 3300, 4500, 6000,
        8000, 10500, 13500, 17000, 21000, 26000, 32000, 40000, 50000,
    ]

    /// Cumulative XP required to *reach* each level. cumulative[0] (level 1) == 0.
    public static let cumulative: [Int] = {
        var out: [Int] = [0]
        var running = 0
        for step in xpToNext {
            running += step
            out.append(running)
        }
        return out   // count == 20
    }()

    public static var totalToMax: Int { cumulative[maxLevel - 1] }

    public static func title(level: Int) -> String {
        let clamped = min(max(level, 1), maxLevel)
        return titles[clamped - 1]
    }

    public static func level(totalXP: Int) -> Int {
        let xp = max(0, totalXP)
        var lvl = 1
        for i in 0..<maxLevel where xp >= cumulative[i] {
            lvl = i + 1
        }
        return lvl
    }

    public static func progress(totalXP: Int) -> LevelProgress {
        let xp = max(0, totalXP)
        let lvl = level(totalXP: xp)
        let name = title(level: lvl)
        if lvl >= maxLevel {
            return LevelProgress(level: lvl, title: name, xpIntoLevel: 0, xpForNextLevel: 0, fraction: 1, isMax: true)
        }
        let floorXP = cumulative[lvl - 1]
        let need = xpToNext[lvl - 1]
        let into = xp - floorXP
        let frac = need > 0 ? min(1, max(0, Double(into) / Double(need))) : 0
        return LevelProgress(level: lvl, title: name, xpIntoLevel: into, xpForNextLevel: need, fraction: frac, isMax: false)
    }

    private static let rewardCoins: [Int: Int] = [
        2: 20, 3: 30, 4: 40, 5: 60, 6: 80, 7: 100, 8: 120, 9: 150, 10: 200,
        11: 250, 12: 300, 13: 400, 14: 500, 15: 600, 16: 800, 17: 1000, 18: 1200, 19: 1500, 20: 0,
    ]
    private static let rewardItem: [Int: Rarity] = [5: .commun, 10: .rare, 15: .epique, 20: .legendaire]

    /// The reward granted for *reaching* `level`.
    public static func reward(reachingLevel level: Int) -> LevelReward {
        LevelReward(level: level, coins: rewardCoins[level] ?? 0, itemRarity: rewardItem[level])
    }
}
