import SwiftUI

/// Les coffres mystère: gagnés en jouant (selon le score) et aux paliers de série.
/// Ouvrir un coffre donne le plus souvent des pièces, parfois un objet cosmétique.
struct ChestOpenView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent
    @State private var last: ChestResult?

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Coffres")
            ScrollView {
                VStack(spacing: 16) {
                    counter
                    if let last { reveal(last) }
                    openButton
                    Text("Un coffre contient surtout des pièces, parfois un objet.")
                        .font(KFont.body(11)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .screenPadding()
                .padding(.vertical, 16)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }

    private var counter: some View {
        VStack(spacing: 6) {
            SectionLabel("Coffres disponibles")
            ScoreText(value: store.profile.ownedChests, size: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .kPanel()
    }

    @ViewBuilder private func reveal(_ result: ChestResult) -> some View {
        VStack(spacing: 10) {
            SectionLabel("Dernier coffre")
            if let id = result.itemID, let item = AvatarItem.item(id: id) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: item.rarity.colorHex))
                Text(item.name).font(KFont.mono(15, bold: true)).foregroundStyle(Theme.text)
                Text(item.rarity.title.uppercased())
                    .font(KFont.mono(10)).tracking(1)
                    .foregroundStyle(Color(hex: item.rarity.colorHex))
            } else {
                ScoreText(value: result.coins, size: 40)
                CoinLabel(amount: result.coins)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .kPanel()
    }

    @ViewBuilder private var openButton: some View {
        if store.profile.ownedChests > 0 {
            PixelButton(title: "Ouvrir") {
                if let result = store.openChest() {
                    withAnimation(.easeOut(duration: 0.2)) { last = result }
                    Haptics.notify(.success)
                }
            }
        } else {
            Text("Aucun coffre. Joue et fais un bon score pour en gagner.")
                .font(KFont.body(13)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack { ChestOpenView() }
        .environment(store)
        .environment(Router(store: store))
        .environment(\.accent, store.accentColor)
}
