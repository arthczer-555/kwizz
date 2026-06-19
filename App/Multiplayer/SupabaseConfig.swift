import Foundation

/// Supabase connection details for the online duel, read from the app's Info.plist
/// keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Populate those via a `.xcconfig`
/// (see docs/PLAN_MULTIJOUEUR.md) so the anon key is never hard-coded in source.
///
/// Returns `nil` when the keys are absent or empty, which makes the app fall back
/// to `MockDuelTransport` (the demo opponents) instead of crashing.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static var current: SupabaseConfig? {
        guard
            let rawURL = info("SUPABASE_URL"), !rawURL.isEmpty,
            let key = info("SUPABASE_ANON_KEY"), !key.isEmpty
        else { return nil }
        let normalized = rawURL.hasPrefix("http") ? rawURL : "https://\(rawURL)"
        guard let url = URL(string: normalized) else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }

    private static func info(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
