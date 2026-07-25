/// Seedable, deterministic PRNG (SplitMix64). Injected into the sim so every
/// random draw is reproducible from the run seed — no `Math.random()`, no
/// wall-clock (KTD-1). Conforms to `RandomNumberGenerator` so the standard
/// `random(in:using:)` helpers work.
public struct SeededRandom: RandomNumberGenerator, Equatable, Sendable {
    /// Internal generator state — part of the sim's fingerprint so same-seed
    /// runs that consume identical draws stay in lockstep.
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A double in [0, 1), the deterministic analogue of `Math.random()`.
    public mutating func unit() -> Double {
        // 53-bit mantissa for a uniform double in [0, 1).
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// A double in [a, b).
    public mutating func range(_ a: Double, _ b: Double) -> Double {
        a + unit() * (b - a)
    }
}
