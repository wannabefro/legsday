import Foundation

/// The deterministic simulation core. `tick(dt:input:)` absorbs variable real
/// frame timing into a fixed-step accumulator (KTD-1) and advances `RunState`
/// one identical `step` at a time — the same step size in tests and on device,
/// so determinism survives variable frame pacing.
public struct RunSim {
    /// Fixed internal step. Small enough to keep later stiff physics
    /// (springs, rope) stable; identical on host and device.
    public static let fixedStep: Double = 1.0 / 120.0
    /// Largest real dt a single tick will honor — absorbs launch/resume spikes
    /// so a stall can't teleport the world (graybox `Math.min(0.05, …)`).
    public static let maxFrameTime: Double = 0.05

    // Movement constants ported from the graybox.
    private static let dragGain: Double = 1.18     // pointer→target sensitivity
    private static let followRate: Double = 14     // target-seek gain
    private static let velDecay: Double = 5.5      // knockback decay rate

    public let tunables: Tunables
    /// Card content, injected so it can come from bundled data (U10).
    public let catalog: CardCatalog
    /// Collection dupe counts (card id → copies owned) driving weapon tier (U11).
    /// U21's Reliquary fills this; empty means every card is tier 1.
    public let collection: [String: Int]
    public internal(set) var state: RunState
    /// Total fixed steps executed — exposes accumulator behavior for testing.
    public private(set) var stepsTaken: Int = 0
    /// Card-interrupt time scaling (KTD-2).
    public private(set) var timescale = Timescale()
    /// How many foes the screen may hold at once. Overflow queues.
    public let threatCap: Int
    private var accumulator: Double = 0

    public init(tunables: Tunables, viewport: Vec2, seed: UInt64,
                catalog: CardCatalog = .seed, collection: [String: Int] = [:],
                draft: Draft? = nil, threatCap: Int = RunSim.defaultThreatCap) {
        self.tunables = tunables
        self.catalog = catalog
        self.collection = collection
        self.threatCap = threatCap
        self.state = RunState(width: viewport.x, height: viewport.y, seed: seed)
        self.state.essNeed = tunables.firstCardCost
        if let draft {
            buildDeck(draft: draft)
        } else if !collection.isEmpty {
            buildDeck(collection: collection)
        } else {
            buildDeck()
        }
    }

    /// Effective scroll rate, px/s (graybox `scrollEff`). Zero during a duel —
    /// the only code path that can halt the scroll (U19). Once keep-running is
    /// chosen it ramps without bound (R17).
    public func scrollEff() -> Double {
        if state.duel != nil { return 0 }
        let base = tunables.scroll * state.stage.scroll * state.mods.scrollMul
        guard state.keepRunning else { return base }
        let elapsed = max(0, state.time - state.keepRunningStartedAt)
        return base * (1 + elapsed * Finale.keepRunningRamp)
    }

    /// Advance by real elapsed `dt`, honoring the same `input` for each fixed
    /// step it produces. A `dt` above `maxFrameTime` is clamped (spike absorb).
    public mutating func tick(dt: Double, input: Input) {
        state.frameEvents.removeAll(keepingCapacity: true) // render hints are per-tick
        guard !state.dead else { return }                  // frozen once caught

        let clamped = min(dt, Self.maxFrameTime)
        // Ease the timescale on real time, then feed the accumulator *scaled*
        // sim time — the world holds its breath while a card is up (KTD-2).
        timescale.advance(toward: cardTimescaleTarget(), realDt: clamped)
        let ts = timescale.current
        // The card takes the thumb: its input is handled in real time (once per
        // tick), so dragging stays responsive while the world is nearly frozen.
        if let c = state.card, !c.committing {
            applyCardInput(input)
        }
        accumulator += clamped * ts
        while accumulator >= Self.fixedStep {
            step(dt: Self.fixedStep, input: input)
            accumulator -= Self.fixedStep
        }
        // …but the Pilgrim still drifts at full scroll. Reading costs ground (R8).
        if ts < 0.999 {
            state.hero.target.y += scrollEff() * clamped * (1 - ts)
            state.hero.target = clampToViewport(state.hero.target)
        }
        // The card animates in real time (it rises/slides while the world is slow).
        updateCardAnimation(realDt: clamped)
    }

    // MARK: - One fixed step

