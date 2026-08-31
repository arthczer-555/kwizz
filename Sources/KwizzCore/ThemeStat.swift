import Foundation

/// Compteur de réussite pour un thème (une catégorie de questions).
/// Utilisé à deux niveaux : par manche (`GameResult.themeBreakdown`) et en cumul
/// sur toute la vie du joueur (`PlayerProfile.themeStats`).
public struct ThemeStat: Codable, Hashable, Sendable {
    /// Bonnes réponses.
    public var correct: Int
    /// Questions répondues (bonnes + mauvaises + timeouts).
    public var answered: Int

    public init(correct: Int = 0, answered: Int = 0) {
        self.correct = correct
        self.answered = answered
    }

    /// Part de bonnes réponses, entre 0 et 1 (0 quand rien n'a encore été répondu).
    public var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 0
    }

    /// Ajoute les compteurs d'un autre relevé du même thème.
    public mutating func merge(_ other: ThemeStat) {
        correct += other.correct
        answered += other.answered
    }
}
