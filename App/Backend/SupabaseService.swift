import Foundation
import Observation
#if canImport(Supabase)
import Supabase
#endif

/// Backend gateway for the online phase: anonymous auth + profile sync to the
/// Supabase `profiles` table. It degrades gracefully: if the `supabase-swift`
/// package or the `SUPABASE_*` config keys are absent, every call is a no-op and
/// the app keeps working fully offline (same philosophy as `MockDuelTransport`).
///
/// Phase 0 of docs/PLAN_LIGUE.md. The SDK-specific calls target supabase-swift
/// v2.x; if your installed version differs, the three spots to verify are
/// `auth.currentUser`, `auth.signInAnonymously()`, and `from(...).upsert(...)`.
@MainActor
@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    enum Status: Equatable {
        case offline        // no SDK / no config: pure offline mode
        case connecting
        case online         // anonymous session established
        case failed(String)
    }

    private(set) var status: Status = .offline
    /// `auth.users.id` once the anonymous session exists. Nil while offline.
    private(set) var userID: String?

    #if canImport(Supabase)
    private var client: SupabaseClient?
    /// In-flight sign-in, partagée par les appelants concurrents (cf. `start()`).
    private var startTask: Task<Void, Never>?
    #endif

    private init() {}

    /// Ensures an anonymous auth session exists. Safe to call repeatedly (idempotent).
    ///
    /// Deux écueils traités ici, car plusieurs écrans (Accueil, Classement, Ligue)
    /// appellent `start()` quasi en même temps :
    ///  1. Déjà en ligne -> on ne refait rien, et surtout on ne repasse PAS en
    ///     `.connecting` (les lectures se gardent sur `status == .online` et
    ///     échoueraient par à-coups sinon).
    ///  2. On sérialise les appels concurrents pour ne lancer qu'UN seul
    ///     `signInAnonymously()`. Sans ça, deux connexions en vol créent deux
    ///     sessions anonymes et un va-et-vient de jeton qui fait rater une requête
    ///     sur deux (symptôme : le classement clignote entre "vide" et rempli).
    func start() async {
        #if canImport(Supabase)
        if case .online = status, client != nil { return }
        if let startTask { return await startTask.value }
        let task = Task { await self.connect() }
        startTask = task
        await task.value
        startTask = nil
        #else
        status = .offline
        #endif
    }

    #if canImport(Supabase)
    /// Établit la session anonyme (réutilise celle persistée, sinon se connecte).
    private func connect() async {
        guard let config = SupabaseConfig.current else { status = .offline; return }
        status = .connecting
        let client = self.client ?? SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        self.client = client
        do {
            // On exige une session au jeton VALIDE, pas seulement un utilisateur en
            // cache. `auth.session` rafraîchit le jeton si besoin et LÈVE si la
            // session persistée est morte (refresh token périmé/invalide). L'ancien
            // code se fiait à `currentUser`, qui renvoie l'utilisateur d'une session
            // même expirée, et se déclarait "online" : les appels d'Edge Functions
            // repartaient alors avec la clé anon (faute de jeton refraîchissable)
            // -> 401 "unauthorized" (symptôme : le matchmaking classé). Si la
            // session est inexploitable, on se reconnecte à neuf.
            let session = try await validSession(for: client)
            userID = session.user.id.uuidString.lowercased()
            status = .online
        } catch {
            // Most likely cause: "Anonymous sign-ins" is still disabled in the
            // Supabase dashboard (Authentication > Providers). Non-fatal.
            status = .failed(error.localizedDescription)
        }
    }

    /// Une session au jeton exploitable : réutilise la session courante (que
    /// `auth.session` rafraîchit au besoin). On ne crée une NOUVELLE session
    /// anonyme QUE s'il n'existe aucune session stockée (vraie première ouverture).
    ///
    /// Garde-fou anti-doublon d'identité : si `auth.session` échoue alors qu'une
    /// session est BIEN stockée (Keychain), c'est presque toujours un raté
    /// TRANSITOIRE du refresh (réseau pas prêt au lancement à froid le lendemain ;
    /// le SDK garde la session sur disque, cf. SessionManager.refreshSession qui
    /// ne supprime rien en cas d'échec). Forger une nouvelle session anonyme dans
    /// ce cas abandonnait le compte du joueur : le score de la veille restait
    /// orphelin sur l'ancien user_id et un 2e profil (pseudo « RetroKid » par
    /// défaut) apparaissait dans le classement mensuel. On PROPAGE donc l'erreur
    /// (l'app retentera au prochain `start()`, avec la MÊME identité) au lieu de
    /// repartir de zéro.
    private func validSession(for client: SupabaseClient) async throws -> Session {
        do {
            return try await client.auth.session
        } catch {
            // currentSession lit la session persistée sans la rafraîchir : non-nil
            // => une identité existe déjà, l'échec est transitoire -> on retentera.
            if client.auth.currentSession != nil { throw error }
            return try await client.auth.signInAnonymously()
        }
    }
    #endif

    /// Upserts the local profile into `profiles`. RLS allows a user to write only
    /// its own row (`auth.uid() = id`), which the anonymous session satisfies.
    /// A failed sync never disrupts play; it only flips `status` to `.failed`.
    func syncProfile(_ profile: PlayerProfile, accent: String) async {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return }
        do {
            try await client.from("profiles").upsert(ProfileRow(id: id, profile: profile, accent: accent)).execute()
        } catch {
            // Le pseudo est UNIQUE en base : si le joueur a gardé en local un pseudo
            // entre-temps pris par quelqu'un d'autre, l'upsert entier échoue et ses
            // stats ne remonteraient JAMAIS. On rejoue donc l'écriture sans le
            // pseudo (le serveur fait foi pour ce champ ; c'est claim_pseudo qui le
            // change, avec un vrai message d'erreur côté UI).
            try? await client.from("profiles")
                .update(ProfileStatsRow(profile: profile, accent: accent))
                .eq("id", value: id)
                .execute()
            // Non-fatal: a failed write must NOT flip the app to "offline" (status
            // reflects the auth session, not the last operation). The leaderboard
            // and ranked screens gate their UI on `status`, so keep it as-is.
        }
        #endif
    }

    /// Réplique l'équipement de l'avatar (PlayerProfile.equipped : [slot : item_id])
    /// dans `equipped_items`, pour que le perso du joueur soit reconstituable par les
    /// autres (profil public). On remplace intégralement les lignes du joueur : delete
    /// de tout son équipement puis insert du map courant. Non-fatal (ne bascule pas
    /// l'app hors ligne en cas d'échec) et no-op hors ligne.
    func syncEquipped(_ equipped: [String: String]) async {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return }
        struct EquippedRow: Encodable { let user_id: String; let slot: String; let item_id: String }
        let rows = equipped.map { EquippedRow(user_id: id, slot: $0.key, item_id: $0.value) }
        do {
            try await client.from("equipped_items").delete().eq("user_id", value: id).execute()
            if !rows.isEmpty {
                try await client.from("equipped_items").insert(rows).execute()
            }
        } catch {
            // Non-fatal : idem syncProfile, l'état online reflète la session, pas l'écriture.
        }
        #endif
    }

    /// Profil public d'un autre joueur (RPC `get_public_profile`) : les seuls champs
    /// exposés hors du propriétaire (le RLS reste fermé sur les tables de base).
    /// Sert à afficher, depuis le classement, le profil d'un joueur avec ses scores
    /// et son perso (avatar reconstruit depuis `equipped` + accent + niveau via XP).
    struct PublicProfile: Decodable, Sendable {
        struct Equipped: Decodable, Sendable { let slot: String; let item_id: String }
        let user_id: String
        let pseudo: String
        let total_xp: Int
        let accent: String?
        let games_played: Int
        let total_correct: Int
        let total_answered: Int
        let best_streak_ever: Int
        let best_score: Int
        let equipped: [Equipped]
    }

    /// Charge le profil public de `userID`. Renvoie `nil` hors ligne ou en cas d'échec
    /// (l'appelant affiche alors un panneau "indisponible").
    func publicProfile(userID: String) async -> PublicProfile? {
        #if canImport(Supabase)
        guard case .online = status, let client else { return nil }
        struct Params: Encodable { let p_user_id: String }
        do {
            return try await client
                .rpc("get_public_profile", params: Params(p_user_id: userID))
                .execute().value
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Résultat d'une tentative de réservation de pseudo (RPC `claim_pseudo`).
    enum ClaimPseudoResult: String, Sendable {
        /// Réservé : le pseudo est désormais celui du joueur.
        case ok
        /// Déjà porté par un autre joueur.
        case taken
        /// Vide, trop court ou trop long (2..24 caractères).
        case invalid
        /// Hors ligne / échec réseau : impossible de trancher maintenant.
        case unavailable
    }

    /// Réserve `pseudo` pour le joueur courant. L'unicité ne peut pas être testée
    /// côté client (RLS ne laisse lire que son propre profil), d'où la RPC.
    func claimPseudo(_ pseudo: String) async -> ClaimPseudoResult {
        #if canImport(Supabase)
        guard case .online = status, let client else { return .unavailable }
        struct Params: Encodable { let p_pseudo: String }
        do {
            let raw: String = try await client
                .rpc("claim_pseudo", params: Params(p_pseudo: pseudo))
                .execute().value
            return ClaimPseudoResult(rawValue: raw) ?? .unavailable
        } catch {
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    /// One answered question of a daily challenge, for server-side validation.
    /// `choice` is the chosen answer's text (nil on timeout); the server compares
    /// it to the question's canonical correct answer, so the client cannot lie.
    /// `Codable` : on persiste les réponses en local pour pouvoir RENVOYER un défi
    /// terminé qui n'aurait pas pu partir (hors ligne / raté réseau).
    struct DailyAnswer: Codable, Sendable {
        let id: String
        let choice: String?
    }

    /// Un défi terminé en attente d'envoi (file locale, persistée dans UserDefaults).
    private struct PendingDaily: Codable { let dayIndex: Int; let answers: [DailyAnswer] }
    private static let pendingDailyKey = "pendingDailySubmissions"

    /// Submits a finished daily challenge to the `submit-daily` Edge Function, which
    /// re-scores it server-side and records one `daily_results` row (1 attempt/day).
    ///
    /// FIABLE (ne perd plus jamais un défi terminé) : on l'enregistre d'abord en
    /// local, puis on garantit la session et on tente l'envoi ; ce qui n'est pas
    /// passé est renvoyé au prochain `start()` (cf. `flushPendingDaily`). Avant,
    /// c'était du fire-and-forget : si la session n'était pas en ligne pile à cet
    /// instant, ou au moindre raté réseau, le score était abandonné en silence.
    func submitDaily(dayIndex: Int, answers: [DailyAnswer]) async {
        #if canImport(Supabase)
        guard !answers.isEmpty else { return }
        enqueuePendingDaily(dayIndex: dayIndex, answers: answers)
        await start()
        await flushPendingDaily()
        #endif
    }

    /// Renvoie les défis terminés encore en attente. Idempotent et sûr à rappeler :
    /// au lancement (RootView) et après chaque soumission. Garde en file ce qui
    /// échoue (nouvel essai plus tard) ; retire ce qui passe (200, y compris le cas
    /// "déjà soumis" que l'Edge Function renvoie aussi en 200).
    func flushPendingDaily() async {
        #if canImport(Supabase)
        var pending = loadPendingDaily()
        guard !pending.isEmpty, case .online = status, let client else { return }
        struct Payload: Encodable { let dayIndex: Int; let answers: [DailyAnswer] }
        for entry in pending {
            do {
                try await client.functions.invoke(
                    "submit-daily",
                    options: .init(body: Payload(dayIndex: entry.dayIndex, answers: entry.answers))
                )
                pending.removeAll { $0.dayIndex == entry.dayIndex }
                savePendingDaily(pending)
            } catch {
                // On garde l'entrée : nouvel essai au prochain start()/lancement.
            }
        }
        #endif
    }

    private func enqueuePendingDaily(dayIndex: Int, answers: [DailyAnswer]) {
        var items = loadPendingDaily()
        guard !items.contains(where: { $0.dayIndex == dayIndex }) else { return }
        items.append(PendingDaily(dayIndex: dayIndex, answers: answers))
        savePendingDaily(items)
    }

    private func loadPendingDaily() -> [PendingDaily] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDailyKey) else { return [] }
        return (try? JSONDecoder().decode([PendingDaily].self, from: data)) ?? []
    }

    private func savePendingDaily(_ items: [PendingDaily]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: Self.pendingDailyKey)
    }

    /// One row of the monthly daily-challenge leaderboard (view
    /// `monthly_challenge_leaderboard`): a player's total over their best 25 days.
    struct MonthlyEntry: Decodable, Identifiable, Sendable {
        let user_id: String
        let pseudo: String
        let total: Int
        let days_counted: Int
        let rank: Int
        var id: String { user_id }
    }

    /// Top of the monthly leaderboard for `month` (format AAAAMM), ordered by rank.
    /// Renvoie `[]` quand il n'y a légitimement rien (hors ligne / mois vide) mais
    /// PROPAGE l'erreur quand la requête échoue : l'appelant doit pouvoir distinguer
    /// "classement vide" d'un "échec réseau", sinon un simple à-coup réseau efface
    /// un classement déjà chargé et affiche "Personne encore" à tort.
    func monthlyLeaderboard(month: Int, limit: Int = 100) async throws -> [MonthlyEntry] {
        #if canImport(Supabase)
        guard case .online = status, let client else { return [] }
        return try await client.from("monthly_challenge_leaderboard")
            .select()
            .eq("month", value: month)
            .order("rank", ascending: true)
            .limit(limit)
            .execute().value
        #else
        return []
        #endif
    }

    /// The current player's own row for `month`, to pin it even when outside the top.
    /// Propage l'erreur pour la même raison que `monthlyLeaderboard`.
    func myMonthly(month: Int) async throws -> MonthlyEntry? {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return nil }
        let rows: [MonthlyEntry] = try await client.from("monthly_challenge_leaderboard")
            .select()
            .eq("month", value: month)
            .eq("user_id", value: id)
            .limit(1)
            .execute().value
        return rows.first
        #else
        return nil
        #endif
    }

    /// An end-of-month reward owed to the player (row of `monthly_rewards`).
    struct MonthlyReward: Decodable, Sendable {
        let month: Int
        let rank: Int
        let coins: Int
        let chests: Int
        let cosmetic_id: String?
    }

    /// Fetches the player's not-yet-granted monthly rewards and marks them granted,
    /// returning them so the caller can apply the coins/chests to the local profile.
    /// Returns [] when offline or nothing is owed.
    func claimMonthlyRewards() async -> [MonthlyReward] {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return [] }
        do {
            let pending: [MonthlyReward] = try await client.from("monthly_rewards")
                .select()
                .eq("user_id", value: id)
                .eq("granted", value: false)
                .execute().value
            guard !pending.isEmpty else { return [] }
            // Mark granted so the lots aren't re-applied on the next launch/device.
            try await client.from("monthly_rewards")
                .update(["granted": true])
                .eq("user_id", value: id)
                .eq("granted", value: false)
                .execute()
            return pending
        } catch { return [] }
        #else
        return []
        #endif
    }

    // MARK: Ranked 1v1 league (Système A)

    enum RankedEnqueueResult: Sendable {
        case queued
        case matched(matchId: String, role: String)
        /// Carries a human-readable reason so the search screen can show *why* it
        /// failed (HTTP code from the Edge Function, or the auth/config state)
        /// instead of a blanket "Connexion impossible".
        case failed(String)
    }

    /// A live `ranked_matches` row. `questions` carries the server-shuffled questions
    /// (with their resolved `correctIndex`); the score/winner/deltas are authoritative.
    struct RankedMatchRow: Decodable, Sendable {
        let id: String
        let player_a: String
        let player_b: String
        let pseudo_a: String?
        let pseudo_b: String?
        let accent_a: String?
        let accent_b: String?
        let questions: [Question]
        let current_index: Int
        let status: String
        let score_a: Int
        let score_b: Int
        let winner: String?
        let delta_a: Int?
        let delta_b: Int?
    }

    struct RankedAnswerRow: Decodable, Sendable {
        let question_index: Int
        let user_id: String
        let answer_index: Int?
        let correct: Bool
        let elapsed_ms: Int
    }

    struct RankedStatsRow: Decodable, Sendable {
        let rating: Int
        let peak_rating: Int
        let wins: Int
        let losses: Int
    }

    struct RankedLeaderboardEntry: Decodable, Identifiable, Sendable {
        let user_id: String
        let pseudo: String
        let rating: Int
        let wins: Int
        let losses: Int
        let rank: Int
        var id: String { user_id }
    }

    /// Joins the matchmaking queue (or returns the match if one was already created
    /// for us). The client re-calls this every ~2 s while `.queued`.
    func enqueueRanked(pseudo: String, accentHex: String?) async -> RankedEnqueueResult {
        #if canImport(Supabase)
        // Not online: surface *which* state blocked us (config absente, auth ratée,
        // connexion en cours) so the error screen says something actionable.
        guard case .online = status, let client else {
            switch status {
            case .offline:        return .failed("Backend hors ligne (config SUPABASE absente ?)")
            case .connecting:     return .failed("Connexion en cours, réessaie")
            case .failed(let m):  return .failed("Auth échouée : \(m)")
            case .online:         return .failed("Client Supabase indisponible")
            }
        }
        struct Body: Encodable { let pseudo: String; let accentHex: String? }
        struct Resp: Decodable { let status: String; let matchId: String?; let role: String? }
        // Filet de sécurité : un 401 signifie qu'un jeton invalide est parti (session
        // morte que `connect()` n'aurait pas rattrapée). On force alors une session
        // anonyme NEUVE et on retente une fois — le serveur répond 200 à un vrai jeton.
        var lastReason = "Connexion impossible"
        for attempt in 0..<2 {
            do {
                let resp: Resp = try await client.functions.invoke(
                    "ranked-enqueue", options: .init(body: Body(pseudo: pseudo, accentHex: accentHex)))
                if resp.status == "matched", let id = resp.matchId, let role = resp.role {
                    return .matched(matchId: id, role: role)
                }
                return .queued
            } catch {
                lastReason = Self.describe(error)
                print("[Ranked] enqueue-ranked a échoué (essai \(attempt + 1)) : \(lastReason)")
                if attempt == 0, Self.isUnauthorized(error) {
                    // On RAFRAÎCHIT la session existante (et surtout PAS de
                    // signInAnonymously : créer un compte anonyme neuf juste pour
                    // purger un jeton périmé forkait l'identité du joueur, cf.
                    // validSession). On resynchronise userID (sert au mapping de
                    // rôle me/adversaire côté RankedController).
                    if let session = try? await client.auth.session {
                        userID = session.user.id.uuidString.lowercased()
                    }
                    continue
                }
                return .failed(lastReason)
            }
        }
        return .failed(lastReason)
        #else
        return .failed("SDK Supabase absent")
        #endif
    }

    #if canImport(Supabase)
    /// Turns an invoke error into a short diagnostic. For `FunctionsError.httpError`
    /// it keeps the HTTP code and the (truncated) response body, which is exactly
    /// what tells 401 (auth) apart from 500 (serveur) and from a network drop.
    static func describe(_ error: Error) -> String {
        if let fe = error as? FunctionsError {
            switch fe {
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? ""
                return "HTTP \(code)\(body.isEmpty ? "" : " : \(body.prefix(120))")"
            case .relayError:
                return "relayError (fonction injoignable ?)"
            @unknown default:
                return fe.localizedDescription
            }
        }
        // Réseau (URLError) ou autre : garde le message système.
        return error.localizedDescription
    }

    /// Vrai si l'invoke a échoué sur un 401 (jeton refusé par l'Edge Function).
    static func isUnauthorized(_ error: Error) -> Bool {
        if case FunctionsError.httpError(let code, _) = error { return code == 401 }
        return false
    }
    #endif

    func cancelRanked() async {
        #if canImport(Supabase)
        guard case .online = status, let client else { return }
        struct Body: Encodable { let leave: Bool }
        do { try await client.functions.invoke("ranked-enqueue", options: .init(body: Body(leave: true))) }
        catch { }
        #endif
    }

    func submitRankedAnswer(matchId: String, questionIndex: Int, answerIndex: Int?, elapsedMs: Int) async {
        #if canImport(Supabase)
        guard case .online = status, let client else { return }
        struct Body: Encodable { let matchId: String; let questionIndex: Int; let answerIndex: Int?; let elapsedMs: Int }
        do {
            try await client.functions.invoke("ranked-answer", options: .init(
                body: Body(matchId: matchId, questionIndex: questionIndex, answerIndex: answerIndex, elapsedMs: elapsedMs)))
        } catch { }
        #endif
    }

    func forfeitRanked(matchId: String) async {
        #if canImport(Supabase)
        guard case .online = status, let client else { return }
        struct Body: Encodable { let matchId: String; let forfeit: Bool }
        do { try await client.functions.invoke("ranked-answer", options: .init(body: Body(matchId: matchId, forfeit: true))) }
        catch { }
        #endif
    }

    func fetchRankedMatch(id: String) async -> RankedMatchRow? {
        #if canImport(Supabase)
        guard case .online = status, let client else { return nil }
        do { return try await client.from("ranked_matches").select().eq("id", value: id).single().execute().value }
        catch { return nil }
        #else
        return nil
        #endif
    }

    func fetchRankedAnswers(matchId: String) async -> [RankedAnswerRow] {
        #if canImport(Supabase)
        guard case .online = status, let client else { return [] }
        do { return try await client.from("ranked_answers").select().eq("match_id", value: matchId).execute().value }
        catch { return [] }
        #else
        return []
        #endif
    }

    func myRankedStats() async -> RankedStatsRow? {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return nil }
        do {
            let rows: [RankedStatsRow] = try await client.from("ranked_stats")
                .select().eq("user_id", value: id).limit(1).execute().value
            return rows.first
        } catch { return nil }
        #else
        return nil
        #endif
    }

    func rankedLeaderboard(limit: Int = 100) async -> [RankedLeaderboardEntry] {
        #if canImport(Supabase)
        guard case .online = status, let client else { return [] }
        do {
            return try await client.from("ranked_leaderboard")
                .select().order("rank", ascending: true).limit(limit).execute().value
        } catch { return [] }
        #else
        return []
        #endif
    }

    /// Ma place au classement général et le nombre total de joueurs classés.
    /// `nil` tant que je n'ai pas de ligne `ranked_stats` (aucun match joué).
    /// Nécessaire car le joueur peut être hors du top 100 : sa place ne se déduit
    /// pas de la liste rapportée par `rankedLeaderboard`.
    struct MyRankedRank: Sendable {
        let rank: Int
        let total: Int
    }

    func myRankedRank() async -> MyRankedRank? {
        #if canImport(Supabase)
        guard case .online = status, let client, let id = userID else { return nil }
        struct RankRow: Decodable { let rank: Int }
        do {
            let mine: [RankRow] = try await client.from("ranked_leaderboard")
                .select("rank").eq("user_id", value: id).limit(1).execute().value
            guard let rank = mine.first?.rank else { return nil }

            // head: true => on ne rapatrie aucune ligne, juste le total.
            let total = try await client.from("ranked_leaderboard")
                .select("user_id", head: true, count: .exact).execute().count
            return MyRankedRank(rank: rank, total: total ?? 0)
        } catch { return nil }
        #else
        return nil
        #endif
    }
}

