import Foundation

/// A short, human-friendly code used to join an online duel room (e.g. "K7QX9").
/// Five characters drawn from an unambiguous alphabet (no O/0, I/1, L), so it is
/// easy to read out loud and type. Generation is deterministic given a generator,
/// which keeps it testable; pass a `SeededGenerator` in tests.
public enum RoomCode {
    /// Uppercase letters and digits with the visually ambiguous ones removed
    /// (no I, L, O, and no 0, 1). 31 symbols → 31^5 ≈ 28.6M combinations.
    public static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    public static let length = 5

    /// Generates a code using the provided generator. Pass a `SeededGenerator`
    /// for reproducible codes in tests, or use `generate()` for the system RNG.
    public static func generate<G: RandomNumberGenerator>(using generator: inout G) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    /// Generates a code from the system RNG.
    public static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    /// Cleans user input: trims, uppercases, and keeps only alphabet characters.
    /// Because the alphabet already avoids look-alikes, a correctly read code never
    /// contains an ambiguous character; any stray one is simply dropped.
    public static func normalize(_ raw: String) -> String {
        let upper = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return String(upper.filter { alphabet.contains($0) })
    }

    /// Whether `code` is a well-formed room code (right length, valid alphabet).
    public static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }
}
