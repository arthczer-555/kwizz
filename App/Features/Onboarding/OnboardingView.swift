import SwiftUI

/// Root onboarding screen (not pushed): the player picks a pseudo, then taps
/// "Press start" to enter the app. Arcade-minimal: logo, INSERT COIN tagline,
/// the mannequin avatar, a pseudo panel and the start button.
struct OnboardingView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent
    @State private var pseudo = "RetroKid"

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            KwizzLogo(size: 36)

            Text("INSERT COIN")
                .font(KFont.mono(12))
                .tracking(2)
                .foregroundStyle(accent)

            AvatarLayeredView(look: store.avatarLook, scale: 1.0)

            VStack(alignment: .leading, spacing: Space.xs) {
                SectionLabel("Pseudo")
                TextField("", text: $pseudo)
                    .font(KFont.mono(18))
                    .foregroundStyle(Theme.text)
                    .tint(accent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kPanel()

            PixelButton(title: "Press start") {
                store.completeOnboarding(pseudo: pseudo)
            }

            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .screenBackground()
    }
}

#Preview {
    OnboardingView()
        .environment(PlayerStore())
        .environment(\.accent, Theme.Accent.vert.color)
}