#if canImport(Supabase)
/// Maps `PlayerProfile` to the online-relevant columns of `profiles`. Values are
/// clamped to respect the table's CHECK constraints (pseudo 2..24 chars,
/// total_correct <= total_answered, non-negative counters).
private struct ProfileRow: Encodable {
    let id: String
    let pseudo: String
    let total_xp: Int
    let coins: Int
    let games_played: Int
    let total_correct: Int
    let total_answered: Int
    let best_streak_ever: Int
    let daily_streak: Int
    let accent: String

    init(id: String, profile: PlayerProfile, accent: String) {
        self.id = id
        self.pseudo = Self.clampPseudo(profile.pseudo)
        self.total_xp = max(0, profile.totalXP)
        self.coins = max(0, profile.coins)
        self.games_played = max(0, profile.gamesPlayed)
        self.total_answered = max(0, profile.totalAnswered)
        self.total_correct = min(max(0, profile.totalCorrect), max(0, profile.totalAnswered))
        self.best_streak_ever = max(0, profile.bestStreakEver)
        self.daily_streak = max(0, profile.dailyStreak)
        self.accent = accent
    }

    private static func clampPseudo(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return "RetroKid" }
        return String(t.prefix(24))
    }
}

/// Les mêmes colonnes que `ProfileRow`, sans `pseudo` : sert de repli quand
/// l'upsert complet bute sur l'unicité du pseudo, pour que les stats du joueur
/// remontent quand même (cf. `syncProfile`).
private struct ProfileStatsRow: Encodable {
    let total_xp: Int
    let coins: Int
    let games_played: Int
    let total_correct: Int
    let total_answered: Int
    let best_streak_ever: Int
    let daily_streak: Int
    let accent: String

    init(profile: PlayerProfile, accent: String) {
        self.total_xp = max(0, profile.totalXP)
        self.coins = max(0, profile.coins)
        self.games_played = max(0, profile.gamesPlayed)
        self.total_answered = max(0, profile.totalAnswered)
        self.total_correct = min(max(0, profile.totalCorrect), max(0, profile.totalAnswered))
        self.best_streak_ever = max(0, profile.bestStreakEver)
        self.daily_streak = max(0, profile.dailyStreak)
        self.accent = accent
    }
}
#endif
