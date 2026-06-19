import SwiftUI

struct AvatarView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent
    /// nil = "Tout" : tous les objets possédés, toutes catégories confondues.
    @State private var slot: AvatarSlot? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    /// Objets possédés pour le filtre courant. En "Tout", on garde l'ordre du
    /// catalogue (déjà groupé par catégorie) pour un rendu lisible.
    private var ownedItems: [AvatarItem] {
        let items = slot.map { AvatarItem.items(slot: $0) } ?? AvatarItem.catalog
        return items.filter { store.isOwned($0) }
    }

    var body: some View {
        VStack(spacing: 14) {
            BackHeader(title: "Vestiaire")

            ScrollView {
                VStack(spacing: 14) {
                    AvatarLayeredView(look: store.avatarLook, scale: 0.8, showShadow: false)
                        .frame(maxWidth: .infinity)
                        .kPanel()

                    // Catégories sur des lignes fixes (pas de swipe) : tout est visible.
                    // "Tout" liste l'ensemble des objets possédés.
                    FlowLayout(spacing: 7, lineSpacing: 7) {
                        Button { slot = nil } label: {
                            KTag(title: "Tout", selected: slot == nil)
                        }
                        .buttonStyle(.plain)
                        ForEach(AvatarSlot.allCases) { s in
                            Button { slot = s } label: {
                                KTag(title: s.title, selected: s == slot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    let owned = ownedItems
                    if owned.isEmpty {
                        Text("Aucun objet ici. Va en boutique.")
                            .font(KFont.body(13))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(owned) { item in
                                Button {
                                    store.equip(item)
                                } label: {
                                    WardrobeItemCard(
                                        item: item,
                                        level: store.profile.level,
                                        equipped: store.equippedItem(slot: item.slot)?.id == item.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }
}

/// A wardrobe tile: an owned cosmetic on a rarity-tinted spotlight with its name
/// and an equipped marker. Tapping equips it. Mirrors the shop tile so the two
/// screens read the same.
private struct WardrobeItemCard: View {
    let item: AvatarItem
    let level: Int
    let equipped: Bool
    @Environment(\.accent) private var accent

    private var rarity: Color { Color(hex: item.rarity.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(colors: [rarity.opacity(0.22), Theme.bg2],
                               center: .center, startRadius: 2, endRadius: 130)
                AvatarItemPreview(item: item, level: level, scale: 0.46)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(equipped ? accent : rarity.opacity(0.5), lineWidth: 1))

            VStack(spacing: 5) {
                Text(item.rarity.title.uppercased())
                    .font(KFont.mono(8)).tracking(1.5)
                    .foregroundStyle(rarity)
                Text(item.name)
                    .font(KFont.body(13))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(equipped ? "ÉQUIPÉ" : "ÉQUIPER")
                    .font(KFont.mono(10)).tracking(1)
                    .foregroundStyle(equipped ? accent : Theme.muted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(equipped ? accent : Theme.border, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        AvatarView()
    }
    .environment(PlayerStore())
    .environment(\.accent, Theme.Accent.vert.color)
}
