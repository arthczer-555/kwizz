import SwiftUI

struct CategorySelectView: View {
    let mode: GameMode
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Catégories")

            ScrollView {
                VStack(spacing: 0) {
                    // "Tous les thèmes" en tête : joue toutes les catégories mélangées.
                    NavigationLink(value: Route.difficulty(mode, Category.melange, nil)) {
                        HStack {
                            Circle()
                                .fill(Color(hex: Category.melange.colorHex))
                                .frame(width: 8, height: 8)
                            Image(systemName: Category.melange.symbol)
                                .frame(width: 22)
                                .foregroundStyle(accent)
                            Text("Tous les thèmes")
                                .font(KFont.body(14))
                                .foregroundStyle(accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Theme.border)

                    ForEach(Category.all) { category in
                        // Tous les modes sautent directement à la difficulté et
                        // jouent toute la catégorie (subcategory = nil).
                        NavigationLink(value: Route.difficulty(mode, category, nil)) {
                            HStack {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 8, height: 8)
                                Image(systemName: category.symbol)
                                    .frame(width: 22)
                                    .foregroundStyle(Theme.muted)
                                Text(category.name)
                                    .font(KFont.body(14))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(Theme.border)
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

#Preview {
    NavigationStack {
        CategorySelectView(mode: .classique)
    }
}
