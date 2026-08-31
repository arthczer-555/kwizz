import SwiftUI
import Observation

/// The app's single source of truth: the saved profile, the loaded question bank,
/// and the accent preference. Persists the profile to Application Support as JSON.
@MainActor
@Observable
final class PlayerStore {
    var profile: PlayerProfile
    var accent: Theme.Accent
    var hasOnboarded: Bool
    var adminEnabled: Bool
    let bank: QuestionBank
    /// Stable per-device identity for online duels (no account needed).
    let clientID: String

    private let saveURL: URL
    private let adminBackupURL: URL

    private var needsUnlockBackfill = false

    init() {
        let url = Self.makeSaveURL()
        self.saveURL = url
        self.adminBackupURL = url.deletingLastPathComponent().appendingPathComponent("kwizz_profile_preadmin.json")
        self.bank = ContentLoader.loadBank()

        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            self.profile = saved
            self.hasOnboarded = true
            needsUnlockBackfill = true
        } else {
            self.profile = PlayerProfile()
            self.hasOnboarded = false
        }

        let raw = UserDefaults.standard.string(forKey: "kwizz.accent") ?? Theme.Accent.vert.rawValue
        self.accent = Theme.Accent(rawValue: raw) ?? .vert

        self.adminEnabled = UserDefaults.standard.bool(forKey: "kwizz.admin")

        if let saved = UserDefaults.standard.string(forKey: "kwizz.clientID") {
            self.clientID = saved
        } else {
            let fresh = UUID().uuidString
            UserDefaults.standard.set(fresh, forKey: "kwizz.clientID")
            self.clientID = fresh
        }

        if needsUnlockBackfill, grantMissingLevelUnlocks() { save() }

