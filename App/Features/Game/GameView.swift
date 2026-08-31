import SwiftUI

/// Full-screen game container, presented as a cover. Swaps to results when done.
struct GamePlayView: View {
    let game: GameController

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch game.phase {
            case .results(let result):
                ResultsView(game: game, result: result)
            default:
                GameView(game: game)
            }
        }
    }
}

struct GameView: View {
    let game: GameController
    @Environment(\.accent) private var accent
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var showQuitConfirm = false
    /// Instant où l'app a commencé à partir en arrière-plan, et si elle y est
    /// vraiment allée (un simple centre de contrôle ne passe que par `.inactive`).
    @State private var leftAt: Date?
    @State private var didBackground = false

    /// Tolérance : un appel entrant ou une notification ne doivent pas coûter le
    /// défi, au-delà c'est une sortie volontaire (et une occasion de tricher).
    private let backgroundTolerance: TimeInterval = 10

    private var isDefi: Bool { game.session.mode == .defi }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topRow
                statusRow
                timerBar
                questionCard
                answersList
                explanationBanner
                footer
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .onAppear { game.start() }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .alert("Quitter le défi ?", isPresented: $showQuitConfirm) {
            Button("Valider et quitter", role: .destructive) { game.abandonAsFinished() }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Le défi du jour ne se joue qu'une fois. Si tu quittes maintenant, ton score sera validé en l'état.")
        }
    }

    /// Le X ne quitte plus en silence pendant le défi : sortir, c'est valider.
    private func requestExit() {
        if isDefi {
            showQuitConfirm = true
        } else {
            router.endGame()
        }
    }

    /// Anti-triche du défi du jour : quitter l'app pendant la partie la valide en
    /// l'état. Cette vue n'est affichée que pendant le jeu (l'écran de résultats
    /// est une autre vue), donc rien à surveiller une fois le score affiché.
    private func handleScenePhase(_ phase: ScenePhase) {
        guard isDefi else { return }
        switch phase {
        case .inactive:
            // `.inactive` précède `.background` : on note l'instant le plus tôt
            // possible, mais sans armer (centre de contrôle, bannière d'appel...).
            if leftAt == nil { leftAt = Date() }
        case .background:
            if leftAt == nil { leftAt = Date() }
            didBackground = true
        case .active:
            let away = leftAt.map { Date().timeIntervalSince($0) } ?? 0
            let wentAway = didBackground
            leftAt = nil
            didBackground = false
            if wentAway, away > backgroundTolerance {
                game.abandonAsFinished()
            } else {
                game.resyncTimerAfterResume()
            }
        @unknown default:
            break
        }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Score")
                Text("\(game.session.score)").font(KFont.pixel(22)).foregroundStyle(accent)
            }
            Spacer()
            Button { requestExit() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.muted).padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var statusRow: some View {
        HStack {
            Text(progressText).font(KFont.mono(12)).foregroundStyle(Theme.muted)
            Spacer()
            if game.session.mode == .duel {
                Text("VS BOT · \(game.duelBotScore)").font(KFont.mono(10)).foregroundStyle(Theme.muted)
            } else if game.session.streak > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 11))
                    Text("série \(game.session.streak)").font(KFont.mono(11))
                }
                .foregroundStyle(accent)
            }
        }
    }

    @ViewBuilder private var timerBar: some View {
        if game.isContreLaMontre {
            TimerBar(fraction: game.globalFraction)
        } else if game.usesPerQuestionTimer {
            TimerBar(fraction: game.barFraction)
        } else {
            HStack { SectionLabel("\(game.session.mode.title) · sans chrono"); Spacer() }
        }
    }

    private var questionCard: some View {
        Text(game.session.current?.text ?? "")
            .font(KFont.body(19, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private var answersList: some View {
        VStack(spacing: 10) {
            if let q = game.session.current {
                ForEach(Array(q.answers.enumerated()), id: \.offset) { idx, text in
                    AnswerRow(letter: letter(idx), text: text, state: answerState(idx, correctIndex: q.correctIndex)) {
                        game.answer(idx)
                    }
                    .disabled(!isPlaying)
                }
            }
        }
    }

    /// The answer explanation. Its space is reserved from the start of the
    /// question (rendered invisibly during `.playing`) so that revealing it
    /// doesn't push the answers list upward, only fades it in. Skipped in
    /// contre-la-montre, which auto-advances too fast to read it.
    @ViewBuilder private var explanationBanner: some View {
        if !game.isContreLaMontre,
           let explanation = game.session.current?.explanation,
           !explanation.isEmpty {
            let correct = revealedWasCorrect
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: correct ? "checkmark.seal" : "lightbulb")
                        .font(.system(size: 11))
                    Text((correct ? "Bien vu" : "À retenir").uppercased())
                        .font(KFont.mono(9)).tracking(1.5)
                }
                .foregroundStyle(correct ? accent : Theme.muted)
                Text(explanation)
                    .font(KFont.mono(12))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kPanel(12)
            .opacity(isRevealed ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isRevealed)
        }
    }

    /// Always reserves a full button's height so the answers above stay anchored
    /// across phases. During a question there is no action button: the only way
    /// out is the X (top right). After answering, "Suivant" / "Voir le score"
    /// lets the player read the reveal at their own pace, then advance.
    @ViewBuilder private var footer: some View {
        Group {
            switch game.phase {
            case .revealed(let outcome) where !game.isContreLaMontre && game.revealVisible:
                PixelButton(title: outcome.endsGame ? "Voir le score" : "Suivant") { game.next() }
            default:
                PixelButton(title: "Suivant") {}.opacity(0).allowsHitTesting(false)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Helpers

    private var isPlaying: Bool {
        if case .playing = game.phase { return true }
        return false
    }

    /// Vrai seulement une fois la correction affichée : entre le tap et la
    /// révélation, l'explication et le bouton « Suivant » restent cachés.
    private var isRevealed: Bool {
        if case .revealed = game.phase { return game.revealVisible }
        return false
    }

    private var revealedWasCorrect: Bool {
        if case .revealed(let outcome) = game.phase { return outcome.wasCorrect }
        return false
    }

    private func letter(_ i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return i < letters.count ? letters[i] : "?"
    }

    private var progressText: String {
        let n = game.session.questionNumber
        if let qc = game.session.mode.questionCount {
            return String(format: "QUESTION %02d/%02d", n, qc)
        }
        return String(format: "QUESTION %02d", n)
    }

    private func answerState(_ idx: Int, correctIndex: Int) -> AnswerRow.State {
        if case .revealed = game.phase {
            // Temps 1 : seul le choix du joueur s'allume, en blanc, sans verdict.
            guard game.revealVisible else {
                return idx == game.selectedIndex ? .selected : .dim
            }
            // Temps 2 : la correction tombe (vert / rouge).
            if idx == correctIndex { return .correct }
            if idx == game.selectedIndex { return .wrong }
            return .dim
        }
        return .idle
    }
}

struct TimerBar: View {
    let fraction: Double
    @Environment(\.accent) private var accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(hex: "#0c0c0c"))
                Rectangle()
                    .fill(fraction < 0.25 ? Theme.bad : accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }
}

struct AnswerRow: View {
    /// `selected` = le joueur a tapé cette case, la correction n'est pas encore
    /// affichée : elle s'allume en blanc, neutre, avant de virer au vert / rouge.
    enum State: Equatable { case idle, selected, correct, wrong, dim }

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
            .overlay(Rectangle().stroke(borderColor, lineWidth: state == .selected ? 2 : 1))
            .opacity(state == .dim ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: state)
    }

    private var borderColor: Color {
        switch state {
        case .correct: accent
        case .wrong: Theme.bad
        case .selected: Theme.text
        default: Theme.border
        }
    }
    private var textColor: Color {
        switch state {
        case .correct: accent
        case .wrong: Theme.bad
        default: Theme.text
        }
    }
    private var keyColor: Color {
        switch state {
        case .correct: accent
        case .wrong: Theme.bad
        case .selected: Theme.text
        default: Theme.muted
        }
    }
}
