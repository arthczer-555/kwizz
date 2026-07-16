import SwiftUI

/// Root onboarding screen (not pushed): the player picks a pseudo, then taps
/// "Press start" to enter the app. Arcade-minimal: logo, INSERT COIN tagline,
/// the mannequin avatar, a pseudo panel and the start button.
struct OnboardingView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent
    /// Volontairement vide : quand le champ était pré-rempli avec "RetroKid", la
    /// plupart des joueurs validaient sans y toucher et se retrouvaient tous
    /// homonymes. Les pseudos étant désormais uniques, il faut un choix explicite.
    @State private var claim = PseudoClaim()

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            KwizzLogo(size: 36)

            Text("INSERT COIN")
                .font(KFont.mono(12))
                .tracking(2)
                .foregroundStyle(accent)

            AvatarLayeredView(look: store.avatarLook, scale: 1.0)

            PseudoField(claim: claim) { start() }
                .kPanel()

            PixelButton(title: claim.isBusy ? "..." : "Press start") { start() }
                .disabled(claim.isBusy || !claim.isLengthValid)

            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .screenBackground()
    }

    /// N'entre dans l'app qu'une fois le pseudo réservé : sinon le joueur
    /// démarrerait sous un pseudo que le serveur refusera à la première sync.
    private func start() {
        Task {
            if await claim.submit(into: store) {
                store.completeOnboarding(pseudo: claim.trimmed)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(PlayerStore())
        .environment(\.accent, Theme.Accent.vert.color)
}
