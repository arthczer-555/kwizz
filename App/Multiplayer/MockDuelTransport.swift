import Foundation

/// An in-memory `DuelTransport` with no backend: a couple of simulated opponents
/// join the lobby, then answer each question after a believable delay once the host
/// opens it. Lets the whole synchronised flow (lobby → live → reveal → podium) be
/// exercised in the simulator before Supabase is wired up.
///
/// It models the host/create flow (the local player is the host); the bots are the
/// guests that react to the host's `beginQuestion` broadcasts.
@MainActor
final class MockDuelTransport: DuelTransport {
    let roomCode: String
    var onEvent: ((DuelEvent) -> Void)?
    var onPresence: (([DuelPlayer]) -> Void)?
    var onError: ((String) -> Void)?

    private var localPlayer: DuelPlayer?
    private let bots: [DuelPlayer] = [
        DuelPlayer(clientID: "bot-lea", pseudo: "Léa", accentHex: "#38d6ff"),
        DuelPlayer(clientID: "bot-max", pseudo: "Max", accentHex: "#ffb000"),
    ]
    private var joined: Set<String> = []
    private var questions: [Question] = []
    private var tasks: [Task<Void, Never>] = []

    init(roomCode: String) { self.roomCode = roomCode }

    func connect(as player: DuelPlayer) async throws {
        localPlayer = player
        emitPresence()
        for (i, bot) in bots.enumerated() {
            schedule(after: .seconds(Double(i) + 1.0)) { [weak self] in
                guard let self else { return }
                self.joined.insert(bot.clientID)
                self.emitPresence()
                self.onEvent?(.hello(player: bot))
            }
        }
    }

    func updatePresence(_ player: DuelPlayer) async {
        localPlayer = player
        emitPresence()
    }

    func send(_ event: DuelEvent) async {
        switch event {
        case .start(let questions, _):
            self.questions = questions
        case .beginQuestion(let index):
            for bot in bots where joined.contains(bot.clientID) {
                scheduleBotAnswer(bot: bot, index: index)
            }
        default:
            break
        }
    }

    func disconnect() async {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    // MARK: Simulation

    private func emitPresence() {
        guard let local = localPlayer else { return }
        onPresence?([local] + bots.filter { joined.contains($0.clientID) })
    }

    /// A bot answers after a short delay (well under the 15 s window), correct ~65%
    /// of the time, with `elapsedMs` matching its delay so the "fastest" logic works.
    private func scheduleBotAnswer(bot: DuelPlayer, index: Int) {
        let task = Task { [weak self] in
            let delay = Double.random(in: 0.8...4.0)
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            let correct = Double.random(in: 0...1) < 0.65
            let answerIndex = self.botAnswerIndex(index: index, correct: correct)
            let answer = DuelAnswer(answerIndex: answerIndex, correct: correct, elapsedMs: Int(delay * 1000))
            self.onEvent?(.answer(clientID: bot.clientID, index: index, answer: answer))
        }
        tasks.append(task)
    }

    private func botAnswerIndex(index: Int, correct: Bool) -> Int {
        guard questions.indices.contains(index) else { return 0 }
        let q = questions[index]
        if correct { return q.correctIndex }
        let wrong = q.answers.indices.filter { $0 != q.correctIndex }
        return wrong.randomElement() ?? 0
    }

    private func schedule(after delay: Duration, _ work: @escaping @MainActor () -> Void) {
        let task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard self != nil, !Task.isCancelled else { return }
            work()
        }
        tasks.append(task)
    }
}
