import SwiftUI

/// Monthly Daily-Challenge leaderboard (Système B). Reads the public view
/// `monthly_challenge_leaderboard` (top + the player's own row) and shows the
/// current month's standings. Offline or empty states fall back to a panel.
struct LeaderboardView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    @State private var entries: [SupabaseService.MonthlyEntry] = []
    @State private var mine: SupabaseService.MonthlyEntry?
    @State private var loading = true
    /// Le dernier chargement a échoué (réseau/jeton), par opposition à un mois vide.
    @State private var loadFailed = false
    @State private var claimedCoins = 0
    @State private var claimedChests = 0
    @State private var showClaim = false

    /// Current month in AAAAMM (today is AAAAMMJJ).
    private var month: Int { store.today() / 100 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TopBar(coins: store.profile.coins, level: store.profile.level)

                HStack {
                    Text("CLASSEMENT")
                        .font(KFont.mono(13, bold: true))
                    Spacer()
                    Text(monthLabel(month))
                        .font(KFont.mono(11))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 8)

                Text("Défi du jour, classé par bonnes réponses (25 meilleurs jours du mois).")
                    .font(KFont.body(12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                NavButton(
                    title: store.dailyAvailable ? "Jouer le défi du jour" : "Défi du jour terminé",
                    style: store.dailyAvailable ? .filled : .ghost,
                    route: .defiIntro
                )
                .padding(.bottom, 16)

                content
            }
            .screenPadding()
            .padding(.top, 12)
        }
        .screenBackground()
        .task(id: month) { await load() }
        .refreshable { await load() }
        .alert("Récompenses du mois", isPresented: $showClaim) {
            Button("Génial !") { }
        } message: {
            Text("Bravo pour ton classement ! Tu reçois +\(claimedCoins) pièces et +\(claimedChests) coffres.")
        }
    }

    @ViewBuilder private var content: some View {
        if loading && entries.isEmpty {
            ProgressView()
                .tint(accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else if SupabaseService.shared.status != .online && entries.isEmpty {
            panel(icon: "wifi.slash", title: "Hors ligne",
                  message: "Connecte-toi pour voir le classement du mois.")
        } else if loadFailed && entries.isEmpty {
            // Échec de chargement (et rien en cache) : on N'affiche PAS "Personne
            // encore", qui ferait croire à tort que le mois est vide.
            panel(icon: "arrow.clockwise", title: "Connexion instable",
                  message: "Le classement n'a pas pu se charger. Tire vers le bas pour réessayer.")
        } else if entries.isEmpty {
            panel(icon: "trophy", title: "Personne encore",
                  message: "Joue le Défi du jour pour ouvrir le classement de ce mois.")
        } else {
            VStack(spacing: 6) {
                ForEach(entries) { row($0) }
            }
            if let mine, !entries.contains(where: { $0.user_id == mine.user_id }) {
                Text("TON RANG")
                    .font(KFont.mono(10))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                row(mine)
            }
        }
    }

    private func row(_ e: SupabaseService.MonthlyEntry) -> some View {
        let isMe = e.user_id == SupabaseService.shared.userID
        return NavigationLink(value: Route.playerProfile(userID: e.user_id)) {
            HStack(spacing: 12) {
                Text("\(e.rank)")
                    .font(KFont.mono(13, bold: true))
                    .foregroundStyle(e.rank <= 3 ? accent : Theme.muted)
                    .frame(minWidth: 32, alignment: .leading)
                Text(e.pseudo)
                    .font(KFont.mono(13, bold: isMe))
                    .lineLimit(1)
                Spacer()
                Text("\(e.total)")
                    .font(KFont.mono(13, bold: true))
                    .foregroundStyle(isMe ? accent : Theme.text)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isMe ? accent.opacity(0.12) : Theme.surface)
            .overlay(Rectangle().stroke(isMe ? accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func panel(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(accent)
            Text(title).font(KFont.mono(15, bold: true))
            Text(message)
                .font(KFont.body(13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .kPanel(24)
        .padding(.top, 40)
    }

    private func load() async {
        loading = true
        await SupabaseService.shared.start()
        // Deux tentatives : si la première échoue (souvent un jeton anonyme expiré
        // que le SDK rafraîchit juste après), la seconde passe. En cas d'échec, on
        // GARDE `entries`/`mine` déjà affichés au lieu de les écraser avec du vide.
        for attempt in 0..<2 {
            do {
                let fetched = try await SupabaseService.shared.monthlyLeaderboard(month: month)
                let mineFetched = try await SupabaseService.shared.myMonthly(month: month)
                entries = fetched
                mine = mineFetched
                loadFailed = false
                break
            } catch {
                loadFailed = true
                if attempt == 0 { try? await Task.sleep(for: .milliseconds(400)) }
            }
        }
        loading = false
        await claimRewards()
    }

    /// Applies any end-of-month rewards owed to the player, once.
    private func claimRewards() async {
        let rewards = await SupabaseService.shared.claimMonthlyRewards()
        guard !rewards.isEmpty else { return }
        let coins = rewards.reduce(0) { $0 + $1.coins }
        let chests = rewards.reduce(0) { $0 + $1.chests }
        store.addCoins(coins)
        for _ in 0..<chests { store.grantChest() }
        guard coins > 0 || chests > 0 else { return }
        claimedCoins = coins
        claimedChests = chests
        showClaim = true
    }

    private func monthLabel(_ yyyymm: Int) -> String {
        let names = ["", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
                     "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
        let m = yyyymm % 100, y = yyyymm / 100
        guard names.indices.contains(m) else { return "\(yyyymm)" }
        return "\(names[m]) \(y)"
    }
}

#Preview {
    LeaderboardView()
        .environment(PlayerStore())
        .environment(\.accent, Theme.Accent.vert.color)
}
