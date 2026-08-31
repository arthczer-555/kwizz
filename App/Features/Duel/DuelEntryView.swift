import SwiftUI

/// Entry point for an online duel: create a room (become host) or join one by code.
struct DuelEntryView: View {
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent
    @State private var code = ""
    @State private var goSetup = false
    @State private var goLobby = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BackHeader(title: "Duel en ligne")

                VStack(alignment: .leading, spacing: 10) {
                    PixelButton(title: "Créer une partie") {
                        goSetup = true
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .kPanel()

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Rejoindre avec un code")
                    TextField("CODE", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(KFont.mono(22, bold: true))
                        .tracking(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(accent)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                        .onChange(of: code) { _, newValue in
                            let cleaned = RoomCode.normalize(newValue)
                            if cleaned != code { code = cleaned }
                        }
                    Text("La mise est fixée par l'hôte : il te faudra assez de pièces pour entrer.")
                        .font(KFont.body(12)).foregroundStyle(Theme.muted)
                    PixelButton(title: "Rejoindre", style: .ghost) {
                        guard RoomCode.isValid(code) else { return }
                        router.joinDuel(code: code)
                        goLobby = true
                    }
                    .opacity(RoomCode.isValid(code) ? 1 : 0.45)
                    .disabled(!RoomCode.isValid(code))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .kPanel()

                if !DuelTransportFactory.isLive {
                    Text("Mode démo : pas de serveur configuré, tu joueras contre des adversaires simulés.")
                        .font(KFont.mono(10)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .screenPadding()
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goSetup) { DuelSetupView() }
        .navigationDestination(isPresented: $goLobby) { DuelRoomView() }
    }
}
