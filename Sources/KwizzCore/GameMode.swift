import Foundation

/// A way to play. All five modes ship in the MVP. `duel` runs against a bot and
/// `defi` (daily challenge) is generated locally and deterministically, so none
/// of them require a backend. `classique` is a 20-question round where the goal
/// is the most correct answers.
public enum GameMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case classique
    case contreLaMontre
    case survie
    case duel
    case defi
    case entrainement

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classique: "Classique"
        case .contreLaMontre: "Contre-la-montre"
        case .survie: "Survie"
        case .duel: "Duel"
        case .defi: "Défi du jour"
        case .entrainement: "Entraînement"
        }
    }

    public var subtitle: String {
        switch self {
        case .classique: "20 questions, max de bonnes réponses"
        case .contreLaMontre: "max de bonnes en 60s"
        case .survie: "jusqu'à la 1re erreur"
        case .duel: "2 à 6 joueurs en ligne"
        case .defi: "grille du jour, 1 essai, classement mensuel"
        case .entrainement: "ton thème, ta difficulté"
        }
    }

    /// SF Symbol shown next to the mode.
    public var symbol: String {
        switch self {
        case .classique: "infinity"
        case .contreLaMontre: "timer"
        case .survie: "heart.slash"
        case .duel: "person.2.fill"
        case .defi: "calendar"
        case .entrainement: "dumbbell"
        }
    }

    /// Fixed number of questions for the mode, or nil when it is open-ended
    /// (survie until first wrong, entraînement until the player quits) or globally
    /// timed (contre-la-montre is bounded by `globalTime`, not by a question count).
    public var questionCount: Int? {
        switch self {
        case .duel: 7
        case .defi: 10
        case .classique: 20
        case .contreLaMontre: nil
        case .survie: nil
        case .entrainement: nil
        }
    }

    /// Seconds for the whole round when the mode uses a single global timer.
    public var globalTime: Double? {
        switch self {
        case .contreLaMontre: 60
        default: nil
        }
    }

    /// Seconds allowed per question in the timed modes, identical everywhere and
    /// independent of the difficulty.
    public static let timePerQuestion: Double = 15

    /// Whether each question has its own countdown (and therefore a speed bonus).
    /// Entraînement is free practice, so it has no time pressure at all.
    public var hasPerQuestionTimer: Bool {
        switch self {
        case .classique, .survie, .duel, .defi: true
        case .contreLaMontre, .entrainement: false
        }
    }

    /// Survie ends on the first wrong answer.
    public var endsOnFirstWrong: Bool { self == .survie }

    /// A free, open-ended practice mode: it never feeds the records and its coins
    /// are capped daily. Entraînement lets the player pick a theme and a difficulty.
    public var isTraining: Bool { self == .entrainement }

    /// Whether the mode contributes to the personal best-score records.
    /// Training modes are free practice, so they do not.
    public var tracksRecord: Bool { !isTraining }

    /// Modes that are not yet playable and show an "à suivre" badge instead of
    /// being tappable. Nothing is gated now that the online duel ships.
    public var comingSoon: Bool { false }
}
