import Foundation

/// Everything mutated by an applied game result.
public struct AppliedResult: Sendable {
    public let coinsDelta: Int          // net coins added to the wallet (incl. level + achievement rewards, post-cap)
    public let xpDelta: Int
    public let leveledUpTo: [Int]       // every new level reached, e.g. [8] or [8, 9]
    public let levelRewardCoins: Int
    public let levelRewardItems: [Rarity]
    public let newRecord: Bool
    public let chestsEarned: Int        // chests won this game (score roll + streak milestone + succès)
    public let newlyUnlockedAchievementIDs: [String]
}

/// The single-player save state. Pure value type; persistence lives in the app.
public struct PlayerProfile: Codable, Sendable {
    public var pseudo: String
    public var totalXP: Int
    public var coins: Int
    public var ownedItemIDs: Set<String>
    public var equipped: [String: String]      // AvatarSlot.rawValue : AvatarItem.id
    public var bestScores: [String: Int]        // recordKey : score
    public var gamesPlayed: Int
    public var totalCorrect: Int
    public var totalAnswered: Int
    public var bestStreakEver: Int
    public var dailyStreak: Int
    public var lastPlayedDay: Int
    public var lastDailyDay: Int
    public var trainingCoinsDay: Int
    public var trainingCoinsToday: Int
    /// Duels won and total duels played (used for the "X/Y gagnés" profile stat).
    public var duelWins: Int
    public var duelGames: Int
    /// Number of distinct daily challenges (défi du jour) finished.
    public var defiCompletedCount: Int
    public var soundOn: Bool
    public var musicOn: Bool
    public var notificationsOn: Bool
    /// Mystery chests won and not yet opened.
    public var ownedChests: Int
    /// Ever-incrementing count of chests opened, used as the open seed.
    public var chestOpenCount: Int
    /// Day key (YYYYMMDD) of the last daily-wheel spin; gates one spin per day.
    public var lastWheelDay: Int
    /// Serial day (DayKey) of the last game that fed the daily play streak.
    public var lastStreakSerial: Int
    /// Streak length already rewarded, so a milestone pays its chests once.
    public var lastMilestoneRewarded: Int
    /// Ids of succès already unlocked (and paid).
    public var unlockedAchievementIDs: Set<String>
    /// Onboarding flags: first game finished, first-cosmetic nudge dismissed,
    /// one-time welcome top-up granted.
    public var firstGameDone: Bool
    public var firstCosmeticNudgeSeen: Bool
    public var welcomeBonusGranted: Bool

    public init(pseudo: String = "RetroKid") {
        self.pseudo = pseudo
        self.totalXP = 0
        self.coins = 0
        self.ownedItemIDs = []
        self.equipped = [:]
        self.bestScores = [:]
        self.gamesPlayed = 0
        self.totalCorrect = 0
        self.totalAnswered = 0
        self.bestStreakEver = 0
        self.dailyStreak = 0
        self.lastPlayedDay = 0
        self.lastDailyDay = 0
        self.trainingCoinsDay = 0
        self.trainingCoinsToday = 0
        self.duelWins = 0
        self.duelGames = 0
        self.defiCompletedCount = 0
        self.soundOn = true
        self.musicOn = true
        self.notificationsOn = false
        self.ownedChests = 0
        self.chestOpenCount = 0
        self.lastWheelDay = 0
        self.lastStreakSerial = 0
        self.lastMilestoneRewarded = 0
        self.unlockedAchievementIDs = []
        self.firstGameDone = false
        self.firstCosmeticNudgeSeen = false
        self.welcomeBonusGranted = false
    }

    // MARK: Codable (resilient to older saves)

    private enum CodingKeys: String, CodingKey {
        case pseudo, totalXP, coins, ownedItemIDs, equipped, bestScores
        case gamesPlayed, totalCorrect, totalAnswered, bestStreakEver
        case dailyStreak, lastPlayedDay, lastDailyDay, trainingCoinsDay, trainingCoinsToday
        case duelWins, duelGames, defiCompletedCount
        case soundOn, musicOn, notificationsOn
        case ownedChests, chestOpenCount, lastWheelDay
        case lastStreakSerial, lastMilestoneRewarded, unlockedAchievementIDs
        case firstGameDone, firstCosmeticNudgeSeen, welcomeBonusGranted
    }

