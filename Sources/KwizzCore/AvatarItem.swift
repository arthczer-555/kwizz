import Foundation

public enum AvatarSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case tete, cheveux, lunettes, cou, haut, main, dos, fond, cadre
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .tete: "Tête"
        case .cheveux: "Cheveux"
        case .lunettes: "Lunettes"
        case .cou: "Cou"
        case .haut: "Haut"
        case .main: "Mains"
        case .dos: "Dos"
        case .fond: "Fond"
        case .cadre: "Cadre"
        }
    }
}

public enum Rarity: String, CaseIterable, Codable, Sendable {
    case commun, rare, epique, legendaire
    public var title: String {
        switch self {
        case .commun: "Commun"
        case .rare: "Rare"
        case .epique: "Épique"
        case .legendaire: "Légendaire"
        }
    }
    public var colorHex: String {
        switch self {
        case .commun: "#9aa0a6"
        case .rare: "#38d6ff"
        case .epique: "#c084fc"
        case .legendaire: "#ffb000"
        }
    }
    public var order: Int {
        switch self {
        case .commun: 0
        case .rare: 1
        case .epique: 2
        case .legendaire: 3
        }
    }
}

public struct AvatarItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let slot: AvatarSlot
    public let rarity: Rarity
    public let price: Int
    /// When set, the item is unlocked by reaching this level instead of being bought.
    public let unlockLevel: Int?

    public init(id: String, name: String, slot: AvatarSlot, rarity: Rarity, price: Int, unlockLevel: Int? = nil) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.price = price
        self.unlockLevel = unlockLevel
    }

    public var isLevelLocked: Bool { unlockLevel != nil }
}

