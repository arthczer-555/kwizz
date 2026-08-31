import SwiftUI

struct ShopView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    @State private var slot: AvatarSlot = .tete

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TopBar(coins: store.profile.coins, level: store.profile.level)

                HStack {
                    Text("BOUTIQUE").font(KFont.mono(13, bold: true))
                    Spacer()
                }

                // Catégories sur des lignes fixes (pas de swipe) : tout est visible.
                FlowLayout(spacing: 7, lineSpacing: 7) {
                    ForEach(AvatarSlot.allCases) { s in
                        Button { slot = s } label: {
                            KTag(title: s.title, selected: s == slot)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AvatarItem.items(slot: slot)) { item in
                        NavigationLink(value: Route.shopItem(item.id)) {
                            ShopItemCard(
                                item: item,
                                level: store.profile.level,
                                unlocked: store.isUnlocked(item),
                                owned: store.isOwned(item)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .screenPadding()
        }
        .screenBackground()
    }
}

/// A single shop tile. The cosmetic preview sits on a rarity-tinted spotlight so
/// even very dark items read clearly against the near-black UI; the rarity, name
/// and price/status sit below on the panel.
private struct ShopItemCard: View {
    let item: AvatarItem
    let level: Int
    let unlocked: Bool
    let owned: Bool
    @Environment(\.accent) private var accent

    private var rarity: Color { Color(hex: item.rarity.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(colors: [rarity.opacity(0.22), Theme.bg2],
                               center: .center, startRadius: 2, endRadius: 130)
                AvatarItemPreview(item: item, level: level, scale: 0.46)
                    .opacity(unlocked ? 1 : 0.85)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(rarity.opacity(0.5), lineWidth: 1))

            VStack(spacing: 5) {
                Text(item.rarity.title.uppercased())
                    .font(KFont.mono(8)).tracking(1.5)
                    .foregroundStyle(rarity)
                Text(item.name)
                    .font(KFont.body(13))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                statusLabel
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var statusLabel: some View {
        // Un level-locked non possédé est forcément encore verrouillé (le palier
        // franchi le crédite) : jamais de prix « 0 pièce » affiché ici.
        if !unlocked || (item.isLevelLocked && !owned) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text("NIVEAU \(item.unlockLevel ?? 0)")
            }
            .font(KFont.mono(10))
            .foregroundStyle(Theme.muted)
        } else if owned {
            Text("POSSÉDÉ")
                .font(KFont.mono(10)).tracking(1)
                .foregroundStyle(accent)
        } else {
            CoinLabel(amount: item.price)
        }
    }
}

#Preview {
    NavigationStack {
        ShopView()
    }
    .environment(PlayerStore())
    .environment(\.accent, Theme.Accent.vert.color)
}
