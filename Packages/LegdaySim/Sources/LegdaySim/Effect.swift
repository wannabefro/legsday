/// A `Mods` field a card effect can scale or offset. `bolts` is integer-only
/// (see `Effect.addBolts`) and so is excluded here.
public enum ModField: String, Equatable, Sendable, Codable {
    case attackCooldown, footing, magnet, gain, scrollMul, essMul, moteSink, spawnMul, fogAdd
    case ropeLen, ropeMass, ropeThreshold
}

/// A Fate Card consequence, modeled as data (not a closure) so U10 can move
/// definitions into bundled JSON unchanged. The interpreter lives on `RunSim`.
public indirect enum Effect: Equatable, Sendable, Codable {
    /// field *= factor
    case multiply(ModField, Double)
    /// field += amount
    case add(ModField, Double)
    /// bolts += n (integer)
    case addBolts(Int)
    /// charge += amount (advances the next card)
    case addCharge(Double)
    /// essence = floor(essence * factor) — a height cost
    case scaleEssence(Double)
    /// smite every foe on screen
    case smiteAllFoes
    /// apply `base` now, auto-undo its inverse after `seconds` of sim time
    case timed(Effect, seconds: Double)
}

/// A scheduled auto-undo of a timed effect (graybox `effects`).
public struct TimedEffect: Equatable, Sendable {
    var undo: Effect
    var until: Double
}
