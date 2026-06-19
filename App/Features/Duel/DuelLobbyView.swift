import SwiftUI

/// The waiting room content: shareable code, live roster (presence), and the host's
/// "Lancer" button. Hosted inside `DuelRoomView`, which owns navigation.
struct DuelLobbyView: View {
    let duel: DuelController
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 16) {
            header

            VStack(spacing: 8) {
                SectionLabel("Code de la partie")
                Text(duel.roomCode)
                    .font(KFont.pixel(34)).foregroundStyle(accent).tracking(2)
                ShareLink(item: "Rejoins ma partie Kwizz avec le code \(duel.roomCode)") {
                    Text("PARTAGER")
                        .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity).kPanel(18)

            statusLine

            VStack(spacing: 0) {
                ForEach(Array(duel.players.enumerated()), id: \.element.clientID) { idx, player in
                    if idx > 0 { Divider().overlay(Theme.border) }
                    PlayerRow(player: player)
                }
            }
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))

            Spacer()

            if duel.isHost {
                PixelButton(title: duel.canStart ? "Lancer la partie" : "En attente de joueurs") {
                    duel.startRound()
                }
                .opacity(duel.canStart ? 1 : 0.5)
                .disabled(!duel.canStart)
            } else {
                Text("EN ATTENTE DE L'HÔTE")
                    .font(KFont.mono(11)).tracking(1).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            }
        }
        .screenPadding().padding(.vertical, 16)
    }

    private var header: some View {
        HStack {
            Button {
                router.activeDuel?.leave()
                router.activeDuel = nil
            } label: {
                Text("◀ QUITTER")
                    .font(KFont.mono(11)).foregroundStyle(Theme.text)
                    .padding(.vertical, 8).padding(.horizontal, 11)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("SALON").font(KFont.mono(13, bold: true)).tracking(1).foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 90, height: 1)
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch duel.status {
        case .connecting:
            Text("CONNEXION...").font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
        case .connected:
            Text("\(duel.players.count)/\(DuelMatch.maxPlayers) JOUEURS · 1 PT PAR BONNE RÉPONSE LA PLUS RAPIDE")
                .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        case .error(let message):
            Text(message.uppercased()).font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.bad)
        }
    }
}

private struct PlayerRow: View {
    let player: DuelPlayer
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: player.accentHex ?? Theme.Accent.vert.hex))
                .frame(width: 12, height: 12)
            Text(player.pseudo).font(KFont.mono(14)).foregroundStyle(Theme.text)
            Spacer()
            if player.isHost {
                Text("HÔTE").font(KFont.mono(9)).tracking(1).foregroundStyle(accent)
                    .padding(.vertical, 4).padding(.horizontal, 7)
                    .overlay(Rectangle().stroke(accent, lineWidth: 1))
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
    }
}

/// The full-screen 3·2·1 shown over the lobby just before the first question.
struct CountdownOverlay: View {
    let value: Int
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 10) {
                SectionLabel("Préparez-vous")
                Text("\(value)").font(KFont.pixel(72)).foregroundStyle(accent)
            }
        }
        .transition(.opacity)
    }
}
