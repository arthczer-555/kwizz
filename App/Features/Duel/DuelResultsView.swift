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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(myRank == 1 ? "VICTOIRE" : "TERMINÉ")
                    .font(KFont.mono(13, bold: true)).tracking(2)
                    .foregroundStyle(myRank == 1 ? accent : Theme.text)
                    .padding(.top, 24)

                SectionLabel("Classement")
                podium

                if let result = duel.localResult { gains(result) }

                SectionLabel("Récap des questions")
                ForEach(Array(duel.match.questions.enumerated()), id: \.offset) { idx, question in
                    QuestionRecapCard(duel: duel, index: idx, question: question)
                }

                PixelButton(title: "Accueil") { router.goHome() }
                    .padding(.top, 4)
            }
            .screenPadding()
            .padding(.vertical, 18)
        }
        .screenBackground()
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

            ForEach(duel.match.players) { player in
                let answer = duel.match.answer(of: player.clientID, at: index)
                let chosen = answer?.answerIndex
                let correct = answer?.correct ?? false
                HStack(spacing: 8) {
                    if player.clientID == winner {
                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(accent)
                    }
                    Text(player.pseudo).font(KFont.mono(12)).foregroundStyle(Theme.text).lineLimit(1)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(12)
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
