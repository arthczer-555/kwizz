#if canImport(Supabase)
import Foundation
import Supabase

/// The real `DuelTransport`, backed by Supabase Realtime (Broadcast + Presence) on
/// a channel named `room:<CODE>`. Events and the presence payload are carried as
/// base64-encoded JSON so the bridge is robust to the exact `AnyJSON` shape.
///
/// This file only compiles once the `supabase-swift` SPM package is added (it is
/// gated by `#if canImport(Supabase)`), so the rest of the app builds and runs on
/// the mock transport until then. When you add the package, verify the three
/// SDK-specific spots against your installed version (they target supabase-swift
/// v2.x): `broadcastStream`, `presenceChange`, and `channel.track(state:)`.
@MainActor
final class SupabaseRealtimeTransport: DuelTransport {
    let roomCode: String
    var onEvent: ((DuelEvent) -> Void)?
    var onPresence: (([DuelPlayer]) -> Void)?
    var onError: ((String) -> Void)?

    private static let broadcastEvent = "duel"

    private let client: SupabaseClient
    private let channel: RealtimeChannelV2
    private var listeners: [Task<Void, Never>] = []
    private var roster: [String: DuelPlayer] = [:]   // presence key : player

    init(config: SupabaseConfig, roomCode: String) {
        self.roomCode = roomCode
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        self.channel = client.channel("room:\(roomCode)")
    }

    func connect(as player: DuelPlayer) async throws {
        // 1) Broadcast: decode events coming from the other clients.
        let broadcasts = channel.broadcastStream(event: Self.broadcastEvent)
        listeners.append(Task { [weak self] in
            for await message in broadcasts {
                guard let self else { return }
                // The SDK delivers the full broadcast envelope, so our payload sits
                // one level down under "payload" (not at the top level).
                if let b64 = message["payload"]?.objectValue?["b64"]?.stringValue,
                   let event = Self.decode(b64, as: DuelEvent.self) {
                    self.onEvent?(event)
                }
            }
        })

        // 2) Presence: rebuild the roster on every join/leave.
        let presence = channel.presenceChange()
        listeners.append(Task { [weak self] in
            for await change in presence {
                guard let self else { return }
                for key in change.leaves.keys { self.roster[key] = nil }
                for (key, state) in change.joins {
                    if let b64 = state.state["b64"]?.stringValue, let p = Self.decode(b64, as: DuelPlayer.self) {
                        self.roster[key] = p
                    }
                }
                self.onPresence?(Array(self.roster.values))
            }
        })

        await channel.subscribe()
        try await channel.track(state: ["b64": .string(Self.encode(player))])
    }

    func updatePresence(_ player: DuelPlayer) async {
        try? await channel.track(state: ["b64": .string(Self.encode(player))])
    }

    func send(_ event: DuelEvent) async {
        do {
            try await channel.broadcast(event: Self.broadcastEvent, message: ["b64": .string(Self.encode(event))])
        } catch {
            onError?("Envoi impossible")
        }
    }

    func disconnect() async {
        listeners.forEach { $0.cancel() }
        listeners.removeAll()
        await channel.unsubscribe()
    }

    // MARK: base64-JSON bridging

    private static func encode<T: Encodable>(_ value: T) -> String {
        (try? JSONEncoder().encode(value))?.base64EncodedString() ?? ""
    }

    private static func decode<T: Decodable>(_ b64: String, as type: T.Type) -> T? {
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
#endif