    /// Decodes leniently so that adding new fields never invalidates an existing
    /// save: any missing key falls back to its default instead of failing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pseudo = try c.decodeIfPresent(String.self, forKey: .pseudo) ?? "RetroKid"
        totalXP = try c.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        ownedItemIDs = try c.decodeIfPresent(Set<String>.self, forKey: .ownedItemIDs) ?? []
        equipped = try c.decodeIfPresent([String: String].self, forKey: .equipped) ?? [:]
        bestScores = try c.decodeIfPresent([String: Int].self, forKey: .bestScores) ?? [:]
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        totalCorrect = try c.decodeIfPresent(Int.self, forKey: .totalCorrect) ?? 0
        totalAnswered = try c.decodeIfPresent(Int.self, forKey: .totalAnswered) ?? 0
        bestStreakEver = try c.decodeIfPresent(Int.self, forKey: .bestStreakEver) ?? 0
        dailyStreak = try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0
        lastPlayedDay = try c.decodeIfPresent(Int.self, forKey: .lastPlayedDay) ?? 0
        lastDailyDay = try c.decodeIfPresent(Int.self, forKey: .lastDailyDay) ?? 0
        trainingCoinsDay = try c.decodeIfPresent(Int.self, forKey: .trainingCoinsDay) ?? 0
        trainingCoinsToday = try c.decodeIfPresent(Int.self, forKey: .trainingCoinsToday) ?? 0
        duelWins = try c.decodeIfPresent(Int.self, forKey: .duelWins) ?? 0
        duelGames = try c.decodeIfPresent(Int.self, forKey: .duelGames) ?? 0
        defiCompletedCount = try c.decodeIfPresent(Int.self, forKey: .defiCompletedCount) ?? 0
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        musicOn = try c.decodeIfPresent(Bool.self, forKey: .musicOn) ?? true
        notificationsOn = try c.decodeIfPresent(Bool.self, forKey: .notificationsOn) ?? false
        ownedChests = try c.decodeIfPresent(Int.self, forKey: .ownedChests) ?? 0
        chestOpenCount = try c.decodeIfPresent(Int.self, forKey: .chestOpenCount) ?? 0
        lastWheelDay = try c.decodeIfPresent(Int.self, forKey: .lastWheelDay) ?? 0
        lastStreakSerial = try c.decodeIfPresent(Int.self, forKey: .lastStreakSerial) ?? 0
        lastMilestoneRewarded = try c.decodeIfPresent(Int.self, forKey: .lastMilestoneRewarded) ?? 0
        unlockedAchievementIDs = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedAchievementIDs) ?? []
        firstGameDone = try c.decodeIfPresent(Bool.self, forKey: .firstGameDone) ?? false
        firstCosmeticNudgeSeen = try c.decodeIfPresent(Bool.self, forKey: .firstCosmeticNudgeSeen) ?? false
        welcomeBonusGranted = try c.decodeIfPresent(Bool.self, forKey: .welcomeBonusGranted) ?? false
    }

    // MARK: Derived

    public var level: Int { LevelTable.level(totalXP: totalXP) }
    public var levelProgress: LevelProgress { LevelTable.progress(totalXP: totalXP) }
    public var title: String { LevelTable.title(level: level) }
    public var accuracy: Double { totalAnswered > 0 ? Double(totalCorrect) / Double(totalAnswered) : 0 }

    public var bestScoreOverall: Int { bestScores.values.max() ?? 0 }

    /// A skill rating built from the player's best score in each ranked mode. Unlike
    /// the level (driven by XP, i.e. how *much* you play), this reflects how *well*
    /// you play: it only moves when you beat a personal best.
    public var skillScore: Int {
        GameMode.allCases.filter(\.tracksRecord).reduce(0) { $0 + bestScore(forMode: $1) }
    }

    public static func recordKey(mode: GameMode, categoryID: String?, difficulty: Difficulty) -> String {
        "\(mode.rawValue)|\(categoryID ?? "all")|\(difficulty.rawValue)"
    }

    public func bestScore(mode: GameMode, categoryID: String?, difficulty: Difficulty) -> Int {
        bestScores[Self.recordKey(mode: mode, categoryID: categoryID, difficulty: difficulty)] ?? 0
    }

    /// Best score for a mode across every category and difficulty, or 0 if never recorded.
    public func bestScore(forMode mode: GameMode) -> Int {
        let prefix = "\(mode.rawValue)|"
        return bestScores.filter { $0.key.hasPrefix(prefix) }.values.max() ?? 0
    }

    // MARK: Mutation

    /// Applies a finished game: coins (with the training daily cap and a wallet floor
    /// of 0), XP and any level-ups (granting their coin rewards), records and lifetime stats.
    @discardableResult
    public mutating func apply(result: GameResult, day: Int) -> AppliedResult {
        // Coins from the game, with the training (classique) daily cap.
        var coinsFromGame = result.coinsEarned
        if result.mode.isTraining {
            if trainingCoinsDay != day {
                trainingCoinsDay = day
                trainingCoinsToday = 0
            }
            let remaining = max(0, Economy.trainingDailyCap - trainingCoinsToday)
            coinsFromGame = min(max(0, result.coinsEarned), remaining)
            trainingCoinsToday += coinsFromGame
        }
        coins = max(0, coins + coinsFromGame)

        // XP and level-ups.
        let beforeLevel = level
        totalXP += max(0, result.xpEarned)
        let afterLevel = level
        var levels: [Int] = []
        var rewardCoinsTotal = 0
        var rewardItems: [Rarity] = []
        if afterLevel > beforeLevel {
            for lvl in (beforeLevel + 1)...afterLevel {
                let reward = LevelTable.reward(reachingLevel: lvl)
                rewardCoinsTotal += reward.coins
                if let rarity = reward.itemRarity { rewardItems.append(rarity) }
                levels.append(lvl)
            }
            coins += rewardCoinsTotal
        }

        // Records.
        var newRecord = false
        if result.mode.tracksRecord {
            let key = Self.recordKey(mode: result.mode, categoryID: result.categoryID, difficulty: result.difficulty)
            if result.score > (bestScores[key] ?? 0) {
                bestScores[key] = result.score
                newRecord = true
            }
        }

        // Lifetime stats.
        gamesPlayed += 1
        totalCorrect += result.correctCount
        totalAnswered += result.total
        bestStreakEver = max(bestStreakEver, result.bestStreak)
        lastPlayedDay = day
        if result.mode == .duel {
            duelGames += 1
            if result.duelWon == true { duelWins += 1 }
        }

        // Chests, streak and succès (post-stats, so the succès context is accurate).
        var chestsEarned = 0

        // a. Chest by score: better games have a higher chance, up to 60% on a flawless run.
        if Economy.chestAwarded(mode: result.mode, correctCount: result.correctCount,
                                total: result.total, seed: chestRollSeed(day: day, score: result.score)) {
            ownedChests += 1
            chestsEarned += 1
        }

        // b. Daily play streak: any finished game holds the streak; milestones grant chests.
        let serial = DayKey.serial(day)
        if serial != lastStreakSerial {
            dailyStreak = (lastStreakSerial == 0 || serial == lastStreakSerial + 1) ? dailyStreak + 1 : 1
            lastStreakSerial = serial
            if dailyStreak != lastMilestoneRewarded {
                let milestoneChests = StreakMilestone.chests(forStreak: dailyStreak)
                if milestoneChests > 0 {
                    ownedChests += milestoneChests
                    chestsEarned += milestoneChests
                    lastMilestoneRewarded = dailyStreak
                }
            }
        }

        firstGameDone = true

        // c. Succès: evaluate once, pay coins and/or chests.
        let ctx = AchievementContext(
            gamesPlayed: gamesPlayed,
            level: level,
            dailyStreak: dailyStreak,
            totalCorrect: totalCorrect,
            lastWasPerfect: result.correctCount == result.total && result.total >= 5
        )
        let newlyUnlocked = Achievement.evaluate(ctx, already: unlockedAchievementIDs)
        var achievementCoins = 0
        for ach in newlyUnlocked {
            unlockedAchievementIDs.insert(ach.id)
            achievementCoins += ach.reward.coins
            if ach.reward.chests > 0 {
                ownedChests += ach.reward.chests
                chestsEarned += ach.reward.chests
            }
        }
        coins = max(0, coins + achievementCoins)

        return AppliedResult(
            coinsDelta: coinsFromGame + rewardCoinsTotal + achievementCoins,
            xpDelta: max(0, result.xpEarned),
            leveledUpTo: levels,
            levelRewardCoins: rewardCoinsTotal,
            levelRewardItems: rewardItems,
            newRecord: newRecord,
            chestsEarned: chestsEarned,
            newlyUnlockedAchievementIDs: newlyUnlocked.map(\.id)
        )
    }

    /// Deterministic seed for the per-game chest roll (no system RNG). Varies by
    /// day, the lifetime games count (already incremented) and the round score.
    private func chestRollSeed(day: Int, score: Int) -> UInt64 {
        var v = UInt64(bitPattern: Int64(day))
        v = (v &* 0x9E3779B97F4A7C15) ^ UInt64(bitPattern: Int64(gamesPlayed))
        v = (v &* 0x9E3779B97F4A7C15) ^ UInt64(bitPattern: Int64(score))
        return v ^ 0xC0FFEE1234567890
    }

    /// One-time welcome top-up so a new player can buy their first cosmetic (200)
    /// after their first game. Idempotent via `welcomeBonusGranted`.
    public mutating func applyWelcomeBonusIfNeeded() {
        guard !welcomeBonusGranted else { return }
        welcomeBonusGranted = true
        coins += Economy.welcomeTopUp(currentCoins: coins)
    }

    /// Records playing today's daily challenge (the défi). The daily play streak
    /// itself is held by finishing any game, handled in `apply(result:day:)`.
    public mutating func registerDaily(day: Int) {
        guard day != lastDailyDay else { return }
        lastDailyDay = day
        defiCompletedCount += 1
    }

    public var dailyAvailable: Bool { true } // gated by lastDailyDay vs today in the store
}
