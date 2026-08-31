import SwiftUI

/// The waiting room content: shareable code, the pot at stake, live roster
/// (presence), and the host's "Lancer" button. Hosted inside `DuelRoomView`,
/// which owns navigation.
///
/// Les réglages (mise, règle de score, thème) sont figés à la création, sur
/// `DuelSetupView` : le salon ne fait que les refléter.
struct DuelLobbyView: View {
    let duel: DuelController
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    private var errorMessage: String? {
        if case .error(let message) = duel.status { return message }
        return nil
    }

    var body: some View {
        // En-tête et bouton d'action restent fixes ; le reste défile. Avec le
        // panneau de mise en plus, un simple VStack débordait sur les petits
        // écrans (ou en gros corps de texte) et écrasait le contenu du milieu.
        VStack(spacing: 0) {
            header
                .screenPadding()
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 16) {
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

                    potCard

                    statusLine

                    roster
                }
                .screenPadding()
                .padding(.vertical, 16)
            }

            footer
                .screenPadding()
                .padding(.bottom, 16)
        }
    }

    private var header: some View {
        HStack {
            Button { quit() } label: {
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

    /// La liste des joueurs présents. Au-delà de 6 elle passe en deux colonnes :
    /// 16 lignes pleine largeur feraient défiler le salon sans fin.
    @ViewBuilder private var roster: some View {
        if duel.match.needsCompactRoster {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)],
                      spacing: 0) {
                ForEach(duel.players) { player in
                    PlayerRow(player: player, compact: true)
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: 0.5))
                }
            }
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(duel.players.enumerated()), id: \.element.clientID) { idx, player in
                    if idx > 0 { Divider().overlay(Theme.border) }
                    PlayerRow(player: player)
                }
            }
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
        }
    }

    // MARK: Cagnotte

    /// Ce que la table met en jeu, et rien d'autre : mise × joueurs présents. La
    /// mise, la règle de score et le thème ont été arrêtés à la création, le salon
    /// ne les rediscute pas.
    private var potCard: some View {
        VStack(spacing: 6) {
            SectionLabel("Cagnotte")
            if !duel.settingsKnown {
                Text("...").font(KFont.pixel(28)).foregroundStyle(Theme.muted)
            } else if duel.stake == 0 {
                Text("AMICALE").font(KFont.mono(15, bold: true)).tracking(2)
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 9) {
                    Circle().strokeBorder(accent, lineWidth: 2).frame(width: 17, height: 17)
                    Text("\(duel.pot)").font(KFont.pixel(30)).foregroundStyle(accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .kPanel(18)
    }

    @ViewBuilder private var statusLine: some View {
        switch duel.status {
        case .connecting:
            Text("CONNEXION...").font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
        case .connected:
            VStack(spacing: 4) {
                Text(summaryLine)
                    .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                Text(duel.scoring.shortLabel)
                    .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                // Le thème n'est affiché qu'une fois les réglages reçus : un
                // invité qui ne les a pas encore verrait « tous les thèmes »
                // alors que l'hôte a peut-être choisi une catégorie.
                if duel.settingsKnown {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: duel.match.settings.category.colorHex))
                            .frame(width: 7, height: 7)
                        Text(duel.themeLabel)
                            .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                    }
                }
            }
            .multilineTextAlignment(.center)
        case .error:
            EmptyView()   // rendu en bas, en panneau rouge, avec le bouton Quitter
        }
    }

    @ViewBuilder private var footer: some View {
        if let errorMessage {
            VStack(spacing: 10) {
                Text(errorMessage.uppercased())
                    .font(KFont.mono(11, bold: true)).tracking(1)
                    .foregroundStyle(Theme.bad)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16).padding(.horizontal, 12)
                    .overlay(Rectangle().stroke(Theme.bad, lineWidth: 1))
                PixelButton(title: "Quitter", style: .ghost) { quit() }
            }
        } else if duel.isHost {
            PixelButton(title: hostButtonTitle) { duel.startRound() }
                .opacity(duel.canStart ? 1 : 0.5)
                .disabled(!duel.canStart)
        } else {
            Text("EN ATTENTE DE L'HÔTE")
                .font(KFont.mono(11)).tracking(1).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
        }
    }

    /// Effectif, longueur de la manche et mise, en une ligne. La longueur n'est
    /// annoncée qu'une fois les réglages reçus : sinon un invité lirait la valeur
    /// par défaut à la place de celle de l'hôte.
    private var summaryLine: String {
        var parts = ["\(duel.players.count)/\(DuelMatch.maxPlayers) JOUEURS"]
        if duel.settingsKnown { parts.append("\(duel.questionCount) QUESTIONS") }
        if duel.stake > 0 { parts.append("MISE \(duel.stake)") }
        return parts.joined(separator: " · ")
    }

    private var hostButtonTitle: String {
        if !duel.canAffordStake { return "Mise trop élevée" }
        return duel.canStart ? "Lancer la partie" : "En attente de joueurs"
    }

    private func quit() {
        router.activeDuel?.leave()
        router.activeDuel = nil
    }
}

private struct PlayerRow: View {
    let player: DuelPlayer
    /// Version deux colonnes : pseudo plus petit et badge hôte réduit à une pastille.
    var compact: Bool = false
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Circle()
                .fill(Color(hex: player.accentHex ?? Theme.Accent.vert.hex))
                .frame(width: compact ? 9 : 12, height: compact ? 9 : 12)
            Text(player.pseudo)
                .font(KFont.mono(compact ? 12 : 14))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if player.isHost {
                Text(compact ? "H" : "HÔTE")
                    .font(KFont.mono(9)).tracking(1).foregroundStyle(accent)
                    .padding(.vertical, 4).padding(.horizontal, compact ? 5 : 7)
                    .overlay(Rectangle().stroke(accent, lineWidth: 1))
            }
        }
        .padding(.vertical, compact ? 9 : 12)
        .padding(.horizontal, compact ? 9 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