    private mutating func step(dt: Double, input: Input) {
        guard !state.dead else { return } // the run is frozen once caught
        stepsTaken += 1
        state.time += dt
        state.worldY += scrollEff() * dt

        // Resolve the current stage; entering one emits the banner event.
        let stage = Ascent.stage(atFathoms: state.fathoms)
        if stage.id != state.stage.id {
            state.stage = stage
            state.frameEvents.append(.stageEntered(stage))
            seedStageThreat(stage)
        }
        processTimedEffects()
        maybeSpawnShrineHerald() // a risk-route shrine summons a guardian (U13→U14)
        applyInput(input)
        integrateHero(dt: dt)
        updateFeel(dt: dt)
        updateRope(dt: dt)
        updateFog(dt: dt)
        updateFeatures(dt: dt)
        spawnFoes(dt: dt)
        steerAndContact(dt: dt)
        autoAttack(dt: dt)
        updateHerald(dt: dt)
        updateMotes(dt: dt)
        maybeDealFork()  // mandatory forks take priority over essence-charged draws
        checkFusionRecipes(); maybeDealFusion() // Death deals fusions ahead of the queue
        maybeDealFinale() // Death deals on entry to THE RECKONING (unit 4)
        maybeEnterDuel()  // the Finale's "turn & fight" zeroes the scroll (U19)
        updateDuel(dt: dt) // the Reaper duel advances while it runs
        maybeDealOffer() // a felled Herald's rival offer deals ahead of the cadence
        maybeDrawCard()
    }

    /// Offset-follow: touch-down anchors (pointer, hero target); movement sets
    /// the target relative to that anchor, so the finger never sits on the hero.
    private mutating func applyInput(_ input: Input) {
        // While a card holds the thumb its input is handled in tick(); the step
        // only drives hero movement, and only when no card is engaged.
        guard state.card == nil || state.card!.committing else { return }
        switch input.phase {
        case .began:
            state.anchor = (pointer: input.location, heroTarget: state.hero.target)
        case .moved:
            guard let anchor = state.anchor else { return }
            let delta = (input.location - anchor.pointer) * (Self.dragGain * state.mods.gain)
            state.hero.target = anchor.heroTarget + delta
        case .ended, .cancelled:
            state.anchor = nil
        case .idle:
            break // target holds; scroll continues
        }
    }

    /// Port of the graybox hero integration: seek target, apply decaying
    /// knockback (which also drags the target so lost ground is real), clamp.
    private mutating func integrateHero(dt: Double) {
        var h = state.hero
        // Before the seek, or the heading would see only the knockback.
        let before = h.pos
        let drag = inBriar(h.pos) ? Feature.heroBriarSeek : 1
        let seek = min(1, dt * Self.followRate * drag)
        h.pos.x += (h.target.x - h.pos.x) * seek
        h.pos.y += (h.target.y - h.pos.y) * seek
        h.pos.x += h.vel.x * dt
        h.pos.y += h.vel.y * dt

        let dec = exp(-dt * Self.velDecay)
        h.vel.x *= dec
        h.vel.y *= dec
        h.target.x += h.vel.x * dt
        h.target.y += h.vel.y * dt

        state.gorge.generate(throughWorldY: terrainY(of: 0), stageID: state.stage.id)
        h.pos = clampToViewport(h.pos, velocity: &h.vel)
        let freed = pushOutOfCairns(h.pos, velocity: &h.vel, radius: 12)
        // The target follows, or it pulls the Pilgrim back into the stone.
        if freed != h.pos { h.target = freed }
        h.pos = freed
        h.target = clampToViewport(h.target)
        if h.invuln > 0 { h.invuln -= dt }
        state.hero = h
        updateHeroRig(dt: dt, drive: h.pos - before)
    }

    private func clampToViewport(_ p: Vec2) -> Vec2 {
        let clamped = Vec2(p.x, min(max(p.y, 64), state.height - 12))
        return state.gorge.clamp(clamped, radius: 14, at: terrainY(of: clamped.y))
    }

    private func clampToViewport(_ p: Vec2, velocity: inout Vec2) -> Vec2 {
        let clamped = Vec2(p.x, min(max(p.y, 64), state.height - 12))
        return state.gorge.clamp(clamped, velocity: &velocity, radius: 14,
                                 at: terrainY(of: clamped.y))
    }

    /// Screen y runs down from the top of the viewport; terrain y runs up the climb.
    func terrainY(of screenY: Double) -> Double {
        state.worldY + state.height - screenY
    }
}
