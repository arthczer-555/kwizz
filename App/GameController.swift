import SwiftUI
import Observation
import UIKit

enum Haptics {
    @MainActor static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    @MainActor static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// Drives a single game: it owns the pure `QuizSession`, the real-time countdown
/// (a single async task per question, with the bar animated by SwiftUI so no
/// per-frame state churn), the duel bot, and the transition to the results.
@MainActor
@Observable
final class GameController: Identifiable {
    nonisolated let id = UUID()

    enum Phase {
        case playing
        case revealed(AnswerOutcome)
        case results(GameResult)
    }

    private(set) var session: QuizSession
    let store: PlayerStore

    var phase: Phase = .playing
    var selectedIndex: Int?
    /// Per-question countdown, 1 -> 0, animated by SwiftUI.
    var barFraction: Double = 1
    /// Global countdown for contre-la-montre, 1 -> 0.
    var globalFraction: Double = 1
    var appliedResult: AppliedResult?
    /// Per-question choices for the Défi du jour, captured to validate the score
    /// server-side (the monthly leaderboard). Only filled in `.defi` mode.
    private(set) var defiAnswers: [SupabaseService.DailyAnswer] = []

    private var questionStart = Date()
    private var deadlineTask: Task<Void, Never>?
    private var globalTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var hasStarted = false
    let duelBotScore: Int

    init(session: QuizSession, store: PlayerStore) {
        self.session = session
        self.store = store
        let n = session.mode.questionCount ?? 7
        self.duelBotScore = Int((Double(n) * 0.6).rounded()) * 150
    }

    // MARK: Derived

    var timeLimit: Double { GameMode.timePerQuestion }
    var usesPerQuestionTimer: Bool { session.mode.hasPerQuestionTimer }
    var isContreLaMontre: Bool { session.mode == .contreLaMontre }
    var isTraining: Bool { session.mode.isTraining }
    var current: Question? { session.current }

    // MARK: Flow

    /// Kicked off from the view's `onAppear`, not from `init`: the timer-bar
    /// animations only animate when started inside an active view update, so
    /// starting in `init` left the very first question with an already-empty bar.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        begin()
    }

    private func begin() {
        if let global = session.mode.globalTime { startGlobalTimer(global) }
        beginQuestion()
    }

    private func beginQuestion() {
        selectedIndex = nil
        phase = .playing
        questionStart = Date()
        deadlineTask?.cancel()
        barFraction = 1
        guard usesPerQuestionTimer else { return }
        withAnimation(.linear(duration: timeLimit)) { barFraction = 0 }
        let limit = timeLimit
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(limit))
            guard let self, !Task.isCancelled else { return }
            if case .playing = self.phase { self.answer(nil) }
        }
    }

    func remainingFraction() -> Double {
        guard usesPerQuestionTimer else { return 0 }
        let elapsed = Date().timeIntervalSince(questionStart)
        return max(0, min(1, (timeLimit - elapsed) / timeLimit))
    }

    func answer(_ index: Int?) {
        guard case .playing = phase else { return }
        deadlineTask?.cancel()
        let remaining = remainingFraction()
        selectedIndex = index
        if usesPerQuestionTimer {
            var freeze = Transaction()
            freeze.disablesAnimations = true
            withTransaction(freeze) { barFraction = remaining }
        }
        if session.mode == .defi, let q = session.current {
            let choice = index.flatMap { q.answers.indices.contains($0) ? q.answers[$0] : nil }
            defiAnswers.append(.init(id: q.id, choice: choice))
        }
        let outcome = session.submit(answerIndex: index, remainingFraction: remaining)
        Haptics.impact(outcome.wasCorrect ? .light : .rigid)
        phase = .revealed(outcome)

        // Contre-la-montre keeps a fast rhythm: reveal briefly, then auto-advance.
        if isContreLaMontre {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.4))
                guard let self, !Task.isCancelled else { return }
                self.next()
            }
        }
    }

    func next() {
        guard case .revealed(let outcome) = phase else { return }
        if outcome.endsGame { finishGame(); return }
        session.advance()
        if session.isOver { finishGame() } else { beginQuestion() }
    }

    private func startGlobalTimer(_ seconds: Double) {
        globalFraction = 1
        withAnimation(.linear(duration: seconds)) { globalFraction = 0 }
        globalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.finishGame()
        }
    }

    private func finishGame() {
        deadlineTask?.cancel()
        globalTask?.cancel()
        autoAdvanceTask?.cancel()
        if case .results = phase { return }
        let prev = store.profile.bestScore(mode: session.mode, categoryID: session.categoryID, difficulty: session.difficulty)
        let duelWon: Bool? = session.mode == .duel ? (session.score >= duelBotScore) : nil
        let result = session.makeResult(previousBest: prev, duelWon: duelWon)
        appliedResult = store.finish(result: result)
        if session.mode == .defi {
            let day = store.today()
            let answers = defiAnswers
            Task { await SupabaseService.shared.submitDaily(dayIndex: day, answers: answers) }
        }
        if let applied = appliedResult, applied.newRecord || !applied.leveledUpTo.isEmpty {
            Haptics.notify(.success)
        }
        phase = .results(result)
    }
}
