import SwiftUI

struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TopBar(coins: store.profile.coins, level: store.profile.level)

                // Hero: avatar + identity
                VStack(spacing: 10) {
                    NavigationLink(value: Route.avatar) {
                        AvatarLayeredView(look: store.avatarLook, scale: 1.3)
                    }
                    .buttonStyle(.plain)

                    Text(store.profile.pseudo)
                        .font(KFont.mono(18, bold: true))
                        .foregroundStyle(Theme.text)
                }
                .padding(.top, 4)

                // XP block
                VStack(spacing: 6) {
                    HStack {
                        SectionLabel("LVL \(store.profile.level)")
                        Spacer()
                        SectionLabel(
                            store.profile.levelProgress.isMax
                                ? "MAX"
                                : "\(store.profile.levelProgress.xpIntoLevel) / \(store.profile.levelProgress.xpForNextLevel) XP"
                        )
                    }
                    XPBar(fraction: store.profile.levelProgress.fraction)
                }
                .padding(.top, 8)

                // Play
                PixelButton(title: "Jouer") { router.goToPlay() }

                // Daily challenge panel
                NavigationLink(value: Route.defiIntro) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            SectionLabel("Défi du jour")
                            Text(store.dailyAvailable ? "1 essai restant" : "déjà joué")
                                .font(KFont.body(12))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        CoinLabel(amount: 50)
                    }
                    .kPanel()
                }
                .buttonStyle(.plain)

                // Récompenses : coffres + roue
                HStack(spacing: 10) {
                    NavigationLink(value: Route.chestOpen) {
                        rewardTile(icon: "shippingbox.fill", title: "Coffres", value: "\(store.profile.ownedChests)")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: Route.dailyWheel) {
                        rewardTile(icon: "circle.hexagongrid.fill", title: "Roue",
                                   value: store.wheelAvailable ? "1 tour" : "demain")
                    }
                    .buttonStyle(.plain)
                }

                // Série en cours
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(accent)
                    Text("Série J\(store.profile.dailyStreak)")
                        .font(KFont.mono(11)).foregroundStyle(Theme.text)
                    Spacer()
                    Text(store.profile.dailyStreak > 0
                            ? "prochain palier J\(StreakMilestone.next(after: store.profile.dailyStreak))"
                            : "joue chaque jour")
                        .font(KFont.mono(10)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 2)

                // Premier cosmétique
                if store.showFirstCosmeticNudge {
                    FirstCosmeticNudge {
                        store.dismissFirstCosmeticNudge()
                        router.tab = .shop
                    }
                }
            }
            .screenPadding()
            .padding(.vertical, 16)
        }
        .screenBackground()
    }

    @ViewBuilder private func rewardTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(accent)
                SectionLabel(title)
                Spacer()
            }
            Text(value).font(KFont.mono(15, bold: true)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(12)
    }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack {
        HomeView()
    }
    .environment(store)
    .environment(Router(store: store))
    .environment(\.accent, store.accentColor)
}
