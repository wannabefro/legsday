/// Runtime modifiers applied to the run — the live tunable surface that Fate
/// Card effects mutate (U6). Defaults mirror the graybox `mods` seed. Held in
/// `RunState` so they replay deterministically.
public struct Mods: Equatable, Sendable {
    /// Auto-attack bolts fired per volley.
    public var bolts: Int = 1
    /// Seconds between auto-attack volleys (graybox `atk`).
    public var attackCooldown: Double = 0.38
    /// Shove resistance — larger divides the incoming impulse (defense).
    public var footing: Double = 1
    /// Mote magnet radius base (graybox `magnet`).
    public var magnet: Double = 34
    /// Drag sensitivity multiplier (graybox `gain`).
    public var gain: Double = 1
    /// Scroll-rate multiplier.
    public var scrollMul: Double = 1
    /// Essence value multiplier on collection.
    public var essMul: Double = 1
    /// Mote sink-rate multiplier.
    public var moteSink: Double = 1
    /// Spawn-rate multiplier.
    public var spawnMul: Double = 1
    /// Additive fog offset, px (raises the fog line when positive).
    public var fogAdd: Double = 0
    /// Chain-weapon rope length multiplier (U16 growth).
    public var ropeLen: Double = 1
    /// Chain-weapon head-mass multiplier (U16 growth).
    public var ropeMass: Double = 1
    /// Chain-weapon whip-threshold multiplier (U16 growth).
    public var ropeThreshold: Double = 1

    public init() {}
}