public extension AvatarItem {
    /// Sample cosmetic catalog. Cosmetic only, zero pay-to-win.
    // Grille de prix (mono-monnaie pièces). Bandes par rareté:
    // commun 200-450, rare 500-1500, épique 1500-3500, légendaire achetable 6000-50000.
    // Sol = haut.tshirt (200), plafond = fond.trounoir (50000). Les 5 légendaires
    // level-locked gardent price 0 + unlockLevel. Invariants épinglés dans Dev/Check.
    static let catalog: [AvatarItem] = [
        // Tête
        AvatarItem(id: "tete.bob", name: "Bob bucket", slot: .tete, rarity: .commun, price: 210),
        AvatarItem(id: "tete.casquette", name: "Casquette", slot: .tete, rarity: .commun, price: 230),
        AvatarItem(id: "tete.serretete", name: "Serre-tête nœud", slot: .tete, rarity: .commun, price: 250),
        AvatarItem(id: "tete.bonnet", name: "Bonnet à pompon", slot: .tete, rarity: .commun, price: 280),
        AvatarItem(id: "tete.beret", name: "Béret d'intello", slot: .tete, rarity: .rare, price: 550),
        AvatarItem(id: "tete.melon", name: "Chapeau melon", slot: .tete, rarity: .rare, price: 700),
        AvatarItem(id: "tete.hautdeforme", name: "Haut-de-forme", slot: .tete, rarity: .rare, price: 750),
        AvatarItem(id: "tete.cowboy", name: "Chapeau cowboy", slot: .tete, rarity: .rare, price: 820),
        AvatarItem(id: "tete.casque", name: "Casque audio rétro", slot: .tete, rarity: .rare, price: 950),
        AvatarItem(id: "tete.toque", name: "Toque de chef", slot: .tete, rarity: .epique, price: 1700),
        AvatarItem(id: "tete.viking", name: "Casque viking", slot: .tete, rarity: .epique, price: 2400),
        AvatarItem(id: "tete.aureole", name: "Auréole clignotante", slot: .tete, rarity: .epique, price: 2600),
        AvatarItem(id: "tete.couronne", name: "Couronne", slot: .tete, rarity: .legendaire, price: 0, unlockLevel: 20),
        // Cheveux
        AvatarItem(id: "cheveux.couettes", name: "Couettes", slot: .cheveux, rarity: .commun, price: 220),
        AvatarItem(id: "cheveux.carre", name: "Carré court", slot: .cheveux, rarity: .commun, price: 240),
        AvatarItem(id: "cheveux.banane", name: "Banane gominée", slot: .cheveux, rarity: .commun, price: 260),
        AvatarItem(id: "cheveux.afro", name: "Coupe afro", slot: .cheveux, rarity: .rare, price: 600),
        AvatarItem(id: "cheveux.fleurs", name: "Couronne de fleurs", slot: .cheveux, rarity: .rare, price: 720),
        AvatarItem(id: "cheveux.tresses", name: "Tresses arc-en-ciel", slot: .cheveux, rarity: .rare, price: 850),
        AvatarItem(id: "cheveux.mulet", name: "Mulet assumé", slot: .cheveux, rarity: .epique, price: 1600),
        AvatarItem(id: "cheveux.dragon", name: "Chignon dragon", slot: .cheveux, rarity: .epique, price: 2000),
        AvatarItem(id: "cheveux.mohawk", name: "Mohawk néon", slot: .cheveux, rarity: .epique, price: 2100),
        AvatarItem(id: "cheveux.flammes", name: "Cheveux en flammes", slot: .cheveux, rarity: .legendaire, price: 6000),
        AvatarItem(id: "cheveux.galaxie", name: "Chevelure galaxie", slot: .cheveux, rarity: .legendaire, price: 8000),
        AvatarItem(id: "cheveux.hologramme", name: "Chevelure hologramme", slot: .cheveux, rarity: .legendaire, price: 0, unlockLevel: 10),
        // Lunettes
        AvatarItem(id: "lunettes.carrees", name: "Lunettes carrées", slot: .lunettes, rarity: .commun, price: 210),
        AvatarItem(id: "lunettes.rondes", name: "Lunettes rondes", slot: .lunettes, rarity: .commun, price: 240),
        AvatarItem(id: "lunettes.soleil", name: "Lunettes de soleil", slot: .lunettes, rarity: .commun, price: 300),
        AvatarItem(id: "lunettes.coeur", name: "Lunettes cœur", slot: .lunettes, rarity: .commun, price: 330),
        AvatarItem(id: "lunettes.neon", name: "Lunettes néon", slot: .lunettes, rarity: .rare, price: 580),
        AvatarItem(id: "lunettes.pixel", name: "Lunettes pixel", slot: .lunettes, rarity: .rare, price: 780),
        AvatarItem(id: "lunettes.aviateur", name: "Aviateur miroir", slot: .lunettes, rarity: .rare, price: 900),
        AvatarItem(id: "lunettes.monocle", name: "Monocle de génie", slot: .lunettes, rarity: .epique, price: 1650),
        AvatarItem(id: "lunettes.masque", name: "Masque arcade", slot: .lunettes, rarity: .epique, price: 2200),
        AvatarItem(id: "lunettes.cyber", name: "Visière cyberpunk", slot: .lunettes, rarity: .epique, price: 2900),
        AvatarItem(id: "lunettes.diamant", name: "Lunettes diamant", slot: .lunettes, rarity: .epique, price: 3100),
        AvatarItem(id: "lunettes.lasers", name: "Lunettes à lasers", slot: .lunettes, rarity: .legendaire, price: 9000),
        // Cou
        AvatarItem(id: "cou.foulard", name: "Foulard", slot: .cou, rarity: .commun, price: 240),
        AvatarItem(id: "cou.cravate", name: "Cravate rouge", slot: .cou, rarity: .commun, price: 300),
        AvatarItem(id: "cou.echarpe", name: "Écharpe rayée", slot: .cou, rarity: .rare, price: 700),
        AvatarItem(id: "cou.chaine", name: "Chaîne en or", slot: .cou, rarity: .rare, price: 900),
        AvatarItem(id: "cou.medaille", name: "Médaille d'or", slot: .cou, rarity: .rare, price: 1100),
        AvatarItem(id: "cou.diamants", name: "Collier de diamants", slot: .cou, rarity: .epique, price: 3000),
        AvatarItem(id: "cou.cosmique", name: "Pendentif cosmique", slot: .cou, rarity: .legendaire, price: 8500),
        // Haut
        AvatarItem(id: "haut.tshirt", name: "T-shirt blanc", slot: .haut, rarity: .commun, price: 200),
        AvatarItem(id: "haut.marin", name: "Marinière", slot: .haut, rarity: .commun, price: 270),
        AvatarItem(id: "haut.pull", name: "Pull pixel", slot: .haut, rarity: .commun, price: 320),
        AvatarItem(id: "haut.hoodie", name: "Hoodie streetwear", slot: .haut, rarity: .commun, price: 340),
        AvatarItem(id: "haut.hawaii", name: "Chemise hawaïenne", slot: .haut, rarity: .rare, price: 650),
        AvatarItem(id: "haut.maillot", name: "Maillot de foot", slot: .haut, rarity: .rare, price: 680),
        AvatarItem(id: "haut.kimono", name: "Kimono", slot: .haut, rarity: .rare, price: 950),
        AvatarItem(id: "haut.bomber", name: "Bomber satin", slot: .haut, rarity: .rare, price: 1000),
        AvatarItem(id: "haut.veste", name: "Veste arcade", slot: .haut, rarity: .rare, price: 1200),
        AvatarItem(id: "haut.costume", name: "Costume", slot: .haut, rarity: .epique, price: 2400),
        AvatarItem(id: "haut.combinaison", name: "Combi spatiale", slot: .haut, rarity: .epique, price: 2700),
        AvatarItem(id: "haut.smoking", name: "Smoking pailleté", slot: .haut, rarity: .epique, price: 3000),
        AvatarItem(id: "haut.armure", name: "Armure de champion", slot: .haut, rarity: .legendaire, price: 0, unlockLevel: 5),
        // Mains (objet tenu)
        AvatarItem(id: "main.cafe", name: "Tasse de café", slot: .main, rarity: .commun, price: 250),
        AvatarItem(id: "main.ballon", name: "Ballon de foot", slot: .main, rarity: .commun, price: 320),
        AvatarItem(id: "main.manette", name: "Manette de jeu", slot: .main, rarity: .commun, price: 360),
        AvatarItem(id: "main.micro", name: "Micro doré", slot: .main, rarity: .rare, price: 850),
        AvatarItem(id: "main.baguette", name: "Baguette magique", slot: .main, rarity: .rare, price: 1000),
        AvatarItem(id: "main.bouclier", name: "Bouclier", slot: .main, rarity: .rare, price: 1200),
        AvatarItem(id: "main.epee", name: "Épée de chevalier", slot: .main, rarity: .epique, price: 2600),
        AvatarItem(id: "main.sabre", name: "Sabre laser", slot: .main, rarity: .legendaire, price: 9000),
        // Dos (cape, ailes, sac)
        AvatarItem(id: "dos.sac", name: "Sac à dos", slot: .dos, rarity: .commun, price: 300),
        AvatarItem(id: "dos.cape", name: "Cape de héros", slot: .dos, rarity: .rare, price: 900),
        AvatarItem(id: "dos.katana", name: "Katana dans le dos", slot: .dos, rarity: .rare, price: 1100),
        AvatarItem(id: "dos.ailes", name: "Ailes d'ange", slot: .dos, rarity: .epique, price: 2800),
        AvatarItem(id: "dos.jetpack", name: "Jetpack", slot: .dos, rarity: .epique, price: 3200),
        AvatarItem(id: "dos.ailesdemon", name: "Ailes de démon", slot: .dos, rarity: .legendaire, price: 9500),
        // Fond
        AvatarItem(id: "fond.uni", name: "Fond uni", slot: .fond, rarity: .commun, price: 200),
        AvatarItem(id: "fond.degrade", name: "Fond dégradé", slot: .fond, rarity: .commun, price: 250),
        AvatarItem(id: "fond.damier", name: "Damier rétro", slot: .fond, rarity: .commun, price: 280),
        AvatarItem(id: "fond.grille", name: "Grille rétro", slot: .fond, rarity: .rare, price: 520),
        AvatarItem(id: "fond.etoiles", name: "Ciel étoilé", slot: .fond, rarity: .rare, price: 700),
        AvatarItem(id: "fond.neon", name: "Néon ville", slot: .fond, rarity: .rare, price: 760),
        AvatarItem(id: "fond.crt", name: "Fond CRT", slot: .fond, rarity: .epique, price: 1800),
        AvatarItem(id: "fond.aurore", name: "Aurore boréale", slot: .fond, rarity: .epique, price: 2100),
        AvatarItem(id: "fond.synthwave", name: "Fond synthwave", slot: .fond, rarity: .epique, price: 2300),
        AvatarItem(id: "fond.lave", name: "Champ de lave", slot: .fond, rarity: .epique, price: 2600),
        AvatarItem(id: "fond.galaxie", name: "Galaxie tourbillon", slot: .fond, rarity: .epique, price: 3200),
        AvatarItem(id: "fond.trounoir", name: "Trou noir animé", slot: .fond, rarity: .legendaire, price: 50000),
        // Cadre
        AvatarItem(id: "cadre.bois", name: "Cadre bois", slot: .cadre, rarity: .commun, price: 230),
        AvatarItem(id: "cadre.pixel", name: "Cadre pixel", slot: .cadre, rarity: .commun, price: 300),
        AvatarItem(id: "cadre.argent", name: "Cadre argent", slot: .cadre, rarity: .rare, price: 560),
        AvatarItem(id: "cadre.neon", name: "Cadre néon", slot: .cadre, rarity: .rare, price: 900),
        AvatarItem(id: "cadre.vert", name: "Cadre vert", slot: .cadre, rarity: .rare, price: 1100),
        AvatarItem(id: "cadre.flammes", name: "Cadre flammes", slot: .cadre, rarity: .epique, price: 1900),
        AvatarItem(id: "cadre.glace", name: "Cadre de glace", slot: .cadre, rarity: .epique, price: 2500),
        AvatarItem(id: "cadre.lauriers", name: "Cadre lauriers", slot: .cadre, rarity: .epique, price: 2800),
        AvatarItem(id: "cadre.diamant", name: "Cadre diamant", slot: .cadre, rarity: .epique, price: 3500),
        AvatarItem(id: "cadre.arcenciel", name: "Cadre arc-en-ciel", slot: .cadre, rarity: .legendaire, price: 0, unlockLevel: 10),
        AvatarItem(id: "cadre.foudre", name: "Cadre foudre", slot: .cadre, rarity: .legendaire, price: 9500),
        AvatarItem(id: "cadre.or", name: "Cadre or", slot: .cadre, rarity: .legendaire, price: 0, unlockLevel: 15),
    ]

    static func item(id: String) -> AvatarItem? { catalog.first { $0.id == id } }

    static func items(slot: AvatarSlot) -> [AvatarItem] {
        catalog.filter { $0.slot == slot }.sorted { $0.rarity.order < $1.rarity.order }
    }
}
