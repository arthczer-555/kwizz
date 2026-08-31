import Foundation

/// La règle de score d'un duel, choisie par l'hôte à la création de la partie.
/// Elle décide qui marque à chaque question ; `DuelMatch.applyReveal` s'en sert
/// pour distribuer les points, et rien d'autre dans le moteur n'en dépend.
public enum DuelScoring: String, Codable, Hashable, Sendable, CaseIterable {
    /// Un point par bonne réponse : tout le monde peut marquer, la vitesse ne
    /// sert qu'à départager le classement à égalité.
    case bonnesReponses
    /// Un point par bonne réponse, plus un point bonus pour la plus rapide.
    case vitesseEtBonnesReponses

    public var title: String {
        switch self {
        case .bonnesReponses: "Bonnes réponses"
        case .vitesseEtBonnesReponses: "Vitesse + bonnes réponses"
        }
    }

    public var detail: String {
        switch self {
        case .bonnesReponses:
            "1 point par bonne réponse. Tout le monde marque, peu importe qui répond en premier."
        case .vitesseEtBonnesReponses:
            "1 point par bonne réponse, +1 pour la plus rapide. Répondre juste rapporte, répondre vite rapporte plus."
        }
    }

    /// Résumé d'une ligne, pour les bandeaux du salon et de la partie.
    public var shortLabel: String {
        switch self {
        case .bonnesReponses: "1 PT PAR BONNE RÉPONSE"
        case .vitesseEtBonnesReponses: "1 PT PAR BONNE RÉPONSE · +1 AU PLUS RAPIDE"
        }
    }

    /// Points gagnés par une bonne réponse.
    public var pointsPerCorrect: Int { 1 }

    /// Point supplémentaire pour la bonne réponse la plus rapide de la question.
    public var speedBonus: Int {
        switch self {
        case .bonnesReponses: 0
        case .vitesseEtBonnesReponses: 1
        }
    }
}

/// Les réglages d'une partie, fixés par l'hôte avant d'ouvrir le salon puis
/// diffusés à toute la salle par `DuelEvent.settings`. Un seul type transporté,
/// pour qu'ajouter un réglage plus tard ne change pas le protocole.
public struct DuelSettings: Codable, Hashable, Sendable {
    /// Longueurs de manche proposées à l'hôte. Nombres impairs : une manche de
    /// duel se tranche mieux sans égalité mécanique, et les paliers montent assez
    /// vite pour que « courte » et « longue » ne se ressemblent pas.
    public static let questionCountOptions = [7, 11, 15, 21]
    /// Longueur par défaut, alignée sur celle du mode Duel hors ligne.
    public static let defaultQuestionCount = GameMode.duel.questionCount ?? 7

    public static let `default` = DuelSettings(stake: DuelWager.defaultStake,
                                               scoring: .vitesseEtBonnesReponses,
                                               questionCount: defaultQuestionCount,
                                               categoryID: Category.melange.id)

    /// Mise en pièces que chaque joueur paie pour entrer.
    public var stake: Int
    /// Comment les points sont distribués à chaque question.
    public var scoring: DuelScoring
    /// Nombre de questions de la manche, parmi `questionCountOptions`.
    public var questionCount: Int
    /// Le thème des questions : l'id d'une `Category`, ou `Category.melange.id`
    /// pour piocher dans tous les thèmes.
    public var categoryID: String

    public init(stake: Int, scoring: DuelScoring, questionCount: Int = defaultQuestionCount,
                categoryID: String = Category.melange.id) {
        self.stake = max(0, stake)
        self.scoring = scoring
        self.questionCount = Self.normalizedQuestionCount(questionCount)
        self.categoryID = Self.normalizedCategoryID(categoryID)
    }

    /// Le thème choisi, `Mélange` si l'id ne correspond à rien de connu.
    public var category: Category { Category.find(id: categoryID) ?? .melange }

    /// Nom affiché du thème. En duel, le mélange s'appelle « Tout » : le réglage
    /// se lit comme un choix (« Tout » ou un thème), pas comme une catégorie de plus.
    public static func themeName(of categoryID: String) -> String {
        categoryID == Category.melange.id ? "Tout" : (Category.find(id: categoryID) ?? .melange).name
    }

    public var themeName: String { Self.themeName(of: categoryID) }

    /// Résumé d'une ligne pour les bandeaux du salon et de la partie.
    public var themeLabel: String { themeName.uppercased() }

    /// Un thème inconnu (hôte d'une autre version, catégorie retirée depuis)
    /// retombe sur le mélange plutôt que de vider le tirage.
    public static func normalizedCategoryID(_ value: String) -> String {
        Category.find(id: value)?.id ?? Category.melange.id
    }

    /// Durée approximative d'une manche, en minutes : temps de réponse et de
    /// révélation cumulés. Sert à annoncer « ~5 min » à côté de « 15 questions »,
    /// parce qu'un nombre de questions ne dit pas à quoi on s'engage.
    public static func estimatedMinutes(questionCount: Int) -> Int {
        let perQuestion = GameMode.timePerQuestion + GameMode.duelRevealSeconds
        return max(1, Int((Double(questionCount) * perQuestion / 60).rounded()))
    }

    /// Ramène une longueur quelconque sur le palier proposé le plus proche : le
    /// réglage vient du réseau, un hôte d'une autre version peut annoncer une
    /// valeur qu'on ne propose pas (ou plus).
    public static func normalizedQuestionCount(_ value: Int) -> Int {
        questionCountOptions.min { abs($0 - value) < abs($1 - value) } ?? defaultQuestionCount
    }

    /// Décodage tolérant : un hôte resté sur une version sans ces réglages envoie
    /// un `settings` sans `questionCount` ni `categoryID`, et sa partie doit
    /// rester jouable.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(stake: try c.decode(Int.self, forKey: .stake),
                  scoring: try c.decode(DuelScoring.self, forKey: .scoring),
                  questionCount: try c.decodeIfPresent(Int.self, forKey: .questionCount)
                      ?? Self.defaultQuestionCount,
                  categoryID: try c.decodeIfPresent(String.self, forKey: .categoryID)
                      ?? Category.melange.id)
    }
}
