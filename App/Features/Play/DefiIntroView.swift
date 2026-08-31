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

            Text("Une grille unique, la même pour tout le monde aujourd'hui.")
                .font(KFont.body(14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                Text("Une seule tentative. Si tu quittes l'app en cours de route, ton défi est validé en l'état.")
                    .font(KFont.mono(11))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kPanel(12)

            VStack(spacing: 10) {
                SectionLabel("Récompense")
                HStack(spacing: 8) {
                    CoinLabel(amount: Economy.defiReward(errors: 0))
                    Text("sans faute")
                        .font(KFont.body(12))
                        .foregroundStyle(Theme.muted)
                }
                Text("1 erreur : \(Economy.defiReward(errors: 1)) · 2 : \(Economy.defiReward(errors: 2)) · 3 : \(Economy.defiReward(errors: 3)) · 4 : \(Economy.defiReward(errors: 4))")
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
