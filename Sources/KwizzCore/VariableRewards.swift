import Foundation

/// A single segment of a weighted prize table: a coin amount and its draw weight.
public struct WheelPrize: Sendable, Equatable {
    public let coins: Int
    public let weight: Int
    public init(coins: Int, weight: Int) {
        self.coins = coins
        self.weight = weight
    }
}

/// What a single chest opening yields: coins, or one cosmetic item (never both).
public struct ChestResult: Sendable, Equatable {
    public let coins: Int        // 0 when an item was awarded
    public let itemID: String?   // nil when coins were awarded
    public init(coins: Int, itemID: String?) {
        self.coins = coins
        self.itemID = itemID
    }
    public var isItem: Bool { itemID != nil }
}

public enum VariableRewards {
    /// Deterministic weighted sampler over non-negative integer weights.
    public static func weightedIndex(_ weights: [Int], using gen: inout SeededGenerator) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let roll = Int(gen.next() % UInt64(total))
        var acc = 0
        for (i, w) in weights.enumerated() {
            acc += w
            if roll < acc { return i }
        }
        return weights.count - 1
    }

    /// Expected value of a coin prize table (sum(coins*weight)/sum(weight)).
    static func expectedValue(_ prizes: [WheelPrize]) -> Double {
        let totalW = prizes.reduce(0) { $0 + $1.weight }
        guard totalW > 0 else { return 0 }
        return Double(prizes.reduce(0) { $0 + $1.coins * $1.weight }) / Double(totalW)
    }
}

/// The once-a-day wheel. Seeded by the calendar day so the result is the same for
/// everyone that day, yet feels like chance. Average payout ~50 coins.
///
/// Les poids sont exprimés sur 10 000 (et non plus sur 100) pour autoriser des
/// probabilités fines: le jackpot de 10 000 pièces a un poids de 1, soit 0,01 %
/// de chance. Il est placé en toute fin de table (le dernier lot, le plus rare).
public enum DailyWheel {
    public static let prizes: [WheelPrize] = [
        WheelPrize(coins: 10, weight: 2600),
        WheelPrize(coins: 20, weight: 3000),
        WheelPrize(coins: 40, weight: 2300),
        WheelPrize(coins: 70, weight: 1200),
        WheelPrize(coins: 120, weight: 500),
        WheelPrize(coins: 250, weight: 250),
        WheelPrize(coins: 500, weight: 100),
        WheelPrize(coins: 1000, weight: 40),
        WheelPrize(coins: 2500, weight: 9),
        WheelPrize(coins: 10000, weight: 1),
    ]

    /// Somme des poids (10 000). Sert à convertir un poids en probabilité.
    public static var totalWeight: Int { prizes.reduce(0) { $0 + $1.weight } }

    public static var expectedValue: Double { VariableRewards.expectedValue(prizes) }

    public static func seed(day: Int) -> UInt64 {
        let base = UInt64(bitPattern: Int64(day))
        return (base &* 0x9E3779B97F4A7C15) ^ 0xA5A5A5A5DEADBEEF
    }

    public static func spinIndex(day: Int) -> Int {
        var gen = SeededGenerator(seed: seed(day: day))
        return VariableRewards.weightedIndex(prizes.map(\.weight), using: &gen)
    }

    /// Coins won for a given day. Deterministic.
    public static func spin(day: Int) -> Int { prizes[spinIndex(day: day)].coins }
}

/// Mystery chests, won by playing. Opening one yields 90% coins (variable amount)
/// or 10% a cosmetic item (mostly common, rarely rarer). Seeded by an incrementing
/// open counter so every open differs yet stays reproducible.
public enum MysteryChest {
    /// Coin payouts on the 90% branch (average ~55, deliberately modest: the
    /// excitement is the 10% item branch, the coins are a small bonus).
    public static let coinPrizes: [WheelPrize] = [
        WheelPrize(coins: 20, weight: 40),
        WheelPrize(coins: 40, weight: 32),
        WheelPrize(coins: 80, weight: 18),
        WheelPrize(coins: 150, weight: 8),
        WheelPrize(coins: 400, weight: 2),
    ]

    /// Out of 100: chance an opening yields an item instead of coins.
    public static let itemDropPercent = 10

    /// Rarity weights for the item branch: mostly common, small chances rarer.
    public static let rarityWeights: [(rarity: Rarity, weight: Int)] = [
        (.commun, 70), (.rare, 22), (.epique, 7), (.legendaire, 1),
    ]

    public static var coinExpectedValue: Double { VariableRewards.expectedValue(coinPrizes) }

    public static func seed(open: Int) -> UInt64 {
        let base = UInt64(bitPattern: Int64(open))
        return ((base &+ 1) &* 0x9E3779B97F4A7C15) ^ 0x1234ABCD5678EF01
    }

    /// Opens the chest indexed by `open`, given the items the player already owns.
    /// Item drops are picked only from un-owned purchasable cosmetics; if none is
    /// available (or the roll lands on coins), pays coins instead.
    public static func open(open openIndex: Int, owned: Set<String>) -> ChestResult {
        var gen = SeededGenerator(seed: seed(open: openIndex))
        let kind = Int(gen.next() % 100)
        if kind >= itemDropPercent {
            return coins(using: &gen)
        }
        if let item = pickItem(owned: owned, using: &gen) {
            return ChestResult(coins: 0, itemID: item.id)
        }
        return coins(using: &gen)
    }

    private static func coins(using gen: inout SeededGenerator) -> ChestResult {
        let idx = VariableRewards.weightedIndex(coinPrizes.map(\.weight), using: &gen)
        return ChestResult(coins: coinPrizes[idx].coins, itemID: nil)
    }

    /// Draws a rarity by weight, then a random un-owned purchasable item of that
    /// rarity; if that rarity is exhausted, walks the other rarities; nil if all
    /// purchasable items are owned.
    static func pickItem(owned: Set<String>, using gen: inout SeededGenerator) -> AvatarItem? {
        let rarityIdx = VariableRewards.weightedIndex(rarityWeights.map(\.weight), using: &gen)
        let start = rarityWeights[rarityIdx].rarity
        for rarity in orderedRarities(startingAt: start) {
            let pool = AvatarItem.catalog.filter {
                $0.rarity == rarity && $0.unlockLevel == nil && !owned.contains($0.id)
            }
            if !pool.isEmpty {
                return pool[Int(gen.next() % UInt64(pool.count))]
            }
        }
        return nil
    }

    private static func orderedRarities(startingAt rarity: Rarity) -> [Rarity] {
        let all: [Rarity] = [.commun, .rare, .epique, .legendaire]
        guard let i = all.firstIndex(of: rarity) else { return all }
        return Array(all[i...]) + Array(all[..<i])
    }
}
