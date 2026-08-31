import SwiftUI

struct ItemDetailView: View {
    let itemID: String

    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    var body: some View {
        let item = AvatarItem.item(id: itemID)

        VStack(spacing: 16) {
            BackHeader(title: "Objet")

            if let item {
                Spacer()

                AvatarItemPreview(item: item, level: store.profile.level, scale: 0.7)
                    .frame(height: 118)

                Text(item.name)
                    .font(KFont.mono(18))

                KTag(title: item.rarity.title, selected: true)

                Text("Cosmétique uniquement. Zéro pay-to-win.")
                    .font(KFont.body(13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            } else {
                Spacer()
                Text("Objet introuvable")
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            if let item {
                footer(item)
                    .frame(maxWidth: .infinity)
                    .screenPadding()
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .background(Theme.bg)
            }
        }
    }

    @ViewBuilder
    private func footer(_ item: AvatarItem) -> some View {
        // Reading store.profile makes the view refresh after buy.
        let _ = store.profile

        if !store.isUnlocked(item) || (item.isLevelLocked && !store.isOwned(item)) {
            Text("Débloqué au niveau \(item.unlockLevel ?? 0)")
                .font(KFont.body(13))
                .foregroundStyle(Theme.muted)
        } else if store.isEquipped(item) {
            VStack(spacing: 8) {
                EquippedLabel()
                Button { store.unequip(slot: item.slot) } label: {
                    Text("Retirer")
                        .font(KFont.mono(12)).tracking(1)
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }
        } else if store.isOwned(item) {
            PixelButton(title: "Équiper") { store.equip(item) }
        } else {
            // Sans le `.disabled`, un joueur trop pauvre tape « Acheter » en boucle
            // sans que rien ne se passe et sans savoir pourquoi.
            let missing = item.price - store.profile.coins
            VStack(spacing: 8) {
                HStack {
                    CoinLabel(amount: item.price)
                    Spacer()
                    PixelButton(title: "Acheter", fullWidth: false) { store.buy(item) }
                        .disabled(missing > 0)
                }
                if missing > 0 {
                    Text("Il te manque \(missing) pièces")
                        .font(KFont.body(12))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

/// Non-interactive "equipped" state shown in place of the Équiper button once the
/// item is the one worn in its slot. Matches PixelButton's footprint so the layout
/// doesn't shift when equipping.
private struct EquippedLabel: View {
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark")
            Text("ÉQUIPÉ")
        }
        .font(KFont.mono(13, bold: true))
        .tracking(2)
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .overlay(Rectangle().stroke(accent, lineWidth: 1))
    }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack {
        ItemDetailView(itemID: AvatarItem.catalog.first?.id ?? "")
    }
    .environment(store)
    .environment(\.accent, store.accentColor)
}
