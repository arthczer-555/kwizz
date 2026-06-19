import Foundation

/// A one-time reward paid the first time a succès unlocks.
public struct AchievementReward: Sendable, Equatable {
    public let coins: Int
    public let chests: Int
    public init(coins: Int = 0, chests: Int = 0) {
        self.coins = coins
        self.chests = chests
    }
}

/// Immutable snapshot the conditions read, built from the post-game profile.
public struct AchievementContext: Sendable {
    public let gamesPlayed: Int
    public let level: Int
    public let dailyStreak: Int
    public let totalCorrect: Int
    public let lastWasPerfect: Bool

    public init(gamesPlayed: Int, level: Int, dailyStreak: Int, totalCorrect: Int, lastWasPerfect: Bool) {
        self.gamesPlayed = gamesPlayed
        self.level = level
        self.dailyStreak = dailyStreak
        self.totalCorrect = totalCorrect
        self.lastWasPerfect = lastWasPerfect
    }
}

/// A succès: a named goal with a one-time reward. Conditions read only existing
/// profile counters, so no extra tracking is needed. Pure, UI-free.
public struct Achievement: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let reward: AchievementReward
    public let condition: @Sendable (AchievementContext) -> Bool

    public init(id: String, title: String, detail: String, reward: AchievementReward,
                condition: @escaping @Sendable (AchievementContext) -> Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.reward = reward
        self.condition = condition
    }

    /// The six succès. Values are easy to adapt.
    public static let catalog: [Achievement] = [
        Achievement(id: "premiere_partie", title: "Première partie",
                    detail: "Termine ta première partie", reward: .init(chests: 1)) {
            $0.gamesPlayed >= 1
        },
        Achievement(id: "sans_faute", title: "Sans faute",
                    detail: "Termine une partie sans aucune erreur", reward: .init(chests: 1)) {
            $0.lastWasPerfect
        },
        Achievement(id: "regulier", title: "Régulier",
                    detail: "Atteins une série de 7 jours", reward: .init(chests: 2)) {
            $0.dailyStreak >= 7
        },
        Achievement(id: "encyclopedie", title: "Encyclopédie",
                    detail: "Réponds correctement à 500 questions", reward: .init(coins: 1000)) {
            $0.totalCorrect >= 500
        },
        Achievement(id: "niveau_10", title: "Niveau 10",
                    detail: "Atteins le niveau 10", reward: .init(chests: 1)) {
            $0.level >= 10
        },
        Achievement(id: "veteran", title: "Vétéran",
                    detail: "Joue 50 parties", reward: .init(coins: 1500)) {
            $0.gamesPlayed >= 50
        },
    ]

    public static func find(_ id: String) -> Achievement? { catalog.first { $0.id == id } }

    /// Succès whose condition is now met and that are not already unlocked.
    public static func evaluate(_ ctx: AchievementContext, already: Set<String>) -> [Achievement] {
        catalog.filter { !already.contains($0.id) && $0.condition(ctx) }
    }
}
