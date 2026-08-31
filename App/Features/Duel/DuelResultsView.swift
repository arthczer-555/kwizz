import SwiftUI

/// The end-of-duel screen: the global ranking by points, the local player's gains,
/// and a full recap of every question (correct answer, explanation, what each player
/// answered, and who took the point).
struct DuelResultsView: View {
    let duel: DuelController
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    private var board: [DuelScore] { duel.match.scoreboard }
    private var myRank: Int { board.first { $0.player.clientID == duel.localClientID }?.rank ?? 0 }
    /// Le règlement de la partie : mise, cagnotte et nombre de vainqueurs.
    private var wager: DuelWager { duel.match.finalWager }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(myRank == 1 ? "VICTOIRE" : "TERMINÉ")
                    .font(KFont.mono(13, bold: true)).tracking(2)
                    .foregroundStyle(myRank == 1 ? accent : Theme.text)
                    .padding(.top, 24)

                if wager.stake > 0 {
                    Text(wagerHeadline)
                        .font(KFont.mono(11, bold: true)).tracking(1)
                        .foregroundStyle(myRank == 1 ? accent : Theme.bad)
                        .multilineTextAlignment(.center)
                }

                Text("\(duel.scoring.shortLabel) · \(duel.themeLabel)")
                    .font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                SectionLabel("Classement")
                podium

                if let result = duel.localResult { gains(result) }

                SectionLabel("Récap des questions")
                ForEach(Array(duel.match.questions.enumerated()), id: \.offset) { idx, question in
                    QuestionRecapCard(duel: duel, index: idx, question: question)
                }

