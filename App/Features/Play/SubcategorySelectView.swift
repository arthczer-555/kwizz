import SwiftUI

struct SubcategorySelectView: View {
    let mode: GameMode
    let category: Category
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: category.name)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Sous-catégorie")
                        .padding(.vertical, 8)

                    ForEach(category.subcategories) { sub in
                        NavigationLink(value: Route.difficulty(mode, category, sub)) {
                            HStack {
                                Text(sub.name)
                                    .font(KFont.body(14))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(Theme.border)
                    }

                    NavigationLink(value: Route.difficulty(mode, category, nil)) {
                        HStack {
                            Text("Tout " + category.name)
                                .font(KFont.body(14))
                                .foregroundStyle(accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
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
        SubcategorySelectView(mode: .classique, category: Category.all[0])
    }
    .environment(\.accent, Theme.Accent.vert.color)
}
