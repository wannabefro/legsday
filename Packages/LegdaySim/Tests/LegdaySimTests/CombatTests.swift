import Foundation
import Testing
@testable import LegdaySim

private let defaults = Tunables(
    scroll: 78, spawn: 1.7, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim(seed: UInt64 = 7) -> RunSim {
    RunSim(tunables: defaults, viewport: viewport, seed: seed)
}
private let step = RunSim.fixedStep

struct CombatTests {

    /// R3: contact shoves the hero away from the foe with a downward bias, sets
    /// i-frames, and (via the velocity→target coupling) displaces the drag
    /// target so lost ground is real.
    @Test func contactShovesDownwardBiasedAndDisplacesTarget() {
        var sim = makeSim()
        let hero = sim.state.hero.pos
        sim.debugAddFoe(at: hero + Vec2(5, 0), hp: 99) // to the right, survives
        let targetBefore = sim.state.hero.target

        sim.tick(dt: step, input: .idle) // shove resolves this step
        let v = sim.state.hero.vel
        #expect(v.x < 0)                     // pushed left, away from the foe
        #expect(v.y > 0)                     // downward bias
        #expect(abs(v.length - defaults.shove) < 1e-6) // |impulse| == shove
        #expect(abs(sim.state.hero.invuln - defaults.iframes) < 1e-6)

        sim.tick(dt: step, input: .idle) // velocity drags the target
        let moved = (sim.state.hero.target - targetBefore).length
        #expect(moved > 0.1)
    }

    /// A second contact inside the i-frames window applies no further shove.
    @Test func secondContactWithinIFramesDoesNothing() {
        var sim = makeSim()
        let hero = sim.state.hero.pos
        let foeId = sim.debugAddFoe(at: hero + Vec2(5, 0), hp: 99)
        sim.tick(dt: step, input: .idle)
        let vAfterFirst = sim.state.hero.vel
        // Re-overlap immediately; invuln is still ~0.55s.
        sim.debugMutate { $0.foes[$0.foes.firstIndex { $0.id == foeId }!].pos = hero + Vec2(5, 0) }
        let velLenBefore = vAfterFirst.length
        sim.tick(dt: step, input: .idle)
        // Only decay should change velocity magnitude — no new impulse added.
        #expect(sim.state.hero.vel.length < velLenBefore + 1e-6)
        #expect(sim.state.hero.invuln > 0)
    }

    /// Footing (shove resistance) divides the incoming impulse.
    @Test func footingScalesImpulse() {
        func impulseMagnitude(footing: Double) -> Double {
            var sim = makeSim()
            sim.debugMutate { $0.mods.footing = footing }
            sim.debugAddFoe(at: sim.state.hero.pos + Vec2(5, 0), hp: 99)
            sim.tick(dt: step, input: .idle)
            return sim.state.hero.vel.length
        }
        let normal = impulseMagnitude(footing: 1)
        let braced = impulseMagnitude(footing: 2)
        #expect(abs(braced - normal / 2) < 1e-6)
    }

    /// Elite shove exceeds a normal shove by exactly ×1.7 at equal geometry.
    @Test func eliteShoveExceedsNormalBy1_7() {
        func impulseMagnitude(elite: Bool) -> Double {
            var sim = makeSim()
            sim.debugAddFoe(at: sim.state.hero.pos + Vec2(5, 0), elite: elite, hp: 99)
            sim.tick(dt: step, input: .idle)
            return sim.state.hero.vel.length
        }
        let ratio = impulseMagnitude(elite: true) / impulseMagnitude(elite: false)
        #expect(abs(ratio - RunSim.eliteShoveFactor) < 1e-6)
    }

    /// Auto-attack fells an in-range foe within a cooldown; a kill is counted.
    @Test func autoAttackFellsInRangeFoe() {
        var sim = makeSim()
        // In attack range (100 < 340) but outside contact radius.
        sim.debugAddFoe(at: sim.state.hero.pos + Vec2(100, 0), hp: 1)
        #expect(sim.state.kills == 0)
        sim.tick(dt: step, input: .idle) // attackTimer starts at 0 → fires immediately
        #expect(sim.state.kills == 1)
        #expect(!sim.state.foes.contains { $0.hp <= 0 })
    }

    /// Spawner rate ramps with run time per the graybox curve (0.7 + t·0.05).
    @Test func spawnerRampMatchesGrayboxCurve() {
        var sim = makeSim()
        // Hold the hero out of the fog, so the run cannot end mid-sample.
        func keepAlive(_ s: inout RunSim) {
            s.debugMutate {
                $0.hero.pos.y = 180; $0.hero.target.y = 180; $0.hero.vel = .zero
                $0.card = nil; $0.charge = 0
            }
        }
        // The rate is the curve — realised spawns measure the threat cap.
        let demand0 = sim.state.spawnedCount + sim.state.queuedFoes
        for _ in 0..<60 { keepAlive(&sim); sim.tick(dt: 1.0 / 60, input: .idle) } // ~1s at t≈0
        let rate0 = sim.spawnRate()
        let delta0 = sim.state.spawnedCount + sim.state.queuedFoes - demand0

        for _ in 0..<(119 * 60) { keepAlive(&sim); sim.tick(dt: 1.0 / 60, input: .idle) }
        let rate120 = sim.spawnRate()

        // Expected: ~1.23 spawns/s at t≈0, ~14.8 at t≈120 (THE OSSUARY stage ×1.30).
        #expect(rate0 >= 1 && rate0 <= 3)
        #expect(rate120 >= 12 && rate120 <= 18)
        #expect(rate120 > rate0 * 4 && delta0 >= 1)
    }
}
