import SwiftUI

/// La confirmation de mise d'un invité, posée par-dessus le salon dès que les
/// réglages de l'hôte arrivent. L'hôte a choisi le montant lui-même sur
/// `DuelSetupView` ; un invité, lui, tape un code sans savoir ce que la partie
/// coûte, et le découvrirait une fois ses pièces parties. Tant qu'il n'a pas
/// confirmé ici, rien ne l'engage : quitter le salon ne coûte rien, et une manche
/// lancée entre-temps le sort de la partie au lieu de le faire payer.
///
/// Rien à confirmer dans une partie amicale (mise à zéro) : `DuelController`
/// n'affiche alors pas cet écran.
struct StakeConfirmOverlay: View {
    let duel: DuelController
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    SectionLabel("Mise de la partie")
                    HStack(spacing: 10) {
                        Circle().strokeBorder(accent, lineWidth: 2).frame(width: 20, height: 20)
                        Text("\(duel.stake)").font(KFont.pixel(38)).foregroundStyle(accent)
                    }
                    Text("Tu paies cette mise en entrant dans la partie. Le gagnant rafle la cagnotte : la mise de tous les joueurs.")
                        .font(KFont.body(13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .kPanel(18)

                VStack(spacing: 0) {
                    row("Cagnotte actuelle", duel.pot, highlighted: true)
                    Divider().overlay(Theme.border)
                    row("Tes pièces", duel.coins)
                    Divider().overlay(Theme.border)
                    row("Après la mise", duel.coinsAfterStake)
                }
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))

                Text("La cagnotte grossit à chaque joueur qui rejoint le salon.")
                    .font(KFont.mono(10))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    PixelButton(title: "Confirmer ma mise") { duel.confirmStake() }
                    PixelButton(title: "Quitter", style: .ghost) { duel.declineStake() }
                }
            }
            .screenPadding()
        }
        .transition(.opacity)
    }

    private func row(_ label: String, _ amount: Int, highlighted: Bool = false) -> some View {
        HStack {
            Text(label.uppercased())
                .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            CoinLabel(amount: amount, color: highlighted ? accent : Theme.text, size: 14)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}
