import SwiftUI
import Observation

enum Route: Hashable {
    case modeSelect
    case category(GameMode)
    case subcategory(GameMode, Category)
    case difficulty(GameMode, Category?, Subcategory?)
    case defiIntro
    case dailyWheel
    case chestOpen
    case shopItem(String)
    case avatar
    case achievements
    case settings
    case admin
    case duelEntry
    case rankedLeaderboard
}

@MainActor
@Observable
final class Router {
    enum Tab: Hashable { case home, play, shop, rank, profile }

    var tab: Tab = .home
    /// Navigation stack for the "Jouer" tab. Reset to root whenever the tab is
    /// (re)selected so "Jouer" always lands on mode selection.
    var playPath = NavigationPath()
    var activeGame: GameController?
    /// The current online duel (lobby + room), if any.
    var activeDuel: DuelController?
    /// The current ranked 1v1 match (matchmaking + match), if any.
    var activeRanked: RankedController?
    /// Rang tab segment: 0 = Ligue 1v1, 1 = Mensuel. Lets other screens deep-link.
    var rankSegment = 0

    private let store: PlayerStore
    init(store: PlayerStore) { self.store = store }

    // MARK: Online duel

    /// Creates a room as the host and connects. The lobby reads `activeDuel`.
    func createDuel() {
        let duel = DuelController(store: store, router: self, role: .host, roomCode: RoomCode.generate())
        activeDuel = duel
        duel.connect()
    }

    /// Joins a room by code as a guest and connects.
    func joinDuel(code: String) {
        let duel = DuelController(store: store, router: self, role: .guest, roomCode: RoomCode.normalize(code))
        activeDuel = duel
        duel.connect()
    }

    // MARK: Ranked 1v1 league

    /// Starts matchmaking; `RankedRoomView` (pushed from the Rang tab) reads `activeRanked`.
    func startRanked() {
        let ranked = RankedController(store: store, router: self)
        activeRanked = ranked
        ranked.startSearch()
    }

    /// Quit while searching or mid-match (a live match counts as a forfeit).
    func quitRanked() {
        activeRanked?.forfeit()
        activeRanked = nil
    }

    /// Leave a finished match (no forfeit).
    func endRanked() {
        activeRanked?.cleanup()
        activeRanked = nil
    }

    /// Deep-link from anywhere (e.g. the Jouer tab) into ranked matchmaking: jump to
    /// the Rang tab's "Ligue 1v1" segment and start searching.
    func openRanked() {
        rankSegment = 0
        tab = .rank
        startRanked()
    }

    /// Deep-link to the monthly daily-challenge leaderboard (Rang tab, "Mensuel").
    func showMonthlyLeaderboard() {
        rankSegment = 1
        tab = .rank
    }

    /// `difficulty` is nil when the player picked "toutes les difficultés" (Entraînement).
    func startGame(mode: GameMode, category: Category?, subcategory: Subcategory?, difficulty: Difficulty?) {
        let session = store.makeSession(mode: mode, category: category, subcategory: subcategory, difficulty: difficulty)
        // `fullScreenCover(item:)` only (re)presents on a nil <-> non-nil change, so
        // when replaying (a game is already active) we must pass through nil first.
        if activeGame == nil {
            activeGame = GameController(session: session, store: store)
        } else {
            activeGame = nil
            Task { @MainActor in
                self.activeGame = GameController(session: session, store: self.store)
            }
        }
    }

    func endGame() { activeGame = nil }

    /// Switches to the "Jouer" tab at its root (mode selection), discarding any
    /// previous navigation so "Jouer" always lands on the mode choice.
    func goToPlay() {
        playPath = NavigationPath()
        tab = .play
    }

    func goHome() {
        activeDuel?.leave()
        activeDuel = nil
        activeRanked?.forfeit()
        activeRanked = nil
        activeGame = nil
        tab = .home
    }
}
