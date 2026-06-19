import SwiftUI

/// The synchronised duel question screen: everyone sees the same question, taps an
/// answer, then a reveal shows the correct answer, the explanation, who answered
/// what, and who took the point.
struct DuelGameView: View {
    let duel: DuelController
    @Environment(\.accent) private var accent
    @Environment(Router.self) private var router

    private var isReveal: Bool { if case .reveal = duel.match.phase { return true }; return false }
    private var index: Int { duel.match.currentIndex ?? 0 }
    private var question: Question? { duel.match.currentQuestion }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                if !isReveal { TimerBar(fraction: duel.barFraction) }
                LiveScoreboardView(duel: duel, compact: true)
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
            Text(String(format: "QUESTION %02d/%02d", index + 1, duel.match.totalQuestions))
                .font(KFont.mono(12)).foregroundStyle(Theme.muted)
            Spacer()
            Button { router.goHome() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
        }
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
                    duel.localAnswer(idx)
                }
                .disabled(isReveal || duel.localAnswered)
            }
        }
    }

    @ViewBuilder private func revealPanel(_ q: Question) -> some View {
        let winner = duel.match.winners[index]
        VStack(alignment: .leading, spacing: 12) {
            // Winner line.
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 12))
                if let winner, let p = duel.match.player(id: winner) {
                    Text("\(p.pseudo.uppercased()) +1").font(KFont.mono(11, bold: true)).tracking(1)
                } else {
                    Text("PERSONNE N'A TROUVÉ").font(KFont.mono(11, bold: true)).tracking(1)
                }
            }
            .foregroundStyle(winner != nil ? accent : Theme.muted)

            // Explanation.
            if let explanation = q.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(KFont.mono(12)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Theme.border)
            SectionLabel("Réponses")
            ForEach(duel.match.players) { player in
                answerRecapRow(player: player, q: q, isWinner: player.clientID == winner)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel(12)
    }

    private func answerRecapRow(player: DuelPlayer, q: Question, isWinner: Bool) -> some View {
        let answer = duel.match.answer(of: player.clientID, at: index)
        let chosen = answer?.answerIndex
        let correct = answer?.correct ?? false
        return HStack(spacing: 8) {
            if isWinner { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(accent) }
            Text(player.pseudo).font(KFont.mono(12)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 8)
            Text(chosen.map { "\(letter($0))" } ?? "—")
                .font(KFont.mono(12, bold: true))
                .foregroundStyle(correct ? accent : (chosen == nil ? Theme.muted : Theme.bad))
            Image(systemName: correct ? "checkmark" : "xmark")
                .font(.system(size: 10))
                .foregroundStyle(correct ? accent : Theme.bad)
                .opacity(chosen == nil ? 0.4 : 1)
        }
    }

    // MARK: Answer state

    private func state(_ idx: Int, _ q: Question) -> DuelAnswerRow.State {
        if isReveal {
            if idx == q.correctIndex { return .correct }
            if idx == duel.localSelectedIndex { return .wrong }
            return .dim
        }
        if duel.localAnswered { return idx == duel.localSelectedIndex ? .selected : .dim }
        return .idle
    }

    private func letter(_ i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return i < letters.count ? letters[i] : "?"
    }
}

/// An answer button for the duel: like the solo `AnswerRow` but with a "selected
/// but not yet revealed" state (you've locked your answer, waiting for the others).
struct DuelAnswerRow: View {
    enum State { case idle, selected, correct, wrong, dim }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(letter).font(KFont.mono(13)).foregroundStyle(keyColor)
                Text(text).font(KFont.mono(13)).foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if state == .correct { Image(systemName: "checkmark").font(.system(size: 12)).foregroundStyle(accent) }
                if state == .wrong { Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(Theme.bad) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(borderColor, lineWidth: 1))
            .opacity(state == .dim ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        switch state {
        case .correct, .selected: accent
        case .wrong: Theme.bad
        default: Theme.border
        }
    }
    private var textColor: Color {
        switch state {
        case .correct, .selected: accent
        case .wrong: Theme.bad
        default: Theme.text
        }
    }
    private var keyColor: Color {
        switch state {
        case .correct, .selected: accent
        case .wrong: Theme.bad
        default: Theme.muted
        }
    }
}
