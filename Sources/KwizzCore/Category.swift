import Foundation

public struct Subcategory: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Category: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Accent colour used for the small category dot (hex, e.g. "#ffb000").
    public let colorHex: String
    /// SF Symbol name.
    public let symbol: String
    public let subcategories: [Subcategory]

    public init(id: String, name: String, colorHex: String, symbol: String, subcategories: [Subcategory]) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbol = symbol
        self.subcategories = subcategories
    }
}

public extension Category {
    private static func subs(_ id: String, _ names: [String]) -> [Subcategory] {
        names.enumerated().map { index, name in
            Subcategory(id: "\(id).\(index)", name: name)
        }
    }

    /// Virtual "all categories" entry: the "Tous les thèmes" choice and the Daily Challenge.
    static let melange = Category(
        id: "melange", name: "Mélange", colorHex: "#00ff88", symbol: "shuffle", subcategories: []
    )

    /// The 13 real categories (see PLAN.md section 9).
    static let all: [Category] = [
        Category(id: "histoire", name: "Histoire", colorHex: "#ffb000", symbol: "building.columns",
                 subcategories: subs("histoire", ["Antiquité", "Moyen Âge", "Époque moderne", "Époque contemporaine", "Guerres mondiales", "Histoire de France"])),
        Category(id: "geographie", name: "Géographie", colorHex: "#38d6ff", symbol: "globe.europe.africa",
                 subcategories: subs("geographie", ["Capitales", "Drapeaux", "Pays du monde", "Fleuves & reliefs", "Mers & océans", "Géographie de France"])),
        Category(id: "sciences", name: "Sciences", colorHex: "#00ff88", symbol: "atom",
                 subcategories: subs("sciences", ["Biologie", "Physique", "Chimie", "Astronomie", "Corps humain", "Mathématiques"])),
        Category(id: "sport", name: "Sport", colorHex: "#ff7a3c", symbol: "sportscourt",
                 subcategories: subs("sport", ["Football", "Tennis", "Rugby", "Jeux Olympiques", "Sports US", "Cyclisme", "Auto/Moto"])),
        Category(id: "cinema", name: "Ciné & Séries", colorHex: "#fb7185", symbol: "film",
                 subcategories: subs("cinema", ["Films cultes", "Acteurs & actrices", "Disney/Pixar", "Marvel/DC", "Séries TV", "Récompenses"])),
        Category(id: "musique", name: "Musique", colorHex: "#c084fc", symbol: "music.note",
                 subcategories: subs("musique", ["Variété française", "Pop internationale", "Rap/Hip-hop", "Rock", "Classique", "Blind test"])),
        Category(id: "arts", name: "Arts & Littérature", colorHex: "#f0f0f0", symbol: "paintbrush",
                 subcategories: subs("arts", ["Peinture", "Littérature classique", "BD & Manga", "Poésie", "Sculpture & architecture"])),
        Category(id: "actu", name: "Actu & Société", colorHex: "#38d6ff", symbol: "newspaper",
                 subcategories: subs("actu", ["Politique", "Économie", "Faits de société", "Événements récents"])),
        Category(id: "nature", name: "Nature & Animaux", colorHex: "#00ff88", symbol: "leaf",
                 subcategories: subs("nature", ["Faune", "Flore", "Écologie", "Dinosaures", "Vie marine"])),
        Category(id: "tech", name: "Tech & Jeux", colorHex: "#fb7185", symbol: "gamecontroller",
                 subcategories: subs("tech", ["Internet & informatique", "Jeux vidéo", "Inventions", "Intelligence artificielle", "Marques tech"])),
        Category(id: "gastronomie", name: "Gastronomie", colorHex: "#ffb000", symbol: "fork.knife",
                 subcategories: subs("gastronomie", ["Cuisine française", "Cuisines du monde", "Vins & boissons", "Pâtisserie"])),
        Category(id: "pop", name: "Pop culture", colorHex: "#c084fc", symbol: "star",
                 subcategories: subs("pop", ["Célébrités", "TV & télé-réalité", "Mèmes & Internet", "Logos & marques"])),
        Category(id: "mythes", name: "Mythes & Religions", colorHex: "#ff7a3c", symbol: "sparkles",
                 subcategories: subs("mythes", ["Mythologie grecque & romaine", "Mythologies nordique/égyptienne", "Religions du monde", "Légendes & croyances"])),
    ]

    static func find(id: String) -> Category? {
        if id == melange.id { return melange }
        return all.first { $0.id == id }
    }
}
