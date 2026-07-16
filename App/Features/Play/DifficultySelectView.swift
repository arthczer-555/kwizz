import SwiftUI

/// Pushed screen for picking a game difficulty before starting.
/// Harder difficulties draw harder questions and pay larger rewards.
struct DifficultySelectView: View {
    let mode: GameMode
    let category: Category?
    let subcategory: Subcategory?

    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    /// nil = « Toutes », proposé en entraînement seulement : les questions sont
    /// tirées dans toutes les difficultés et chacune paie selon la sienne.
    @State private var difficulty: Difficulty? = .normal

    /// Les trois difficultés, plus « Toutes » (nil) en entraînement.
    private var options: [Difficulty?] {
        Difficulty.allCases.map { $0 } + (mode.isTraining ? [nil] : [])
    }

    private func title(_ d: Difficulty?) -> String { d?.title ?? "Toutes" }
    private func gainLabel(_ d: Difficulty?) -> String { d?.gainLabel ?? "x1 à x2.5" }

    var body: some View {
        VStack(spacing: 14) {
            BackHeader(title: "Difficulté")

            Text("Plus dur = plus payant.")
                .font(KFont.body(13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(options, id: \.self) { d in
                Button {
                    difficulty = d
                } label: {
                    HStack {
                        Text(title(d))
                            .font(KFont.mono(14))
                            .foregroundStyle(d == difficulty ? accent : Theme.text)
                        Spacer()
                        SectionLabel("gain \(gainLabel(d))")
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
