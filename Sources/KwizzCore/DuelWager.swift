import Foundation

/// La mise d'un duel en ligne. L'hôte la règle au curseur dans le salon, chaque
/// joueur la paie en entrant, et le vainqueur rafle la cagnotte : mise × nombre de
/// joueurs (donc « trois fois sa mise » dans une partie à trois).
///
/// Type pur et déterministe : c'est lui qui décide combien de pièces chaque joueur
/// gagne ou perd, `Economy.coins` ne fait que l'appliquer.
public struct DuelWager: Codable, Hashable, Sendable {
    /// Mise proposée par défaut quand l'hôte en a les moyens.
    public static let defaultStake = 100

    // MARK: Le curseur

    /// Raideur de la courbe du curseur. La mise suit une exponentielle de la
    /// position : à gauche la poignée avance pièce par pièce (réglage fin des
    /// petites mises), à droite elle accélère fortement. Avec 4.5, la première
    /// moitié de course couvre ~10 % du porte-monnaie et la seconde les 90 % restants.
    public static let curve = 4.5

    /// Position du curseur (0...1) → mise en pièces, arrondie à un pas lisible et
    /// jamais au-dessus du porte-monnaie.
    public static func stake(atPosition position: Double, maxStake: Int) -> Int {
        guard maxStake > 0 else { return 0 }
        let t = min(max(position, 0), 1)
        // Bord droit franc : « tout miser » doit donner le porte-monnaie exact,
        // pas un arrondi qui retomberait juste en dessous.
        guard t < 0.999 else { return maxStake }
        let raw = Double(maxStake) * (exp(curve * t) - 1) / (exp(curve) - 1)
        return min(maxStake, snap(Int(raw.rounded())))
    }

    /// Mise → position du curseur, l'inverse de `stake(atPosition:maxStake:)` (à
    /// l'arrondi près). Sert à replacer la poignée quand la vue se redessine.
    public static func position(ofStake stake: Int, maxStake: Int) -> Double {
        guard maxStake > 0 else { return 0 }
        let clamped = min(max(stake, 0), maxStake)
        let ratio = Double(clamped) / Double(maxStake)
        return min(max(log(1 + ratio * (exp(curve) - 1)) / curve, 0), 1)
    }

    /// Arrondi « lisible » : plus la mise est grosse, plus le pas est gros, pour ne
    /// jamais afficher un montant comme 743 pièces.
    public static func snap(_ value: Int) -> Int {
        let v = max(0, value)
        let step: Int
        switch v {
        case ..<50:    step = 1
        case ..<200:   step = 5
        case ..<1_000: step = 10
        case ..<5_000: step = 25
        default:       step = 100
        }
        return Int((Double(v) / Double(step)).rounded()) * step
    }

    /// La mise présélectionnée à la création d'une partie : la mise par défaut, ou
    /// tout le porte-monnaie s'il est plus maigre que ça.
    public static func suggestedStake(coins: Int) -> Int {
        min(defaultStake, max(0, coins))
    }

    // MARK: Le règlement

    /// Mise payée par chaque joueur.
    public let stake: Int
    /// Nombre de joueurs ayant misé (figé au lancement de la manche).
    public let playerCount: Int
    /// Nombre de vainqueurs (> 1 en cas d'égalité en tête : la cagnotte est partagée).
    public let winnerCount: Int

    public init(stake: Int, playerCount: Int, winnerCount: Int) {
        self.stake = max(0, stake)
        self.playerCount = max(1, playerCount)
        self.winnerCount = max(1, winnerCount)
    }

    /// Total mis en jeu par la table.
    public var pot: Int { stake * playerCount }

    /// Part brute revenant à chaque vainqueur (mise comprise).
    public var winnerShare: Int { pot / winnerCount }

    /// Variation nette du portefeuille : le vainqueur récupère sa part moins sa
    /// propre mise, les autres perdent la leur.
    public func payout(isWinner: Bool) -> Int {
        isWinner ? winnerShare - stake : -stake
    }
}
