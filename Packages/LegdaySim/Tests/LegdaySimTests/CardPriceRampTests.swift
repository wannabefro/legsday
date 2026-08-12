// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

private let noSpawn = Tunables(
    scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 5, cardCostIncrement: 10
)
private func makeSim() -> RunSim {
    RunSim(tunables: noSpawn, viewport: Vec2(393, 852), seed: 5)
}

/// Essence income is multiplied by `essMul`, so the price ramp is too. A flat
/// ramp against a multiplied income has no stable card count. Measured at the
/// shipped spawn rate: increment 6 drew 44 cards a run and increment 7 drew 10.
struct CardPriceRampTests {

    /// At the default multiplier the ramp is the shipped increment exactly.
    @Test func theFirstCardCostsTheShippedPrice() {
        var sim = makeSim()
        #expect(sim.state.essNeed == 5)
        sim.debugMutate { $0.charge = 5 }
        sim.debugDrawCardIfCharged()
        #expect(sim.state.essNeed == 15)
    }

    /// A stacked multiplier ramps the price by the same factor it ramps income.
    @Test func theRampRidesTheEssenceMultiplier() {
        var sim = makeSim()
        sim.debugMutate { $0.mods.essMul = 3; $0.charge = 5 }
        sim.debugDrawCardIfCharged()
        #expect(sim.state.essNeed == 5 + 10 * 3)
    }

    /// The ceiling bounds the ramp, because it bounds the income it tracks.
    @Test func theRampStopsRampingAtTheCeiling() {
        var sim = makeSim()
        sim.debugMutate { $0.mods.essMul = RunSim.essMulCeiling; $0.charge = 5 }
        sim.debugDrawCardIfCharged()
        #expect(sim.state.essNeed == 5 + 10 * RunSim.essMulCeiling)
    }

    /// Charge below the price deals nothing and leaves the price alone.
    @Test func anUnderchargedRunDrawsNoCard() {
        var sim = makeSim()
        sim.debugMutate { $0.charge = 4.999 }
        sim.debugDrawCardIfCharged()
        #expect(sim.state.card == nil)
        #expect(sim.state.essNeed == 5)
    }

    /// The boundary itself deals, not one step past it.
    @Test func chargeExactlyAtThePriceDeals() {
        var sim = makeSim()
        sim.debugMutate { $0.charge = 5 }
        sim.debugDrawCardIfCharged()
        #expect(sim.state.card != nil)
    }
}