        consumeInterruptedDefi()
    }

    // MARK: Derived

    var accentColor: Color { accent.color }

    func today() -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return DailyChallenge.day(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    var dailyAvailable: Bool { profile.lastDailyDay != today() }

    // MARK: Défi du jour (anti-abandon)

    /// Jour du défi actuellement en cours. Posé au lancement de la partie, effacé
    /// dès qu'elle est validée (fin normale ou abandon). S'il survit à la fermeture
    /// de l'app, c'est que le joueur l'a tuée en pleine partie.
    private static let defiInProgressKey = "kwizz.defiInProgressDay"

    func markDefiInProgress() {
        UserDefaults.standard.set(today(), forKey: Self.defiInProgressKey)
    }

    func clearDefiInProgress() {
        UserDefaults.standard.removeObject(forKey: Self.defiInProgressKey)
    }

    /// Ferme le contournement « je tue l'app pour rejouer le défi » : au lancement,
    /// un marqueur laissé sur le jour courant consomme la tentative (score perdu).
    /// Le marqueur n'est jamais honoré pour un autre jour, il est simplement
    /// nettoyé : impossible de bloquer le joueur le lendemain.
    private func consumeInterruptedDefi() {
        let defaults = UserDefaults.standard
        guard let day = defaults.object(forKey: Self.defiInProgressKey) as? Int else { return }
        defaults.removeObject(forKey: Self.defiInProgressKey)
        guard day == today(), profile.lastDailyDay != day else { return }
        profile.registerDaily(day: day)
        save()
    }

    // MARK: Onboarding

    func completeOnboarding(pseudo: String) {
        setPseudo(pseudo)
        hasOnboarded = true
        save()
    }

    /// Adopte en local le pseudo réservé côté serveur. Passer par
    /// `SupabaseService.claimPseudo` d'abord (cf. `PseudoClaim`) : les pseudos
    /// sont uniques, écrire ici sans réservation désynchronise du classement.
    func setPseudo(_ pseudo: String) {
        let name = pseudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        profile.pseudo = String(name.prefix(24))
        save()
    }

    // MARK: Building a game

    /// IDs served in recent rounds (newest last), used to steer new games away from
    /// just-seen questions so Classique etc. don't repeat across consecutive parties.
    private var recentlyServed: [String] = []
    private let recentlyServedCap = 200

    /// `difficulty` is nil when the player picked "toutes les difficultés" (Entraînement).
    func makeSession(mode: GameMode, category: Category?, subcategory: Subcategory?, difficulty: Difficulty?) -> QuizSession {
        let catID = category?.id
        let questions: [Question]
        let resolvedCat: String?
        let recent = Set(recentlyServed)
        switch mode {
        case .defi:
            questions = DailyChallenge.questions(from: bank.all, day: today())
            resolvedCat = Category.melange.id
        case .entrainement:
            // Seul mode personnalisable : on filtre par thème, sous-thème et difficulté
            // choisis. difficulty nil = « toutes les difficultés », le banc ne filtre pas.
            questions = bank.query(categoryID: catID, subcategoryID: subcategory?.id, difficulty: difficulty,
                                   count: mode.questionCount ?? 80, excluding: recent)
            resolvedCat = catID
        case .classique, .survie, .contreLaMontre, .duel:
            // Tout mélangé : toutes les catégories et toutes les difficultés confondues.
            let count = mode.questionCount ?? 80
            questions = bank.query(categoryID: nil, subcategoryID: nil, difficulty: nil, count: count, excluding: recent)
            resolvedCat = Category.melange.id
        }
        rememberServed(questions)
        return QuizSession(mode: mode, difficulty: difficulty, categoryID: resolvedCat, questions: questions)
    }

    // MARK: Online duel

    /// This device's identity in a duel room, coloured by the chosen accent.
    func duelPlayer(isHost: Bool) -> DuelPlayer {
        DuelPlayer(clientID: clientID, pseudo: profile.pseudo, accentHex: accent.hex, isHost: isHost)
    }

    /// Builds the questions a duel host deals to the room. Seeded so a round is
    /// reproducible; the host broadcasts the resulting questions verbatim, so guests
    /// never need an identical local question bank. `count` vient des réglages de
    /// la partie (l'hôte choisit la longueur de la manche).
    /// `categoryID` vaut `Category.melange.id` (ou nil) pour piocher dans tous les
    /// thèmes ; sinon toute la manche sort du thème choisi par l'hôte.
    func makeDuelQuestions(seed: UInt64, count: Int = DuelSettings.defaultQuestionCount,
                           categoryID: String? = nil) -> [Question] {
        bank.query(categoryID: categoryID, subcategoryID: nil, difficulty: nil,
                   count: max(1, count), seed: seed)
    }

    /// Records the questions just dealt and trims the history to its cap.
    private func rememberServed(_ questions: [Question]) {
        recentlyServed.append(contentsOf: questions.map(\.id))
        if recentlyServed.count > recentlyServedCap {
            recentlyServed.removeFirst(recentlyServed.count - recentlyServedCap)
        }
    }

    // MARK: Applying a finished game

    @discardableResult
    func finish(result: GameResult) -> AppliedResult {
        let day = today()
        let applied = profile.apply(result: result, day: day)
        for lvl in applied.leveledUpTo {
            // Un palier peut porter plusieurs cosmétiques (ex: niveau 10) : tous sont dus.
            let unlocks = AvatarItem.catalog.filter { $0.unlockLevel == lvl }
            if unlocks.isEmpty {
                if let rarity = LevelTable.reward(reachingLevel: lvl).itemRarity {
                    grantItem(rarity: rarity)
                }
            } else {
                for item in unlocks { profile.ownedItemIDs.insert(item.id) }
            }
        }
        if result.mode == .defi {
            profile.registerDaily(day: day,
                                  correct: result.correctCount,
                                  reward: Economy.defiReward(errors: result.total - result.correctCount))
            // La partie est validée : le marqueur « défi en cours » n'a plus lieu d'être.
            clearDefiInProgress()
        }
        profile.applyWelcomeBonusIfNeeded()
        save()
        return applied
    }

    // MARK: Variable rewards (wheel + chests)

    var wheelAvailable: Bool { profile.lastWheelDay != today() }

    /// Spins the daily wheel once, credits the coins, returns the amount won.
    @discardableResult
    func spinWheel() -> Int {
        guard wheelAvailable else { return 0 }
        let amount = DailyWheel.spin(day: today())
        profile.lastWheelDay = today()
        profile.coins = max(0, profile.coins + amount)
        save()
        return amount
    }

    /// Opens one owned chest. Returns coins or a granted item, or nil if none held.
    @discardableResult
    func openChest() -> ChestResult? {
        guard profile.ownedChests > 0 else { return nil }
        let result = MysteryChest.open(open: profile.chestOpenCount, owned: profile.ownedItemIDs)
        profile.ownedChests -= 1
        profile.chestOpenCount += 1
        if let itemID = result.itemID {
            profile.ownedItemIDs.insert(itemID)
        } else {
            profile.coins = max(0, profile.coins + result.coins)
        }
        save()
        return result
    }

    private func grantItem(rarity: Rarity) {
        let owned = profile.ownedItemIDs
        if let item = AvatarItem.catalog.first(where: { $0.rarity == rarity && $0.unlockLevel == nil && !owned.contains($0.id) }) {
            profile.ownedItemIDs.insert(item.id)
        } else if let any = AvatarItem.catalog.first(where: { $0.unlockLevel == nil && !owned.contains($0.id) }) {
            profile.ownedItemIDs.insert(any.id)
        }
    }

    // MARK: Shop / avatar

    func isOwned(_ item: AvatarItem) -> Bool { profile.ownedItemIDs.contains(item.id) }

    /// Rattrape les cosmétiques level-locked dont le palier est déjà franchi mais
    /// qui n'ont jamais été crédités (profil antérieur au palier, palier multiple
    /// manqué, niveau gagné hors `finish`). Sans ça ils s'affichent en boutique
    /// comme achetables à 0 pièce. Retourne true si le profil a changé.
    @discardableResult
    func grantMissingLevelUnlocks() -> Bool {
        let due = AvatarItem.catalog.filter { item in
            guard let level = item.unlockLevel else { return false }
            return profile.level >= level && !profile.ownedItemIDs.contains(item.id)
        }
        guard !due.isEmpty else { return false }
        for item in due { profile.ownedItemIDs.insert(item.id) }
        return true
    }

    func isUnlocked(_ item: AvatarItem) -> Bool {
        if let level = item.unlockLevel { return profile.level >= level }
        return true
    }

    @discardableResult
    func buy(_ item: AvatarItem) -> Bool {
        guard !isOwned(item) else { return true }
        guard item.unlockLevel == nil, item.price > 0 else { return false }
        guard profile.coins >= item.price else { return false }
        profile.coins -= item.price
        profile.ownedItemIDs.insert(item.id)
        save()
        return true
    }

    func equip(_ item: AvatarItem) {
        guard isOwned(item) else { return }
        profile.equipped[item.slot.rawValue] = item.id
        save()
    }

    /// Vide un slot : plus rien d'équipé dans cette catégorie.
    func unequip(slot: AvatarSlot) {
        guard profile.equipped[slot.rawValue] != nil else { return }
        profile.equipped[slot.rawValue] = nil
        save()
    }

    /// Équipe l'item, ou le retire s'il est déjà équipé (tap = bascule).
    func toggleEquip(_ item: AvatarItem) {
        if isEquipped(item) {
            unequip(slot: item.slot)
        } else {
            equip(item)
        }
    }

    func isEquipped(_ item: AvatarItem) -> Bool {
        profile.equipped[item.slot.rawValue] == item.id
    }

    func equippedItem(slot: AvatarSlot) -> AvatarItem? {
        guard let id = profile.equipped[slot.rawValue] else { return nil }
        return AvatarItem.item(id: id)
    }

    // MARK: Settings

    func setAccent(_ accent: Theme.Accent) {
        self.accent = accent
        UserDefaults.standard.set(accent.rawValue, forKey: "kwizz.accent")
    }

    func toggleSound() { profile.soundOn.toggle(); save() }
    func toggleMusic() { profile.musicOn.toggle(); save() }
    func toggleNotifications() { profile.notificationsOn.toggle(); save() }

    // MARK: Admin / debug

    /// Turning admin ON snapshots the current profile to disk; turning it OFF
    /// restores that snapshot (discarding any admin changes) and removes it.
    func toggleAdmin() {
        if adminEnabled {
            restorePreAdminSnapshot()
            adminEnabled = false
        } else {
            savePreAdminSnapshot()
            adminEnabled = true
        }
        UserDefaults.standard.set(adminEnabled, forKey: "kwizz.admin")
    }

    private func savePreAdminSnapshot() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: adminBackupURL, options: .atomic)
    }

    private func restorePreAdminSnapshot() {
        if let data = try? Data(contentsOf: adminBackupURL),
           let saved = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = saved
            save()
        }
        try? FileManager.default.removeItem(at: adminBackupURL)
    }

    /// Sets the player straight to the given level by jumping `totalXP` to the
    /// cumulative threshold of that level (1...maxLevel).
    func setLevel(_ level: Int) {
        let clamped = min(max(level, 1), LevelTable.maxLevel)
        profile.totalXP = LevelTable.cumulative[clamped - 1]
        save()
    }

    func setCoins(_ amount: Int) {
        profile.coins = max(0, amount)
        save()
    }

    func addCoins(_ amount: Int) {
        profile.coins = max(0, profile.coins + amount)
        save()
    }

    /// Debug: grant a chest and make the wheel spinnable again.
    func grantChest() {
        profile.ownedChests += 1
        save()
    }

    func resetWheel() {
        profile.lastWheelDay = 0
        save()
    }

    /// Grants every catalogue item, ignoring price and level locks.
    func unlockAllItems() {
        profile.ownedItemIDs = Set(AvatarItem.catalog.map(\.id))
        save()
    }

    /// Removes every owned and equipped item.
    func lockAllItems() {
        profile.ownedItemIDs = []
        profile.equipped = [:]
        save()
    }

    /// Wipes the save back to a fresh profile (keeps the current pseudo).
    func resetProfile() {
        let pseudo = profile.pseudo
        profile = PlayerProfile(pseudo: pseudo)
        clearDefiInProgress()
        save()
    }

    // MARK: Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private static func makeSaveURL() -> URL {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        return dir.appendingPathComponent("kwizz_profile.json")
    }
}
