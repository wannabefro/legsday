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

    /// A splash scheduled to hit the fog surface after a felled foe's corpse
    /// falls (KTD-3 — sim-born, never read back from the render layer).
    struct PendingSplash: Equatable, Sendable {
        var dueTime: Double
        var xFraction: Double
        var magnitude: Double
    }

    /// Live foes (append on spawn, remove on death/cull — stable order).
    public internal(set) var foes: [Foe] = []
    /// Foes felled this run (graybox `kills`).
    public internal(set) var kills: Int = 0
    /// Total foes spawned this run — monotonic (spawn-rate testing).
    public internal(set) var spawnedCount: Int = 0
    /// Runtime modifiers (card effects mutate these in U6).
    public internal(set) var mods = Mods()

    /// Fog pressure — the ramping term that raises the fog line (graybox
    /// `fogPressure`). Kills push it back.
    public internal(set) var fogPressure: Double = 0
    /// Whether the hero is currently within the fog (below the fog line).
    public internal(set) var heroInFog: Bool = false
    /// Whether the fog's grip has taken hold (past the grace window).
    public internal(set) var heroGripped: Bool = false
    /// Run over — the fog's grip completed.
    public internal(set) var dead: Bool = false
    /// The rippling fog surface (read-only feedback; rest line decides death).
    public internal(set) var fogSurface: SpringLine

    /// Splashes queued from felled corpses, fired when their fall completes.
    var pendingSplashes: [PendingSplash] = []
    /// Transient render hints produced this tick (bolts, hits, kills). Not
    /// persistent state and excluded from `fingerprint`; consumed by the render
    /// layer after each tick and cleared at the next tick's start.
    public internal(set) var frameEvents: [FrameEvent] = []

    /// Fractional spawn accumulator (graybox `spawnAcc`).
    var spawnAcc: Double = 0
    /// Auto-attack cooldown timer (graybox `atkT`).
    var attackTimer: Double = 0
    /// Monotonic foe id source (stable identity for render pooling).
    var nextFoeId: Int = 0

    /// Drag anchor: pointer + hero-target at touch-down (offset follow).
    var anchor: (pointer: Vec2, heroTarget: Vec2)?
    /// Injected PRNG (KTD-1).
    var rng: SeededRandom

    public init(width: Double, height: Double, seed: UInt64) {
        self.width = width
        self.height = height
        let start = Vec2(width / 2, height * 0.42) // graybox hero spawn
        self.hero = Hero(pos: start, target: start, vel: .zero, invuln: 0, fogTime: 0)
        self.fogSurface = SpringLine(nodeCount: 48)
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
        mix(UInt64(bitPattern: Int64(kills)))
        mix(UInt64(bitPattern: Int64(spawnedCount)))
        mix(spawnAcc); mix(attackTimer)
        mix(fogPressure); mix(UInt64(dead ? 1 : 0))
        for v in fogSurface.heights { mix(v) }
        for v in fogSurface.velocities { mix(v) }
        for f in foes {
            mix(UInt64(bitPattern: Int64(f.id)))
            mix(f.pos.x); mix(f.pos.y); mix(f.radius); mix(f.speed)
            mix(UInt64(bitPattern: Int64(f.hp)))
            mix(UInt64(f.elite ? 1 : 0))
        }
        mix(rng.state)
        return h
    }
}