                rematchFooter
                    .padding(.top, 4)
            }
            .screenPadding()
            .padding(.vertical, 18)
        }
        .screenBackground()
    }

    /// Rejouer ou rentrer. L'hôte relance la salle telle quelle : même code, mêmes
    /// réglages, et tous ceux encore connectés repartent au salon sans rien
    /// ressaisir. Un invité ne peut que patienter, la relance appartient à l'hôte.
    @ViewBuilder private var rematchFooter: some View {
        VStack(spacing: 10) {
            if duel.isHost {
                PixelButton(title: "Rejouer avec les mêmes joueurs") { duel.requestRematch() }
                    .opacity(duel.canRematch ? 1 : 0.5)
                    .disabled(!duel.canRematch)
                Text("La partie \(duel.roomCode) rouvre avec les joueurs encore connectés.")
                    .font(KFont.mono(10)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("L'HÔTE PEUT RELANCER UNE MANCHE")
                    .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            }
            PixelButton(title: "Accueil", style: .ghost) { router.goHome() }
        }
    }

    /// Ce que la mise a rapporté ou coûté, en une ligne, sous le titre.
    private var wagerHeadline: String {
        guard myRank == 1 else { return "MISE PERDUE : \(wager.stake) PIÈCES" }
        if wager.winnerCount > 1 {
            return "CAGNOTTE DE \(wager.pot) PARTAGÉE À \(wager.winnerCount) : \(wager.winnerShare) PIÈCES"
        }
        return "TU RAFLES LA CAGNOTTE : \(wager.pot) PIÈCES"
    }

    private var podium: some View {
        VStack(spacing: 0) {
            ForEach(Array(board.enumerated()), id: \.element.id) { idx, score in
                if idx > 0 { Divider().overlay(Theme.border) }
                HStack(spacing: 12) {
                    Text("#\(score.rank)")
                        .font(KFont.mono(13, bold: true))
                        .foregroundStyle(score.rank == 1 ? accent : Theme.muted)
                        .frame(width: 32, alignment: .leading)
                    Circle()
                        .fill(Color(hex: score.player.accentHex ?? Theme.Accent.vert.hex))
                        .frame(width: 10, height: 10)
                    Text(score.player.pseudo)
                        .font(KFont.mono(14, bold: score.player.clientID == duel.localClientID))
                        .foregroundStyle(score.player.clientID == duel.localClientID ? accent : Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(score.points) pt")
                        .font(KFont.mono(15, bold: true))
                        .foregroundStyle(score.player.clientID == duel.localClientID ? accent : Theme.text)
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func gains(_ result: GameResult) -> some View {
        VStack(spacing: 0) {
            DuelRecapRow(label: "Bonnes réponses", value: "\(result.correctCount)/\(result.total)")
            Divider().overlay(Theme.border)
            if wager.stake > 0 {
                DuelRecapRow(label: "Mise", value: "\(wager.stake)")
                Divider().overlay(Theme.border)
                DuelRecapRow(label: "Cagnotte", value: "\(wager.pot)", highlight: myRank == 1)
                Divider().overlay(Theme.border)
            }
            DuelRecapRow(label: "Pièces", value: result.coinsEarned >= 0 ? "+\(result.coinsEarned)" : "\(result.coinsEarned)", highlight: true)
            Divider().overlay(Theme.border)
            DuelRecapRow(label: "XP", value: "+\(result.xpEarned)")
            if let chests = duel.localApplied?.chestsEarned, chests > 0 {
                Divider().overlay(Theme.border)
                DuelRecapRow(label: chests > 1 ? "Coffres" : "Coffre", value: "+\(chests)", highlight: true)
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }
}

/// One question in the end-of-game recap.
private struct QuestionRecapCard: View {
    let duel: DuelController
    let index: Int
    let question: Question
    @Environment(\.accent) private var accent

    private var winner: String? { duel.match.winners[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(String(format: "Q%02d", index + 1)).font(KFont.mono(10, bold: true)).foregroundStyle(Theme.muted)
                Text(question.text).font(KFont.body(14, weight: .semibold)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal").font(.system(size: 11))
                Text("\(letterFor(question.correctIndex)) · \(question.correctAnswer ?? "")")
                    .font(KFont.mono(12, bold: true))
            }
            .foregroundStyle(accent)

            if let explanation = question.explanation, !explanation.isEmpty {
                Text(explanation).font(KFont.mono(11)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Theme.border)

            // Salle nombreuse : détailler 16 joueurs sur chacune des 7 questions
            // ferait un récap illisible. On garde le vainqueur, sa propre réponse
            // et le décompte ; le détail complet reste pour les petites parties.
            if duel.match.needsCompactRoster {
                summaryRows
            } else {
                ForEach(duel.match.players) { player in
                    playerAnswerRow(player)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(12)
    }

    /// Version condensée : le vainqueur du point, ta réponse, et le nombre de
    /// joueurs qui ont trouvé.
    @ViewBuilder private var summaryRows: some View {
        if let winner, let champion = duel.match.player(id: winner) {
            playerAnswerRow(champion)
        }
        if let me = duel.match.player(id: duel.localClientID), me.clientID != winner {
            playerAnswerRow(me)
        }
        HStack {
            Text("ONT TROUVÉ").font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
            Spacer()
            Text("\(correctCount) / \(duel.match.players.count)")
                .font(KFont.mono(11, bold: true)).foregroundStyle(Theme.muted)
        }
    }

    private var correctCount: Int {
        duel.match.players.filter { duel.match.answer(of: $0.clientID, at: index)?.correct == true }.count
    }

    private func playerAnswerRow(_ player: DuelPlayer) -> some View {
        let answer = duel.match.answer(of: player.clientID, at: index)
        let chosen = answer?.answerIndex
        let correct = answer?.correct ?? false
        return HStack(spacing: 8) {
            if player.clientID == winner {
                Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(accent)
            }
            Text(player.pseudo)
                .font(KFont.mono(12, bold: player.clientID == duel.localClientID))
                .foregroundStyle(player.clientID == duel.localClientID ? accent : Theme.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(chosen.map(letterFor) ?? "—")
                .font(KFont.mono(12, bold: true))
                .foregroundStyle(correct ? accent : (chosen == nil ? Theme.muted : Theme.bad))
            Image(systemName: correct ? "checkmark" : "xmark")
                .font(.system(size: 10))
                .foregroundStyle(correct ? accent : Theme.bad)
                .opacity(chosen == nil ? 0.4 : 1)
        }
    }

    private func letterFor(_ i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return i < letters.count ? letters[i] : "?"
    }
}

private struct DuelRecapRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    @Environment(\.accent) private var accent

    var body: some View {
        HStack {
            Text(label).font(KFont.mono(12)).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(KFont.mono(13, bold: true)).foregroundStyle(highlight ? accent : Theme.text)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
    }
}
