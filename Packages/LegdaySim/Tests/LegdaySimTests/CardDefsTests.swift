import Foundation
import Testing
@testable import LegdaySim

struct CardDefsTests {
    /// The seed catalog round-trips through JSON card-for-card (KTD-7).
    @Test func seedCatalogRoundTrips() throws {
        let data = try JSONEncoder().encode(CardCatalog.seed)
        let back = try CardCatalog.decoded(from: data)
        #expect(back == CardCatalog.seed)
        #expect(back.player.count == 5)
        #expect(back.death.count == 3)
    }

    /// An unknown effect name fails decode loudly — no silent fallback.
    @Test func unknownEffectFailsDecode() {
        let bad = #"{"frobnicate":{"_0":"footing","_1":2}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Effect.self, from: Data(bad.utf8))
        }
    }

    /// A decoded card applies the same Mods mutation as the in-code seed
    /// (spot-check the whole-catalog equivalence at the effect level).
    @Test func decodedCardAppliesSameMutation() throws {
        let data = try JSONEncoder().encode(CardCatalog.seed)
        let catalog = try CardCatalog.decoded(from: data)
        let t = Tunables(scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1)
        var sim = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 1, catalog: catalog)
        let knuckle = catalog.player.first { $0.id == "second_knuckle" }!
        sim.debugMutate { $0.card = ActiveCard(def: knuckle, deathDealt: false) }
        let before = sim.state.mods.attackCooldown
        sim.commitCard(1) // right: attack ×0.8
        #expect(abs(sim.state.mods.attackCooldown - before * 0.8) < 1e-9)
    }
}
