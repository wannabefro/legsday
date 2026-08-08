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
    public internal(set) var gorge: Gorge

    /// Fog ground a kill may still buy back. It refills below the creep rate, so
    /// a dense field slows the fog and never reverses it.
    public internal(set) var pushBudget: Double = RunSim.pushBudgetCap

    /// A splash scheduled to hit the fog surface after a felled foe's corpse
    /// falls (KTD-3 — sim-born, never read back from the render layer).
    struct PendingSplash: Equatable, Sendable {
        var dueTime: Double
        var xFraction: Double
        var magnitude: Double
    }

    /// Live foes (append on spawn, remove on death/cull — stable order).
    public internal(set) var foes: [Foe] = []
    /// Live essence motes.
    public internal(set) var motes: [Mote] = []
    /// Essence banked this run (the currency).
    public internal(set) var essence: Double = 0
    /// Essence charging the next Fate Card (consumed in U6).
    public internal(set) var charge: Double = 0
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
    /// The Pilgrim's lantern (physical feel, R20).
    public internal(set) var lantern = Pendulum()
    /// The Pilgrim's trailing cloak (physical feel, R20).
    public internal(set) var cloak: VerletChain
    /// The chain weapon's verlet rope, once the Wild chain is acquired (U16).
    /// Nil until the weapon's form is chosen; removed if a fusion takes it.
    public internal(set) var rope: ChainRope?
    /// Hero position last step — used to drive the lantern.
    var prevHeroPos: Vec2

    /// The Fate Card currently in play (nil while charging).
    public internal(set) var card: ActiveCard?
    /// The drafted deck — fuel that darkens into Death's deck when spent (R11).
    public internal(set) var deck: [CardDef] = []
    /// Death's deck — dealt (and cycled) once the drafted deck is dry.
    public internal(set) var deathDeck: [CardDef] = []
    /// The deck as built, kept so an early-run exhaustion reshuffles it (R21).
    public internal(set) var deckSource: [CardDef] = []
    /// Weapons acquired this run, keyed by weapon id: form chosen and levels
    /// accrued per growth axis (R13). Empty until the first weapon is claimed.
    public internal(set) var weapons: [String: WeaponState] = [:]
    /// Faction affinity from accepted offers (U12) — empowers that faction's
    /// weapons and (via the draft) thickens its draws.
    public internal(set) var affinity: [Faction: Int] = [:]
    /// Rival threat cards still queued to interleave into the stream (R10),
    /// computed once from the draft's faction weighting at deck build.
    public internal(set) var scheduledThreats: [ThreatInsertion] = []
    /// Fathoms at which the next mandatory fork deals (unit 3).
    public internal(set) var nextForkFathoms: Double = Ascent.forkCadenceFathoms
    /// Forks dealt so far — cycles the fork pool deterministically.
    public internal(set) var forkCount: Int = 0
    /// Current biome, swapped by forks (render palette tag, U13/U24).
    public internal(set) var biome: Biome = .moor
    /// The current Ascent stage, resolved from `fathoms` each step (unit 2).
    public internal(set) var stage: AscentStage = Ascent.stages[0]
    /// Stage ids whose threat card has been shuffled into the deck (unit 5).
    public internal(set) var seededStages: Set<String> = []
    /// A risk-route shrine is pending — the U14 Herald-guardian hook (U13).
    public internal(set) var shrinePending: Bool = false
    /// The living rival champion, if any — anchors the fog while alive (U14).
    public internal(set) var herald: Herald? = nil
    /// Rival-faction offers queued by felled Heralds, dealt ahead of the
    /// cadence (U14) — the only in-run rival-card source.
    public internal(set) var pendingOffers: [CardDef] = []
    /// A fusion recipe whose gate is met, awaiting its FUSION deal (U15).
    public internal(set) var pendingFusion: FusionRecipe? = nil
    /// Recipe keys declined this run — suppressed so they never re-fire (U15).
    public internal(set) var suppressedFusions: [String] = []
    /// Cards drawn this run (graybox `drawn`).
    public internal(set) var drawn: Int = 0
    /// Essence needed to charge the next card; escalates per draw.
    public internal(set) var essNeed: Double = 0
    /// The Finale card has been dealt once (R17).
    public internal(set) var finaleDealt: Bool = false
    /// Keep-running chosen: the scroll ramps forever and only the fog ends the
    /// run (R17).
    public internal(set) var keepRunning: Bool = false
    public internal(set) var keepRunningStartedAt: Double = 0
    /// Turn & fight chosen: U19 enters the duel with the Reaper.
    public internal(set) var duelRequested: Bool = false
    /// The Reaper duel ended in a loss (U19) — result ending `.duelLoss`.
    public internal(set) var deadInDuel: Bool = false
    /// The Reaper duel was won (U19) — result ending `.duelWin`, shards ×3.
    public internal(set) var duelWon: Bool = false
    /// The live duel (U19) — nil until the Finale's "turn & fight" is chosen.
    public internal(set) var duel: DuelState? = nil

    /// Splashes queued from felled corpses, fired when their fall completes.
    var pendingSplashes: [PendingSplash] = []
    /// Active auto-undo timers from `timed` card effects.
    var timedEffects: [TimedEffect] = []
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
    /// Monotonic mote id source.
    var nextMoteId: Int = 0

    /// Drag anchor: pointer + hero-target at touch-down (offset follow).
    var anchor: (pointer: Vec2, heroTarget: Vec2)?
    /// Pointer x at which the current card grab began (tilt anchor); nil when no
    /// touch is driving the card.
    var cardGrabX: Double?
    /// Injected PRNG (KTD-1).
    var rng: SeededRandom

    public init(width: Double, height: Double, seed: UInt64) {
        self.width = width
        self.height = height
        let start = Vec2(width / 2, height * 0.42) // graybox hero spawn
        self.hero = Hero(pos: start, target: start, vel: .zero, invuln: 0, fogTime: 0)
        self.gorge = Gorge(width: width, seed: seed)
        self.fogSurface = SpringLine(nodeCount: 48)
        self.cloak = VerletChain(pin: start)
        self.prevHeroPos = start
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
        mix(essence); mix(charge); mix(essNeed)
        mix(UInt64(bitPattern: Int64(drawn)))
        mix(UInt64(finaleDealt ? 1 : 0))
        mix(UInt64(keepRunning ? 1 : 0))
        mix(keepRunningStartedAt)
        mix(UInt64(duelRequested ? 1 : 0))
        mix(UInt64(deadInDuel ? 1 : 0))
        mix(UInt64(duelWon ? 1 : 0))
        if let duel {
            mix(UInt64(bitPattern: Int64(duel.phase)))
            mix(UInt64(bitPattern: Int64(duel.hits)))
            mix(duel.reaperPos.x); mix(duel.reaperPos.y)
            mix(duel.telegraphTimer)
            mix(UInt64(duel.telegraph == nil ? 0 : 1))
        }
        mix(UInt64(bitPattern: Int64(deck.count)))
        mix(UInt64(bitPattern: Int64(deathDeck.count)))
        if let c = card {
            mix(c.offset); mix(c.rise); mix(c.tilt); mix(c.tiltVel); mix(Double(c.dir))
            mix(UInt64(c.committing ? 1 : 0))
            mix(UInt64(c.deathDealt ? 1 : 0))
            mix(c.holdTime); mix(UInt64(c.signatureArmed ? 1 : 0))
        }
        if let g = cardGrabX { mix(g) }
        for key in weapons.keys.sorted() { // sorted → stable across processes
            let w = weapons[key]!
            mix(UInt64(w.owned ? 1 : 0))
            mix(UInt64(bitPattern: Int64(w.form ?? -1)))
            for l in w.levels { mix(UInt64(bitPattern: Int64(l))) }
        }
        for f in Faction.allCases { mix(UInt64(bitPattern: Int64(affinity[f] ?? 0))) }
        for t in scheduledThreats { mix(UInt64(bitPattern: Int64(t.atDraw))) }
        mix(nextForkFathoms); mix(UInt64(bitPattern: Int64(forkCount)))
        mix(UInt64(bitPattern: Int64(Biome.allCases.firstIndex(of: biome) ?? 0)))
        mix(UInt64(Ascent.stages.firstIndex(of: stage) ?? 0))
        for id in seededStages.sorted() {
            for b in id.utf8 { mix(UInt64(b)) }
            mix(UInt64(0xFF)) // separator
        }
        mix(UInt64(shrinePending ? 1 : 0))
        if let h = herald {
            mix(UInt64(bitPattern: Int64(Faction.allCases.firstIndex(of: h.faction) ?? 0)))
            mix(h.pos.x); mix(h.pos.y); mix(UInt64(bitPattern: Int64(h.hp)))
            mix(h.slamTimer); mix(UInt64(h.guardian ? 1 : 0))
        }
        mix(UInt64(bitPattern: Int64(pendingOffers.count)))
        mix(UInt64(pendingFusion == nil ? 0 : 1))
        mix(UInt64(bitPattern: Int64(suppressedFusions.count)))
        for te in timedEffects { mix(te.until) }
        for m in motes {
            mix(UInt64(bitPattern: Int64(m.id)))
            mix(m.pos.x); mix(m.pos.y); mix(m.value)
        }
        for v in fogSurface.heights { mix(v) }
        for v in fogSurface.velocities { mix(v) }
        mix(lantern.angle); mix(lantern.angularVel)
        for p in cloak.points { mix(p.x); mix(p.y) }
        if let rope {
            for p in rope.points { mix(p.x); mix(p.y) }
            mix(rope.headSpeed)
        }
        for f in foes {
            mix(UInt64(bitPattern: Int64(f.id)))
            mix(f.pos.x); mix(f.pos.y); mix(f.radius); mix(f.speed)
            mix(UInt64(bitPattern: Int64(f.hp)))
            mix(f.whipAcc)
            mix(UInt64(f.elite ? 1 : 0))
        }
        mix(rng.state)
        mix(gorge.fingerprint)
        mix(pushBudget.bitPattern)
        return h
    }
}
