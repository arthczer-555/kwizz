import SwiftUI

struct DefiIntroView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 16) {
            BackHeader(title: "Défi du jour")

            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 30))
                .foregroundStyle(accent)

            Text("Défi du jour")
                .font(KFont.mono(16))

            Text("Une grille unique, la même pour tout le monde aujourd'hui. Une seule tentative.")
                .font(KFont.body(14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                SectionLabel("Récompense")
                HStack(spacing: 8) {
                    CoinLabel(amount: 150)
                    Text("sans faute")
                        .font(KFont.body(12))
                        .foregroundStyle(Theme.muted)
                }
                Text("1 erreur : 50 · 2 : 30 · 3 : 20 · 4 : 10")
                    .font(KFont.body(11))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .kPanel()

            Spacer()
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Group {
                if store.dailyAvailable {
                    PixelButton(title: "Commencer") {
                        router.startGame(mode: .defi, category: nil, subcategory: nil, difficulty: .normal)
                    }
                } else {
                    Text("Déjà joué aujourd'hui, reviens demain.")
                        .font(KFont.body(13))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .screenPadding()
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Theme.bg)
        }
    }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack {
        DefiIntroView()
    }
    .environment(store)
    .environment(Router(store: store))
    .environment(\.accent, Theme.Accent.vert.color)
}
