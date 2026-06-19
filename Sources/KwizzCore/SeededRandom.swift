import Foundation

/// A small, fast, fully deterministic PRNG (SplitMix64). Used so the Daily
/// Challenge produces the same grid for everyone on a given day, and so seeded
/// sampling is reproducible in tests.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // Avoid a zero state producing a weak stream.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
