import SwiftUI

/// The "Rang" tab: a segmented switch between the ranked 1v1 ladder and the
/// monthly daily-challenge leaderboard.
struct RankedHubView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Picker("", selection: $router.rankSegment) {
                Text("Ligue 1v1").tag(0)
                Text("Mensuel").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if router.rankSegment == 0 { RankedLadderView() } else { LeaderboardView() }
        }
        .screenBackground()
    }
}

/// Ranked 1v1 home: the player's tier card and a "find an opponent" button, plus
/// the top of the global ladder.
struct RankedLadderView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    @State private var stats: SupabaseService.RankedStatsRow?
    @State private var board: [SupabaseService.RankedLeaderboardEntry] = []
    @State private var loading = true

    private var rating: Int { stats?.rating ?? Elo.start }
    private var tier: RankTier { RankTier.tier(forRating: rating) }

    private var roomBinding: Binding<Bool> {
        Binding(get: { router.activeRanked != nil }, set: { if !$0 { router.quitRanked() } })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TopBar(coins: store.profile.coins, level: store.profile.level)
                tierCard
                PixelButton(title: "Trouver un adversaire") { router.startRanked() }

                SectionLabel("Règles")
                    .frame(maxWidth: .infinity, alignment: .leading)
                rulesCard

                SectionLabel("Tous les rangs")
                    .frame(maxWidth: .infinity, alignment: .leading)
                RankFrieze(current: tier)

                if !board.isEmpty {
                    HStack {
                        SectionLabel("Top joueurs")
                        Spacer()
                        NavigationLink(value: Route.rankedLeaderboard) {
                            Text("classement général →")
                                .font(KFont.mono(11))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(spacing: 6) {
                        ForEach(board) { RankedRow(entry: $0, isMe: $0.user_id == SupabaseService.shared.userID) }
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationDestination(isPresented: roomBinding) { RankedRoomView() }
        .task { await load() }
        .refreshable { await load() }
    }

    /// Les règles du 1v1 classé, en quatre lignes : c'est le seul endroit où le
    /// joueur apprend que les deux marquent et que l'égalité se départage au temps.
    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            rule("7 questions, 15 s chacune")
            rule("1 point par bonne réponse : vous pouvez marquer tous les deux")
            rule("Égalité : le plus rapide au temps cumulé l'emporte")
            rule("Aucune pièce en jeu, seul le classement bouge")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(14)
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("›").font(KFont.mono(11, bold: true)).foregroundStyle(accent)
            Text(text).font(KFont.mono(11)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tierCard: some View {
        VStack(spacing: 10) {
            Text(tier.title.uppercased())
                .font(KFont.mono(15, bold: true)).tracking(2)
                .foregroundStyle(Color(hex: tier.colorHex))
            ScoreText(value: rating, size: 44)
            XPBar(fraction: tier.progress(rating: rating))
            HStack {
                Text("\(stats?.wins ?? 0) V").font(KFont.mono(11)).foregroundStyle(accent)
                Spacer()
                Text("\(stats?.losses ?? 0) D").font(KFont.mono(11)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .kPanel(18)
    }

    private func load() async {
        loading = true
        await SupabaseService.shared.start()
        stats = await SupabaseService.shared.myRankedStats()
        // Simple aperçu : le classement complet (top 100 + ma place) est derrière
        // le lien "classement général".
        board = await SupabaseService.shared.rankedLeaderboard(limit: 5)
        loading = false
    }
}

/// The full tier ladder (Grand Master at top down to Bronze), with the player's
/// current tier highlighted and each tier's rating range.
struct RankFrieze: View {
    let current: RankTier
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(RankTier.allCases.reversed()), id: \.self) { tier in
                let isCurrent = tier == current
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color(hex: tier.colorHex))
                        .frame(width: 6, height: 20)
                    Text(tier.title.uppercased())
                        .font(KFont.mono(12, bold: isCurrent))
                        .foregroundStyle(isCurrent ? accent : Theme.text)
                    if isCurrent {
                        Text("◀ TOI").font(KFont.mono(9, bold: true)).foregroundStyle(accent)
                    }
                    Spacer(minLength: 8)
                    Text(range(tier)).font(KFont.mono(10)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(isCurrent ? accent.opacity(0.12) : Color.clear)
                if tier != .bronze { Divider().overlay(Theme.border) }
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func range(_ tier: RankTier) -> String {
        if let next = RankTier(rawValue: tier.rawValue + 1) {
            return "\(tier.minRating)-\(next.minRating - 1)"
        }
        return "\(tier.minRating)+"
    }
}
