import SwiftUI

/// The pushed duel destination. It owns navigation (hidden bar, pop when the duel
/// ends) and swaps between lobby, the synchronised game, and the podium by phase.
struct DuelRoomView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if let duel = router.activeDuel {
                switch duel.match.phase {
                case .lobby, .countdown:
                    DuelLobbyView(duel: duel)
                    if let n = duel.countdown { CountdownOverlay(value: n) }
                case .question, .reveal:
                    DuelGameView(duel: duel)
                case .finished:
                    DuelResultsView(duel: duel)
                }
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: router.activeDuel == nil) { _, gone in if gone { dismiss() } }
    }
}
