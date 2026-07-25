/// The full deterministic world state advanced by `RunSim`. Reference-space
/// (points); the render layer maps it to the device viewport. Everything that
/// affects outcomes lives here so it can be fingerprinted and replayed.
public struct RunState: Sendable {
    /// The Pilgrim. Positions are in reference space; `+y` is downward, so the
    /// fog (large y) is "below" and climbing means smaller y / growing worldY.
    public struct Hero: Equatable, Sendable {
        public var pos: Vec2
        /// The drag target the Pilgrim eases toward (offset-follow, R1).
        public var target: Vec2
        /// Knockback velocity (shoves in U3); decays exponentially.
        public var vel: Vec2
        /// Remaining invulnerability, seconds.
        public var invuln: Double
        /// Time spent inside the fog this dip, seconds (grace/grip in U4).
        public var fogTime: Double
    }

    /// Reference viewport, pinned per run; graybox formulas use it directly.
    public let width: Double
    public let height: Double

    /// Elapsed sim time, seconds.
    public var time: Double = 0
    /// Camera offset — grows at the effective scroll rate (px). `fathoms` is the
    /// player-facing distance; a fathom is 10 reference points (graybox `/10`).
    public var worldY: Double = 0
    public var hero: Hero

    /// Drag anchor: pointer + hero-target at touch-down (offset follow).
    var anchor: (pointer: Vec2, heroTarget: Vec2)?
    /// Injected PRNG (KTD-1).
    var rng: SeededRandom

    public init(width: Double, height: Double, seed: UInt64) {
        self.width = width
        self.height = height
        let start = Vec2(width / 2, height * 0.42) // graybox hero spawn
        self.hero = Hero(pos: start, target: start, vel: .zero, invuln: 0, fogTime: 0)
        self.anchor = nil
        self.rng = SeededRandom(seed: seed)
    }

    /// Player-facing distance climbed (graybox `fathoms`).
    public var fathoms: Double { worldY / 10 }

    /// A bit-deterministic hash of the full state, stable across processes —
    /// the basis of the U2 seed-replay keystone test.
    public var fingerprint: UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325 // FNV-1a offset basis
        func mix(_ bits: UInt64) { h = (h ^ bits) &* 0x0000_0100_0000_01B3 }
        func mix(_ d: Double) { mix(d.bitPattern) }
        mix(time); mix(worldY)
        mix(hero.pos.x); mix(hero.pos.y)
        mix(hero.target.x); mix(hero.target.y)
        mix(hero.vel.x); mix(hero.vel.y)
        mix(hero.invuln); mix(hero.fogTime)
        mix(rng.state)
        return h
    }
}
