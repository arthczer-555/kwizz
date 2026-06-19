import SwiftUI

/// The pushed ranked destination: it owns navigation and swaps between searching,
/// the synchronised game, and the results by the controller's stage/phase. Mirrors
/// `DuelRoomView` but for the server-authoritative `RankedController`.
struct RankedRoomView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if let r = router.activeRanked {
                switch r.stage {
                case .searching:
                    RankedSearchView(controller: r)
                case .error(let message):
                    RankedErrorView(message: message)
                case .active:
                    if r.isFinished {
                        RankedResultsView(controller: r)
                    } else {
                        RankedGameView(controller: r)
                        if let n = r.countdown { CountdownOverlay(value: n) }
                    }
                }
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: router.activeRanked == nil) { _, gone in if gone { dismiss() } }
    }
}

/// "Recherche d'un adversaire…" with the player's current tier and rating.
struct RankedSearchView: View {
    let controller: RankedController
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            let tier = RankTier.tier(forRating: controller.ratingBefore)
            Text(tier.title.uppercased())
                .font(KFont.mono(13, bold: true)).tracking(2)
                .foregroundStyle(Color(hex: tier.colorHex))
            ScoreText(value: controller.ratingBefore, size: 46)
            ProgressView().tint(accent).padding(.top, 6)
            Text("Recherche d'un adversaire…")
                .font(KFont.mono(13)).foregroundStyle(Theme.muted)
            Spacer()
            PixelButton(title: "Annuler", style: .ghost) { router.quitRanked() }
        }
        .frame(maxWidth: .infinity)
        .screenPadding()
        .padding(.vertical, 28)
    }
}

/// Matchmaking failure / no opponent found.
struct RankedErrorView: View {
    let message: String
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 34)).foregroundStyle(accent)
            Text(message)
                .font(KFont.mono(14, bold: true))
                .multilineTextAlignment(.center)
            Spacer()
            PixelButton(title: "Retour") { router.endRanked() }
        }
        .frame(maxWidth: .infinity)
        .screenPadding()
        .padding(.vertical, 28)
    }
}
