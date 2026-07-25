import Foundation
import Testing
@testable import LegdaySim

private let cardDefaults = Tunables(
    scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim(seed: UInt64 = 31) -> RunSim {
    RunSim(tunables: cardDefaults, viewport: viewport, seed: seed)
}
private let step = RunSim.fixedStep
private func knuckle() -> CardDef { CardLibrary.playerSeed.first { $0.id == "second_knuckle" }! }
private func input(_ p: Input.Phase, _ x: Double, _ y: Double = 400) -> Input {
    Input(phase: p, location: Vec2(x, y))
}

struct InputRoutingTests {

    /// R8: while a card is engaged, movement input tilts the card, not the hero.
    @Test func engagedCardMovementDoesNotMoveHeroTarget() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let heroX = sim.state.hero.target.x
        sim.tick(dt: step, input: input(.began, 200))
        sim.tick(dt: step, input: input(.moved, 320)) // would move the hero if not routed
        #expect(sim.state.hero.target.x == heroX)      // hero x untouched
        #expect(sim.state.card!.offset != 0)           // the card tilted instead
    }

    /// Commit past the 30% threshold applies the chosen side's effects.
    @Test func commitPastThresholdAppliesEffects() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let cd = sim.state.mods.attackCooldown
        sim.tick(dt: step, input: input(.began, 200))
        sim.tick(dt: step, input: input(.moved, 200 + viewport.x * 0.4)) // right, past 30%
        sim.tick(dt: step, input: input(.ended, 200 + viewport.x * 0.4))
        #expect(sim.state.card!.committing)
        #expect(abs(sim.state.mods.attackCooldown - cd * 0.8) < 1e-9) // right = attack ×0.8
    }

    /// A sub-threshold release springs the card back to neutral, unapplied.
    @Test func subThresholdReleaseSpringsBack() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let cd = sim.state.mods.attackCooldown
        sim.tick(dt: step, input: input(.began, 200))
        sim.tick(dt: step, input: input(.moved, 200 + viewport.x * 0.2)) // below 30%
        sim.tick(dt: step, input: input(.ended, 200 + viewport.x * 0.2))
        #expect(!sim.state.card!.committing)
        #expect(sim.state.card!.offset == 0)
        #expect(sim.state.mods.attackCooldown == cd) // nothing applied
    }

    /// A cancel while engaged springs back with no effects — even past the
    /// threshold (an abort, unlike a release).
    @Test func cancelAlwaysSpringsBackNoEffects() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let cd = sim.state.mods.attackCooldown
        sim.tick(dt: step, input: input(.began, 200))
        sim.tick(dt: step, input: input(.moved, 200 + viewport.x * 0.4)) // past 30%
        sim.tick(dt: step, input: input(.cancelled, 200 + viewport.x * 0.4))
        #expect(!sim.state.card!.committing)         // not committed
        #expect(sim.state.card!.offset == 0)         // sprung back
        #expect(sim.state.mods.attackCooldown == cd) // nothing applied
    }

    /// A card dealt mid-drag transfers the thumb: the hero freezes and the card
    /// tilts from the transfer anchor.
    @Test func cardDealtMidDragTransfersToCard() {
        var sim = makeSim()
        sim.tick(dt: step, input: input(.began, 200))
        sim.tick(dt: step, input: input(.moved, 220))
        sim.debugMutate { $0.charge = $0.essNeed }         // deal next step
        sim.tick(dt: step, input: input(.moved, 230))       // draws card at step end
        #expect(sim.state.card != nil)

        sim.tick(dt: step, input: input(.moved, 280))       // establishes transfer anchor (280)
        let heroX = sim.state.hero.target.x
        sim.tick(dt: step, input: input(.moved, 320))       // offset = 320 − 280
        #expect(abs(sim.state.card!.offset - 40) < 1e-9)
        #expect(sim.state.hero.target.x == heroX)           // hero frozen under the card
    }

    /// Backgrounding mid-card and resuming leaves the card engaged with no time
    /// jump (the resume dt spike is clamped).
    @Test func backgroundResumeKeepsCardEngaged() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        for _ in 0..<30 { sim.tick(dt: step, input: .idle) } // settle the timescale
        let t0 = sim.state.time
        sim.tick(dt: 2.0, input: .idle)                     // resume spike
        #expect(sim.state.card != nil)
        #expect(!sim.state.card!.committing)
        #expect(sim.state.time - t0 <= RunSim.maxFrameTime + 1e-9)
    }
}
