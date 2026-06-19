import SwiftUI

/// The synchronised ranked question screen: same question for both players, tap an
/// answer, then a reveal shows the correct answer, who was fastest, and the point.
/// Reuses `TimerBar`, `DuelAnswerRow` and `CountdownOverlay` from the friend duel.
struct RankedGameView: View {
    let controller: RankedController
    @Environment(\.accent) private var accent
    @Environment(Router.self) private var router

    private var index: Int { controller.currentIndex }
    private var question: Question? { controller.currentQuestion }
    private var isReveal: Bool { controller.isReveal }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                if !isReveal { TimerBar(fraction: controller.barFraction) }
                scoreboard
                    .padding(10)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                if let q = question {
                    questionCard(q)
                    answers(q)
                    if isReveal { revealPanel(q) }
                }
            }
            .screenPadding()
            .padding(.vertical, 12)
        }
        .screenBackground()
    }

    private var header: some View {
        HStack {
            Text(String(format: "QUESTION %02d/%02d", index + 1, controller.totalQuestions))
                .font(KFont.mono(12)).foregroundStyle(Theme.muted)
            Spacer()
            Button { router.quitRanked() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
        }
    }

    private var scoreboard: some View {
        HStack(spacing: 8) {
            chip(controller.me, score: controller.scoreMe, isMe: true)
            Text("VS").font(KFont.mono(10)).foregroundStyle(Theme.muted)
            chip(controller.opponent, score: controller.scoreOpponent, isMe: false)
        }
    }

    private func chip(_ player: DuelPlayer?, score: Int, isMe: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: player?.accentHex ?? Theme.Accent.vert.hex))
                .frame(width: 8, height: 8)
            Text(player?.pseudo ?? (isMe ? "Toi" : "Adv."))
                .font(KFont.mono(12, bold: isMe))
                .foregroundStyle(isMe ? accent : Theme.text)
                .lineLimit(1)
            if isMe && controller.localAnswered && !isReveal {
                Image(systemName: "checkmark").font(.system(size: 9)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            Text("\(score) pt").font(KFont.mono(13, bold: true)).foregroundStyle(isMe ? accent : Theme.text)
        }
        .frame(maxWidth: .infinity)
    }

    private func questionCard(_ q: Question) -> some View {
        Text(q.text)
            .font(KFont.body(19, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20).padding(.horizontal, 16)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func answers(_ q: Question) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(q.answers.enumerated()), id: \.offset) { idx, text in
                DuelAnswerRow(letter: letter(idx), text: text, state: state(idx, q)) {
                    controller.localAnswer(idx)
                }
                .disabled(isReveal || controller.localAnswered)
            }
        }
    }

    @ViewBuilder private func revealPanel(_ q: Question) -> some View {
        let winner = controller.match?.winners[index]
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 12))
                if let winner, let p = controller.match?.player(id: winner) {
                    Text("\(p.pseudo.uppercased()) +1").font(KFont.mono(11, bold: true)).tracking(1)
                } else {
                    Text("PERSONNE N'A TROUVÉ").font(KFont.mono(11, bold: true)).tracking(1)
                }
            }
            .foregroundStyle(winner != nil ? accent : Theme.muted)
            if let explanation = q.explanation, !explanation.isEmpty {
                Text(explanation).font(KFont.mono(12)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(12)
    }

    private func state(_ idx: Int, _ q: Question) -> DuelAnswerRow.State {
        if isReveal {
            if idx == q.correctIndex { return .correct }
            if idx == controller.localSelectedIndex { return .wrong }
            return .dim
        }
        if controller.localAnswered { return idx == controller.localSelectedIndex ? .selected : .dim }
        return .idle
    }

    private func letter(_ i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return i < letters.count ? letters[i] : "?"
    }
}
