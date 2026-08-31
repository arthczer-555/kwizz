import SwiftUI

/// L'écran de configuration d'une partie, entre « Créer une partie » et le salon :
/// l'hôte y fixe la mise (donc la cagnotte), la longueur de la manche, la règle
/// de score et le thème avant qu'un code
/// de salon existe. Rien n'est diffusé ici, aucun `DuelController` n'est encore
/// créé : les réglages sont locaux jusqu'au bouton d'ouverture, qui les passe au
/// contrôleur. Les invités les découvriront par l'événement `.settings`.
struct DuelSetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent
    @Environment(\.dismiss) private var dismiss

    @State private var settings: DuelSettings = .default
    /// Position de la poignée pendant un glissement, avant de figer la mise.
    @State private var dragPosition: Double?
    @State private var goLobby = false
    /// Les réglages ne sont calés sur le porte-monnaie qu'une fois, à l'ouverture.
    @State private var didSeed = false

    private var coins: Int { store.profile.coins }

    /// La mise affichée : celle du curseur en cours de glissement, sinon la retenue.
    private var shownStake: Int {
        guard let dragPosition else { return settings.stake }
        return DuelWager.stake(atPosition: dragPosition, maxStake: coins)
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Nouvelle partie")
                .screenPadding()
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 16) {
                    StakeField(stake: shownStake,
                               maxStake: coins,
                               position: dragPosition ?? DuelWager.position(ofStake: settings.stake, maxStake: coins)) { position, committed in
                        if committed {
                            dragPosition = nil
                            settings.stake = DuelWager.stake(atPosition: position, maxStake: coins)
                            Haptics.impact(.light)
                        } else {
                            dragPosition = position
                        }
                    }
                    .kPanel()

                    PotSummary(stake: shownStake, playerCount: nil)
                        .kPanel()

                    QuestionCountField(questionCount: settings.questionCount) { count in
                        settings.questionCount = count
                        Haptics.impact(.light)
                    }
                    .kPanel()

                    ScoringField(scoring: settings.scoring) { mode in
                        settings.scoring = mode
                        Haptics.impact(.light)
                    }
                    .kPanel()

                    ThemeField(categoryID: settings.categoryID) { id in
                        settings.categoryID = id
                        Haptics.impact(.light)
                    }
                    .kPanel()

                    Text("Ces réglages valent pour toute la partie : ils sont figés à l'ouverture du salon, et resservent tels quels si tu relances une manche avec les mêmes joueurs.")
                        .font(KFont.mono(10))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .screenPadding()
                .padding(.vertical, 16)
            }

            PixelButton(title: "Ouvrir le salon") {
                router.createDuel(settings: settings)
                goLobby = true
            }
            .screenPadding()
            .padding(.bottom, 16)
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            settings.stake = DuelWager.suggestedStake(coins: coins)
        }
        .navigationDestination(isPresented: $goLobby) { DuelRoomView() }
    }
}
