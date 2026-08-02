import Foundation

/// The Reaper's placeholder pattern kit (R17/U19). Telegraphs render ahead of
/// each pattern (U23); the sim carries only the tag.
public enum ReaperPattern: String, Equatable, Sendable {
    case sweep, slam, fogSurge
}

/// The duel arena: a fixed band above the fog floor; the fog still kills.
public struct Arena: Equatable, Sendable {    public var minX: Double
    public var maxX: Double
    public var minY: Double
    public var maxY: Double

    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }
}

/// The live duel state (R17/U19). No HP bar — accumulated hits drive phases.
public struct DuelState: Equatable, Sendable {
    /// Current phase (1…3), the "set" of patterns on offer.
    public var phase: Int
    /// Hits landed on the Reaper this phase — crosses a threshold → next phase.
    public var hits: Int
    /// The pattern currently winding up (nil while idle between telegraphs).
    public var telegraph: ReaperPattern?
    /// Seconds until the telegraphed pattern fires.
    public var telegraphTimer: Double
    public var reaperPos: Vec2
    public let arena: Arena

    public init(phase: Int = 1, hits: Int = 0, telegraph: ReaperPattern? = nil,
                telegraphTimer: Double = 0, reaperPos: Vec2, arena: Arena) {
        self.phase = phase
        self.hits = hits
        self.telegraph = telegraph
        self.telegraphTimer = telegraphTimer
        self.reaperPos = reaperPos
        self.arena = arena
    }
}

/// Duel tuning (R17). Placeholder kit and thresholds by design.
public enum Reaper {
    /// Hits to complete each phase: phase 1 ends at 4 hits, 2 at 8, win at 12.
    public static let phaseThresholds = [4, 8, 12]
    public static let patternInterval: Double = 2.2
    public static let telegraphTime: Double = 0.8
    public static let sweepImpulse: Double = 90
    public static let slamImpulse: Double = 140
    public static let fogSurgeAmount: Double = 44
    public static let fogSurgeSeconds: Double = 3
    public static let reaperSpeed: Double = 60
}

extension RunSim {
    /// The arena band for the duel (U19). The floor sits above the static fog
    /// line so the hero isn't clamped into it — only a slam can push it down.
    func duelArena() -> Arena {
        Arena(minX: 30, maxX: state.width - 30,
              minY: state.height * 0.35, maxY: state.height - 160)
    }

    /// Enter the duel on "turn & fight": scroll halts and the arena fixes.
    /// The only path that zeroes scroll.
    mutating func maybeEnterDuel() {
        guard state.duelRequested, state.duel == nil else { return }
        let arena = duelArena()
        state.duel = DuelState(
            reaperPos: Vec2(state.width / 2, arena.maxY - 40), arena: arena)
        state.hero.pos = Vec2(min(max(state.hero.pos.x, arena.minX), arena.maxX),
                              min(max(state.hero.pos.y, arena.minY), arena.maxY))
        state.hero.target = state.hero.pos
        state.frameEvents.append(.heroShoved(at: state.hero.pos))
    }

    /// Advance the duel: the Reaper drifts, telegraphs patterns, and hits
    /// advance phases until the final phase is won.
    mutating func updateDuel(dt: Double) {
        guard state.duel != nil else { return }

        // Clamp the hero to the arena (the fog is the floor, still lethal).
        if let a = state.duel?.arena {
            state.hero.pos = Vec2(min(max(state.hero.pos.x, a.minX), a.maxX),
                                  min(max(state.hero.pos.y, a.minY), a.maxY))
            state.hero.target = state.hero.pos
        }

        guard var d = state.duel else { return }
        // The Reaper drifts toward the hero's x, holding at the arena's top.
        let targetX = min(max(state.hero.pos.x, d.arena.minX + 40), d.arena.maxX - 40)
        let dx = targetX - d.reaperPos.x
        let step = min(abs(dx), Reaper.reaperSpeed * dt)
        d.reaperPos.x += dx >= 0 ? step : -step

        // Telegraph cadence: idle → wind up → fire.
        if d.telegraph == nil {
            d.telegraphTimer -= dt
            if d.telegraphTimer <= 0 {
                d.telegraph = nextPattern(for: d.phase)
                d.telegraphTimer = Reaper.telegraphTime
            }
        } else {
            d.telegraphTimer -= dt
            if d.telegraphTimer <= 0 {
                fire(d.telegraph!, at: d.reaperPos)
                d.telegraph = nil
                d.telegraphTimer = Reaper.patternInterval
            }
        }
        state.duel = d
    }

    /// A phase's pattern set: later phases add moves (U19 kit). Deterministic,
    /// chosen from the seeded RNG, never `randomElement`.
    mutating func nextPattern(for phase: Int) -> ReaperPattern {
        let roll = state.rng.unit()
        switch phase {
        case 1: return .sweep
        case 2: return roll < 0.5 ? .sweep : .slam
        default:
            if roll < 0.34 { return .sweep }
            if roll < 0.67 { return .slam }
            return .fogSurge
        }
    }

    /// Execute a pattern: sweep shoves sideways, slam drives down, fog surge
    /// raises the fog briefly. All displacement/fog — never HP.
    mutating func fire(_ pattern: ReaperPattern, at pos: Vec2) {
        switch pattern {
        case .sweep:
            let dir: Double = state.hero.pos.x < pos.x ? -1 : 1
            state.hero.vel.x += dir * Reaper.sweepImpulse / state.mods.footing
            state.hero.invuln = max(state.hero.invuln, tunables.iframes)
            state.frameEvents.append(.heroShoved(at: state.hero.pos))
        case .slam:
            state.hero.vel.y += Reaper.slamImpulse / state.mods.footing
            state.hero.invuln = max(state.hero.invuln, tunables.iframes)
            state.frameEvents.append(.heroShoved(at: state.hero.pos))
        case .fogSurge:
            apply(.timed(.add(.fogAdd, Reaper.fogSurgeAmount), seconds: Reaper.fogSurgeSeconds))
        }
    }

    /// A bolt lands on the Reaper: accumulate the hit, advance phases at
    /// thresholds, and win when the final phase completes.
    mutating func hitReaper() {        guard var d = state.duel else { return }
        d.hits += 1
        if d.hits >= Reaper.phaseThresholds[min(d.phase - 1, 2)] {
            if d.phase >= 3 {
                state.duelWon = true
                state.dead = true
                return
            }
            d.phase += 1
        }
        state.duel = d
    }
}
