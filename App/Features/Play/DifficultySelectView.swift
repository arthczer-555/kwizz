import SwiftUI

/// Pushed screen for picking a game difficulty before starting.
/// Harder difficulties draw harder questions and pay larger rewards.
struct DifficultySelectView: View {
    let mode: GameMode
    let category: Category?
    let subcategory: Subcategory?

    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    @State private var difficulty: Difficulty = .normal

    var body: some View {
        VStack(spacing: 14) {
            BackHeader(title: "Difficulté")

            Text("Plus dur = plus payant.")
                .font(KFont.body(13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Difficulty.allCases) { d in
                Button {
                    difficulty = d
                } label: {
                    HStack {
                        Text(d.title)
                            .font(KFont.mono(14))
                            .foregroundStyle(d == difficulty ? accent : Theme.text)
                        Spacer()
                        SectionLabel("gain \(d.gainLabel)")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface)
                    .overlay(Rectangle().stroke(d == difficulty ? accent : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PixelButton(title: "Go") {
                router.startGame(mode: mode, category: category, subcategory: subcategory, difficulty: difficulty)
            }
            .screenPadding()
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Theme.bg)
        }
    }
}

#Preview {
    NavigationStack {
        DifficultySelectView(mode: .classique, category: nil, subcategory: nil)
    }
    .environment(Router(store: PlayerStore()))
    .environment(\.accent, Theme.Accent.vert.color)
}
