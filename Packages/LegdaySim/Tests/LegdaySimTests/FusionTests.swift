import Foundation
import Testing
@testable import LegdaySim

/// U15 — Death deals a FUSION when two owned weapons are each upgraded past the
/// gate (R15). Fuse loses both for the evolution and converts remaining deck
/// copies; decline pays a boon and suppresses the recipe. Closes AE4 end-to-end.
struct FusionTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1)
    }

    private func own(_ sim: inout RunSim, _ id: String, total: Int) {
        sim.debugMutate { $0.weapons[id] = WeaponState(owned: true, form: 0, levels: [total, 0]) }
    }

    /// The recipe fires only when *both* sources are upgraded ≥ the gate.
    @Test func recipeFiresOnlyAtBothUpgraded() {
        var sim = makeSim()
        own(&sim, "the_thurible", total: 2)
        own(&sim, "the_passing_bell", total: 1) // one short
        sim.checkFusionRecipes()
        #expect(sim.state.pendingFusion == nil)

        own(&sim, "the_passing_bell", total: 2)
        sim.checkFusionRecipes()
        #expect(sim.state.pendingFusion?.a == "the_thurible")
        #expect(sim.state.pendingFusion?.rivalPair == false) // the neutral pair
    }

    /// The rival-pair recipe needs the Plague weapon, which lives only in the
    /// Herald-offer pool — never the draftable weapons pool.
    @Test func rivalPairReachableOnlyViaHeraldOffer() {
        #expect(!CardCatalog.seed.weapons.contains { $0.id == "the_censer_rot" })
        #expect(CardCatalog.seed.rivalOffers.contains { $0.id == "the_censer_rot" })

        var sim = makeSim()
        own(&sim, "the_thurible", total: 2)
        own(&sim, "the_censer_rot", total: 2) // as if won from a Plague Herald
        sim.checkFusionRecipes()
        #expect(sim.state.pendingFusion?.rivalPair == true)
    }

    /// Fuse removes both sources, grants the evolution at the combined level, and
    /// rewrites remaining deck copies of the sources into evolution upgrades.
    @Test func fuseRemovesSourcesAndConvertsDeckCopies() {
        var sim = makeSim()
        own(&sim, "the_thurible", total: 2)
        own(&sim, "the_passing_bell", total: 2)
        let thu = CardLibrary.weaponSeed.first { $0.id == "the_thurible" }!
        let bell = CardLibrary.weaponSeed.first { $0.id == "the_passing_bell" }!
        sim.debugMutate { $0.deck = [thu, CardLibrary.playerSeed[0], bell] }

        sim.checkFusionRecipes(); sim.maybeDealFusion()
        #expect(sim.state.card?.def.fusion != nil)
        sim.commitCard(-1) // left = fuse

        #expect(sim.state.weapons["the_thurible"] == nil)
        #expect(sim.state.weapons["the_passing_bell"] == nil)
        #expect(sim.state.weapons["the_requiem"]?.owned == true)
        #expect(sim.state.weapons["the_requiem"]?.levels.reduce(0, +) == 4) // 2 + 2
        #expect(sim.state.deck.filter { $0.id == "the_requiem" }.count == 2)
        #expect(!sim.state.deck.contains { $0.id == "the_thurible" || $0.id == "the_passing_bell" })
    }

    /// Decline pays the boon and suppresses the recipe for the rest of the run.
    @Test func declineGrantsBoonAndSuppresses() {
        var sim = makeSim()
        own(&sim, "the_thurible", total: 2)
        own(&sim, "the_passing_bell", total: 2)
        sim.checkFusionRecipes(); sim.maybeDealFusion()
        let essBefore = sim.state.essence

        sim.commitCard(1) // right = decline
        #expect(sim.state.essence == essBefore + Fusions.declineBoon)
        #expect(sim.state.suppressedFusions.contains("the_thurible+the_passing_bell"))

        sim.debugMutate { $0.card = nil }
        sim.checkFusionRecipes()
        #expect(sim.state.pendingFusion == nil) // never re-fires
    }
}
