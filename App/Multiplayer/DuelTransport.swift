import Foundation

/// Abstracts the realtime backend behind the duel so the controller and the UI
/// never import a networking SDK directly. Two implementations exist:
///
/// - `MockDuelTransport` drives the whole flow (lobby, live scores, podium) with
///   simulated opponents and no backend, so the feature is testable today.
/// - `SupabaseRealtimeTransport` is the real one, compiled in automatically once the
///   `supabase-swift` SPM package is added (gated behind `#if canImport(Supabase)`).
///
/// It is callback-based on purpose: it slots cleanly into the `@Observable`,
/// `@MainActor` controller without bridging `AsyncStream`s.
@MainActor
protocol DuelTransport: AnyObject {
    var roomCode: String { get }

    /// A decoded event from another client on the channel.
    var onEvent: ((DuelEvent) -> Void)? { get set }
    /// The current presence roster (everyone in the room, including this device).
    var onPresence: (([DuelPlayer]) -> Void)? { get set }
    /// The channel dropped or failed to connect; the payload is a user-facing reason.
    var onError: ((String) -> Void)? { get set }

    /// Joins the room channel and announces `player` via presence.
    func connect(as player: DuelPlayer) async throws
    /// Re-publishes this device's presence (e.g. after the pseudo changes).
    func updatePresence(_ player: DuelPlayer) async
    /// Broadcasts an event to the other clients.
    func send(_ event: DuelEvent) async
    /// Leaves the channel.
    func disconnect() async
}

/// Picks the real Supabase transport when the SDK is present and configured,
/// otherwise the in-memory mock. This is the single switch between "online" and
/// "demo" modes; nothing else in the app needs to know which is active.
@MainActor
enum DuelTransportFactory {
    static func make(roomCode: String) -> DuelTransport {
        #if canImport(Supabase)
        if let config = SupabaseConfig.current {
            return SupabaseRealtimeTransport(config: config, roomCode: roomCode)
        }
        #endif
        return MockDuelTransport(roomCode: roomCode)
    }

    /// Whether a real backend is wired up. The UI uses this to show a small
    /// "mode démo" hint when running on the mock.
    static var isLive: Bool {
        #if canImport(Supabase)
        return SupabaseConfig.current != nil
        #else
        return false
        #endif
    }
}
