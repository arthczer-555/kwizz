import SwiftUI

/// Console de triche / debug, accessible depuis Réglages quand le mode admin
/// est activé. Permet de sauter à n'importe quel niveau, régler les pièces,
/// débloquer tous les items, et réinitialiser le profil.
struct AdminView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    @State private var showResetConfirm = false

    private let levelColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var ownedCount: Int { store.profile.ownedItemIDs.count }
    private var totalItems: Int { AvatarItem.catalog.count }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Admin")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("En coupant le mode admin (dans Réglages), ta progression d'avant l'activation est restaurée automatiquement.")
                        .font(KFont.body(11))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    summary

                    section("Niveau") {
                        Text("Niveau actuel : \(store.profile.level) · \(store.profile.title)")
                            .font(KFont.body(12))
                            .foregroundStyle(Theme.muted)
                        LazyVGrid(columns: levelColumns, spacing: 8) {
                            ForEach(1...LevelTable.maxLevel, id: \.self) { lvl in
                                levelCell(lvl)
                            }
                        }
                    }

                    section("Pièces") {
                        HStack {
                            Text("Solde").font(KFont.body(12)).foregroundStyle(Theme.muted)
                            Spacer()
                            CoinLabel(amount: store.profile.coins)
                        }
                        HStack(spacing: 8) {
                            chip("+100") { store.addCoins(100) }
                            chip("+1K") { store.addCoins(1_000) }
                            chip("+10K") { store.addCoins(10_000) }
                            chip("0") { store.setCoins(0) }
                        }
                    }

                    section("Coffres & roue") {
                        HStack {
                            Text("Coffres").font(KFont.body(12)).foregroundStyle(Theme.muted)
                            Spacer()
                            Text("\(store.profile.ownedChests)")
                                .font(KFont.mono(13, bold: true)).foregroundStyle(accent)
                        }
                        HStack(spacing: 8) {
                            chip("+1 coffre") { store.grantChest() }
                            chip("Reset roue") { store.resetWheel() }
                        }
                    }

                    section("Items") {
                        HStack {
                            Text("Possédés").font(KFont.body(12)).foregroundStyle(Theme.muted)
                            Spacer()
                            Text("\(ownedCount) / \(totalItems)")
                                .font(KFont.mono(13, bold: true))
                                .foregroundStyle(accent)
                        }
                        PixelButton(title: "Tout débloquer") { store.unlockAllItems() }
                        PixelButton(title: "Tout retirer", style: .ghost) { store.lockAllItems() }
                    }

                    section("Zone de danger") {
                        PixelButton(title: "Réinitialiser le profil", style: .ghost) {
                            showResetConfirm = true
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 18)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
        .alert("Réinitialiser le profil ?", isPresented: $showResetConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) { store.resetProfile() }
        } message: {
            Text("Niveau, pièces, items et records seront remis à zéro. Le pseudo est conservé.")
        }
    }

    // MARK: Pieces

    private var summary: some View {
        HStack(spacing: 9) {
            summaryStat("Niveau", "\(store.profile.level)")
            summaryStat("Pièces", "\(store.profile.coins)")
            summaryStat("Items", "\(ownedCount)/\(totalItems)")
        }
    }

    @ViewBuilder
    private func summaryStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(KFont.mono(16, bold: true)).foregroundStyle(accent)
            SectionLabel(label)
        }
        .frame(maxWidth: .infinity)
        .kPanel(12)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel()
    }

    @ViewBuilder
    private func levelCell(_ lvl: Int) -> some View {
        let isCurrent = store.profile.level == lvl
        Button {
            store.setLevel(lvl)
        } label: {
            Text("\(lvl)")
                .font(KFont.mono(13, bold: true))
                .foregroundStyle(isCurrent ? Theme.accentInk : Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isCurrent ? accent : Color.clear)
                .overlay(Rectangle().stroke(isCurrent ? accent : Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KFont.mono(12, bold: true))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AdminView()
            .environment(PlayerStore())
            .environment(\.accent, Theme.Accent.vert.color)
    }
}
