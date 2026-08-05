import Foundation
import Testing
@testable import LegdaySim

/// U13 — world-owned mandatory forks on a fathom cadence (R12): zero essence cost,
/// no spring-back, risk vs safe, and no safe road past minute 8.
struct ForkTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1) // spawn 0 → no foes, no essence

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1)
    }

    private static var crossroads: CardDef { CardLibrary.forkSeed[0] }
    private func deal(_ sim: inout RunSim) {
        sim.debugMutate { $0.card = ActiveCard(def: Self.crossroads, deathDealt: false) }
    }

    /// A fork deals after 450 fathoms of climb, with zero essence.
    @Test func forkDealsAtCadenceForFree() {
        var sim = makeSim()
        // Tick with the hero alive and no cards; climb to 449.5 then past 450.5.
        sim.debugMutate { $0.hero.pos.y = 180; $0.hero.target.y = 180
            $0.charge = 0; $0.card = nil }
        while sim.state.fathoms < Ascent.forkCadenceFathoms - 0.5,
              sim.state.card == nil {
            sim.tick(dt: 0.05, input: .idle)
        }
        #expect(sim.state.card == nil) // not yet — 0.5 fathoms short
        while sim.state.fathoms < Ascent.forkCadenceFathoms + 0.5,
              sim.state.card == nil {
            sim.tick(dt: 0.05, input: .idle)
        }
        #expect(sim.state.card?.def.fork != nil)
        #expect(sim.state.charge == 0)
        #expect(sim.state.drawn == 0)
    }

    /// The risk road raises spawn density and the essence multiplier, and flags
    /// a shrine (the U14 hook).
    @Test func riskSideRaisesSpawnAndEssence() {
        var sim = makeSim()
        deal(&sim)
        let s0 = sim.state.mods.spawnMul, e0 = sim.state.mods.essMul
        sim.commitCard(1) // right = risk
        #expect(sim.state.mods.spawnMul > s0)
        #expect(sim.state.mods.essMul > e0)
        #expect(sim.state.shrinePending)
    }

    /// The safe road raises scroll 10% and does not flag a shrine.
    @Test func safeSideRaisesScroll() {
        var sim = makeSim()
        deal(&sim)
        let scroll0 = sim.state.mods.scrollMul
        sim.commitCard(-1) // left = safe (time 0 < minute 8)
        #expect(abs(sim.state.mods.scrollMul - scroll0 * 1.1) < 1e-9)
        #expect(!sim.state.shrinePending)
    }

    /// Past minute 8 the safe slot becomes a second risk flavor: both sides are
    /// risk-shaped (the left slot no longer grants the scroll boon).
    @Test func lateGameBothSidesRisk() {
        var sim = makeSim()
        sim.debugMutate { $0.time = Forks.lateThreshold + 20 }
        deal(&sim)
        let offer = sim.currentOffer()!
        #expect(offer.left == Self.crossroads.fork!.lateRisk)
        #expect(offer.right == Self.crossroads.fork!.risk)

        let scroll0 = sim.state.mods.scrollMul
        sim.commitCard(-1) // the late "safe" slot — now risk-shaped
        #expect(sim.state.mods.scrollMul == scroll0) // no safe scroll boon late
        #expect(sim.state.shrinePending)             // risk-shaped → shrine
    }

    /// A fork cannot spring back: releasing at neutral still commits a side.
    @Test func forkCannotSpringBack() {
        var sim = makeSim()
        deal(&sim) // offset 0
        sim.releaseCard()
        #expect(sim.state.card!.committing) // committed, not returned to neutral
    }
}
