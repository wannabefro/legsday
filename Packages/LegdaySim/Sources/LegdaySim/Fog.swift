import Foundation

/// The fog economy (R4, R5) and its rippling surface (R20). The fog owns the
/// bottom of the screen: it advances on a ramping clock, every kill pushes it
/// back, and a stay past the grace window is fatal. The spring surface is
/// read-only feedback — death is decided by the flat rest line only.
extension RunSim {
    private static let fogBaseOffset: Double = 110   // graybox 110px above bottom
    private static let fogWobbleAmp: Double = 12
    private static let fogWobbleFreq: Double = 1.05
    private static let fogPressureCap: Double = 190
    private static let gracePull: Double = 8          // gentle downward pull in grace
    private static let gripPull: Double = 30           // strong pull once gripped
    private static let fogTimeDecay: Double = 0.9      // fogTime bleed when clear
    private static let corpseFallSpeed: Double = 420   // px/s; splash-delay basis
    private static let splashMagnitude: Double = 90    // ripple velocity per kill

    /// The flat fog rest line in reference-space y. Larger `fogPressure` raises
    /// it (smaller y) toward the hero. The wobble is a slow breathing.
    public func fogLineY() -> Double {
        let wobble = sin(state.time * Self.fogWobbleFreq) * Self.fogWobbleAmp
        return state.height - (Self.fogBaseOffset + wobble + state.fogPressure + state.mods.fogAdd)
    }

    /// Advance fog pressure, fire due splashes, ripple the surface, then resolve
    /// the grace/grip death timer against the flat rest line.
    mutating func updateFog(dt: Double) {
        // Ramping creep (graybox: fogCreep · (0.7 + t·0.015)); a living Herald
        // anchors the fog, accelerating the creep (R16).
        let heraldCreep = state.herald != nil ? Heralds.creepMult : 1
        let creep = dt * tunables.fogCreep * (0.7 + state.time * 0.015) * heraldCreep
        state.fogPressure = min(Self.fogPressureCap, state.fogPressure + creep)

        firePendingSplashes()
        state.fogSurface.update(dt: dt)

        let line = fogLineY()
        state.heroInFog = state.hero.pos.y > line
        if state.heroInFog {
            state.hero.fogTime += dt
            state.heroGripped = state.hero.fogTime > tunables.fogGrace
            // The fog pulls the drag target down — gently in grace, hard in grip.
            state.hero.target.y += (state.heroGripped ? Self.gripPull : Self.gracePull) * dt
            if state.hero.fogTime - tunables.fogGrace > tunables.fogGrip {
                state.dead = true
                if state.duel != nil { state.deadInDuel = true }
            }
        } else {
            state.heroGripped = false
            state.hero.fogTime = max(0, state.hero.fogTime - dt * Self.fogTimeDecay)
        }
    }

    private mutating func firePendingSplashes() {
        guard !state.pendingSplashes.isEmpty else { return }
        var remaining: [RunState.PendingSplash] = []
        remaining.reserveCapacity(state.pendingSplashes.count)
        for s in state.pendingSplashes {
            if state.time >= s.dueTime {
                state.fogSurface.inject(atFraction: s.xFraction, magnitude: s.magnitude)
            } else {
                remaining.append(s)
            }
        }
        state.pendingSplashes = remaining
    }

    /// Kill consequences owned by U4: push the fog back and schedule the
    /// corpse's splash after a deterministic fall delay (KTD-3).
    mutating func applyFogKill(_ foe: Foe) {
        // A living Herald halves every kill-push — the fog holds while it lives (R16).
        let heraldFactor = state.herald != nil ? Heralds.killPushFactor : 1
        let push = tunables.killPush * (foe.elite ? Self.eliteFogPushFactor : 1) * heraldFactor
        state.fogPressure = max(0, state.fogPressure - push)

        let fallDistance = max(0, fogLineY() - foe.pos.y)
        let delay = fallDistance / Self.corpseFallSpeed
        let xFraction = min(max(foe.pos.x / state.width, 0), 1)
        state.pendingSplashes.append(
            RunState.PendingSplash(
                dueTime: state.time + delay,
                xFraction: xFraction,
                magnitude: Self.splashMagnitude * (foe.elite ? 1.6 : 1)
            )
        )
    }
}
