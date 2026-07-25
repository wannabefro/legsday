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
    public internal(set) var state: RunState
    /// Total fixed steps executed — exposes accumulator behavior for testing.
    public private(set) var stepsTaken: Int = 0
    private var accumulator: Double = 0

    public init(tunables: Tunables, viewport: Vec2, seed: UInt64) {
        self.tunables = tunables
        self.state = RunState(width: viewport.x, height: viewport.y, seed: seed)
    }

    /// Effective scroll rate, px/s (graybox `scrollEff`).
    public func scrollEff() -> Double { tunables.scroll * state.mods.scrollMul }

    /// Advance by real elapsed `dt`, honoring the same `input` for each fixed
    /// step it produces. A `dt` above `maxFrameTime` is clamped (spike absorb).
    public mutating func tick(dt: Double, input: Input) {
        state.frameEvents.removeAll(keepingCapacity: true) // render hints are per-tick
        accumulator += min(dt, Self.maxFrameTime)
        while accumulator >= Self.fixedStep {
            step(dt: Self.fixedStep, input: input)
            accumulator -= Self.fixedStep
        }
    }

    // MARK: - One fixed step

    private mutating func step(dt: Double, input: Input) {
        guard !state.dead else { return } // the run is frozen once caught
        stepsTaken += 1
        state.time += dt
        state.worldY += scrollEff() * dt
        applyInput(input)
        integrateHero(dt: dt)
        updateFog(dt: dt)
        spawnFoes(dt: dt)
        steerAndContact(dt: dt)
        autoAttack(dt: dt)
        updateMotes(dt: dt)
    }

    /// Offset-follow: touch-down anchors (pointer, hero target); movement sets
    /// the target relative to that anchor, so the finger never sits on the hero.
    private mutating func applyInput(_ input: Input) {
        switch input.phase {
        case .began:
            state.anchor = (pointer: input.location, heroTarget: state.hero.target)
        case .moved:
            guard let anchor = state.anchor else { return }
            let delta = (input.location - anchor.pointer) * (Self.dragGain * state.mods.gain)
            state.hero.target = anchor.heroTarget + delta
        case .ended:
            state.anchor = nil
        case .idle:
            break // target holds; scroll continues
        }
    }

    /// Port of the graybox hero integration: seek target, apply decaying
    /// knockback (which also drags the target so lost ground is real), clamp.
    private mutating func integrateHero(dt: Double) {
        var h = state.hero
        let seek = min(1, dt * Self.followRate)
        h.pos.x += (h.target.x - h.pos.x) * seek
        h.pos.y += (h.target.y - h.pos.y) * seek
        h.pos.x += h.vel.x * dt
        h.pos.y += h.vel.y * dt

        let dec = exp(-dt * Self.velDecay)
        h.vel.x *= dec
        h.vel.y *= dec
        h.target.x += h.vel.x * dt
        h.target.y += h.vel.y * dt

        h.pos = clampToViewport(h.pos)
        h.target = clampToViewport(h.target)
        if h.invuln > 0 { h.invuln -= dt }
        state.hero = h
    }

    private func clampToViewport(_ p: Vec2) -> Vec2 {
        Vec2(
            min(max(p.x, 14), state.width - 14),
            min(max(p.y, 64), state.height - 12)
        )
    }
}
