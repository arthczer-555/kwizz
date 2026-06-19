import SwiftUI

/// Bandeau affiché après la première partie, quand le joueur a de quoi s'offrir
/// son premier cosmétique. L'oriente vers la boutique. Simple et épuré.
struct FirstCosmeticNudge: View {
    let onGo: () -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Première récompense")
            Text("Tu as de quoi t'offrir ton premier item !")
                .font(KFont.body(13)).foregroundStyle(Theme.text)
            HStack {
                CoinLabel(amount: Economy.welcomeFloor)
                Spacer()
                PixelButton(title: "Boutique", fullWidth: false) { onGo() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel()
    }
}
