import Foundation
import Testing
@testable import LegdaySim

private let defaults = Tunables(
    scroll: 78, spawn: 1.7, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852) // reference iPhone portrait points

private func makeSim(seed: UInt64 = 42) -> RunSim {
    RunSim(tunables: defaults, viewport: viewport, seed: seed)
}

struct SimFoundationTests {

    /// R1: the Pilgrim eases toward a moved drag target, honoring the fixed
    /// pointer offset (target = anchorTarget + (pointer − anchorPointer)·gain).
    @Test func heroConvergesToMovedDragTarget() {
        var sim = makeSim()
        let start = sim.state.hero.pos
        sim.tick(dt: 1.0 / 60, input: Input(phase: .began, location: Vec2(100, 100)))
        // Hold a moved pointer 50pt right / 20pt down of the anchor.
        for _ in 0..<120 {
            sim.tick(dt: 1.0 / 60, input: Input(phase: .moved, location: Vec2(150, 120)))
        }
        let expectedTarget = start + Vec2(50, 20) * 1.18
        #expect(abs(sim.state.hero.target.x - expectedTarget.x) < 1e-6)
        #expect(abs(sim.state.hero.target.y - expectedTarget.y) < 1e-6)
        // Position has converged onto the target within the follow time.
        #expect((sim.state.hero.pos - sim.state.hero.target).length < 0.5)
    }

    /// R1: the camera advances world Y at exactly the scroll rate, independent
    /// of frame chunking.
    @Test func scrollAdvancesWorldYAtScrollRate() {
        var sim = makeSim()
        for _ in 0..<60 { sim.tick(dt: 1.0 / 60, input: .idle) } // 1.0s → 120 steps
        #expect(sim.stepsTaken == 120)
        #expect(abs(sim.state.worldY - 78.0) < 1e-9)   // 78 px/s · 1s
        #expect(abs(sim.state.fathoms - 7.8) < 1e-9)
    }

    /// KEYSTONE (KTD-1): two sims with the same seed fed an identical
    /// (dt, input) stream are bit-identical after 60 s. Guards every later unit.
    @Test func seedReplayIsBitIdenticalAfter60s() {
        var a = makeSim(seed: 1337)
        var b = makeSim(seed: 1337)
        for i in 0..<3600 { // 60s at 60fps
            let loc = Vec2(196 + 80 * sin(Double(i) * 0.011), 400 + 60 * cos(Double(i) * 0.017))
            let input = Input(phase: i == 0 ? .began : .moved, location: loc)
            a.tick(dt: 1.0 / 60, input: input)
            b.tick(dt: 1.0 / 60, input: input)
        }
        #expect(a.state.fingerprint == b.state.fingerprint)
        #expect(a.stepsTaken == b.stepsTaken)
    }

    /// Accumulator correctness: an irregular real-dt sequence (unequal chunks,
    /// each a whole number of fixed steps, same total) reaches the same step
    /// count and state as the even fixed-step reference.
    @Test func irregularDtMatchesFixedStepReference() {
        let h = RunSim.fixedStep
        var reference = makeSim()
        for _ in 0..<240 { reference.tick(dt: h, input: .idle) }

        var irregular = makeSim()
        // Chunk 240 steps into unequal groups of 1…5 fixed steps (≤ clamp:
        // 5·fixedStep ≈ 0.042s < maxFrameTime).
        var chunks: [Int] = []
        var remaining = 240
        let pattern = [5, 1, 4, 2, 3]
        var i = 0
        while remaining > 0 {
            let k = min(pattern[i % pattern.count], remaining)
            chunks.append(k)
            remaining -= k
            i += 1
        }
        #expect(chunks.reduce(0, +) == 240)
        for k in chunks { irregular.tick(dt: Double(k) * h, input: .idle) }

        #expect(irregular.stepsTaken == reference.stepsTaken)
        #expect(abs(irregular.state.time - reference.state.time) < 1e-9)
        #expect(abs(irregular.state.worldY - reference.state.worldY) < 1e-9)
    }

    /// A resume/launch spike is clamped: a 2 s tick advances at most
    /// `maxFrameTime` of sim time, never the full 2 s.
    @Test func spikeAdvancesAtMostTheClamp() {
        var sim = makeSim()
        sim.tick(dt: 2.0, input: .idle)
        #expect(sim.state.time <= RunSim.maxFrameTime + 1e-9)
        #expect(sim.state.time > 0)
        #expect(sim.stepsTaken == Int((RunSim.maxFrameTime / RunSim.fixedStep).rounded(.down)))
    }

    /// A paused (idle) input leaves the drag target stationary while the world
    /// keeps scrolling.
    @Test func idleInputHoldsTargetWhileScrollContinues() {
        var sim = makeSim()
        // Establish a target, then release to idle.
        sim.tick(dt: 1.0 / 60, input: Input(phase: .began, location: Vec2(100, 100)))
        sim.tick(dt: 1.0 / 60, input: Input(phase: .moved, location: Vec2(160, 140)))
        sim.tick(dt: 1.0 / 60, input: Input(phase: .ended, location: Vec2(160, 140)))
        let heldTarget = sim.state.hero.target
        let worldYBefore = sim.state.worldY

        for _ in 0..<60 { sim.tick(dt: 1.0 / 60, input: .idle) }

        #expect(sim.state.hero.target.x == heldTarget.x)
        #expect(sim.state.hero.target.y == heldTarget.y)
        #expect(sim.state.worldY > worldYBefore) // scroll never paused
    }
}
