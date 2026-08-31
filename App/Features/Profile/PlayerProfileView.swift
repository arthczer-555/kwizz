import SwiftUI

/// Read-only profile of ANOTHER player, opened by tapping their name in the
/// monthly leaderboard. Fetches the public profile (`get_public_profile` RPC)
/// and shows their scores plus their character (avatar rebuilt from the equipped
/// cosmetics + their accent + the level derived from XP).
///
/// The perso is only fully accurate once that player has run the version that
/// syncs equipment/accent; older data falls back to a level-only avatar with the
/// default accent - a clean degrade, not a bug.
struct PlayerProfileView: View {
    let userID: String

    @Environment(\.accent) private var accent
    @State private var profile: SupabaseService.PublicProfile?
    @State private var loading = true

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("PROFIL").font(KFont.mono(13, bold: true))
                    Spacer()
                }
                content
            }
            .screenPadding()
        }
        .screenBackground()
        .task(id: userID) { await load() }
    }

    @ViewBuilder private var content: some View {
        if loading && profile == nil {
            ProgressView()
                .tint(accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else if let p = profile {
            loaded(p)
        } else {
            panel(icon: "person.crop.circle.badge.exclamationmark",
                  title: "Profil indisponible",
                  message: "Impossible de charger ce profil. Vérifie ta connexion et réessaie.")
        }
    }

    @ViewBuilder private func loaded(_ p: SupabaseService.PublicProfile) -> some View {
        let playerAccent = Theme.Accent(rawValue: p.accent ?? "")?.color ?? Theme.Accent.vert.color
        let progress = LevelTable.progress(totalXP: p.total_xp)

        VStack(spacing: 8) {
            AvatarLayeredView(look: avatarLook(p, level: progress.level), scale: 1.0)
                .environment(\.accent, playerAccent)
            Text(p.pseudo).font(KFont.mono(16, bold: true))
            Text("Niveau \(progress.level)")
                .font(KFont.body(13))
                .foregroundStyle(Theme.muted)
            XPBar(fraction: progress.fraction)
                .environment(\.accent, playerAccent)
        }

        LazyVGrid(columns: columns, spacing: 9) {
            stat("Parties", "\(p.games_played)")
            stat("% Bonnes", "\(percent(p))")
            stat("Meilleur", "\(p.best_score)")
            stat("Série max", "\(p.best_streak_ever)")
        }
    }

    /// Rebuilds the avatar from the equipped cosmetics returned by the server.
    /// Unknown item ids / slots are skipped (catalog drift stays harmless).
    private func avatarLook(_ p: SupabaseService.PublicProfile, level: Int) -> AvatarLook {
        var items: [AvatarSlot: AvatarItem] = [:]
        for e in p.equipped {
            guard let slot = AvatarSlot(rawValue: e.slot), let item = AvatarItem.item(id: e.item_id) else { continue }
            items[slot] = item
        }
        return AvatarLook(level: level, items: items)
    }

    private func percent(_ p: SupabaseService.PublicProfile) -> Int {
        guard p.total_answered > 0 else { return 0 }
        return Int(Double(p.total_correct) / Double(p.total_answered) * 100)
    }

    @ViewBuilder private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(KFont.mono(17)).foregroundStyle(accent)
            SectionLabel(label)
        }
        .frame(maxWidth: .infinity)
        .kPanel()
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
        profile = await SupabaseService.shared.publicProfile(userID: userID)
        loading = false
    }
}
