import Foundation
import Testing
import LegdaySim
@testable import Legday

/// The Reliquary must state what a relic does and what a duplicate buys, or a
/// pull is an unreadable transaction.
struct ReliquaryCopyTests {
    private func card(_ id: String) -> CardDef {
        CardCatalog.seed.card(id: id)!
    }

    @MainActor
    @Test func ordinaryRelicShowsBothSides() {
        let s = ReliquaryView.effectSummary(card("oath_of_footing"))
        #expect(s == "footing +35% / motes worth ×2")
    }

    /// A weapon's sides are resolved in the run, so its static L/R would lie.
    @MainActor
    @Test func weaponSaysItsFormIsChosenInTheRun() {
        let weapon = CardCatalog.seed.weapons.first!
        #expect(ReliquaryView.effectSummary(weapon).contains("weapon"))
    }

    @MainActor
    @Test func unownedRelicReadsAsUnrecovered() {
        #expect(ReliquaryView.copyNote(card: card("the_tithe"), copies: 0) == "unrecovered")
    }

    /// Only a weapon gains anything at three copies; an ordinary dupe stacks.
    @MainActor
    @Test func onlyWeaponsPromiseASignature() {
        let weapon = CardCatalog.seed.weapons.first!
        #expect(ReliquaryView.copyNote(card: weapon, copies: 2) == "×2 — signature at 3")
        #expect(ReliquaryView.copyNote(card: weapon, copies: 3) == "×3 — signature unlocked")
        #expect(ReliquaryView.copyNote(card: card("the_tithe"), copies: 2) == "×2 in your deck")
    }

    /// The boundary itself: maxTier, not one below it, unlocks the signature.
    @MainActor
    @Test func signatureUnlocksAtMaxTierExactly() {
        let weapon = CardCatalog.seed.weapons.first!
        let atGate = ReliquaryView.copyNote(card: weapon, copies: Collection.maxTier)
        let below = ReliquaryView.copyNote(card: weapon, copies: Collection.maxTier - 1)
        #expect(atGate.contains("unlocked"))
        #expect(!below.contains("unlocked"))
    }
}

/// The pity counter is meaningless unless it survives the pull that increments
/// it — it lived only inside a throwaway Collection before.
struct PityPersistenceTests {
    @MainActor
    @Test func pityRoundTripsThroughTheStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pity-\(UUID().uuidString).json")
        var store = Store(fileURL: url)
        store.pity = 7
        store.save()
        #expect(Store(fileURL: url).pity == 7)
        try? FileManager.default.removeItem(at: url)
    }

    /// A file written before `pity` existed must load, not reset the collection.
    @MainActor
    @Test func olderSaveWithoutPityStillLoads() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-\(UUID().uuidString).json")
        let legacy = #"{"collection":{"the_tithe":2},"shards":40,"bestFathoms":312.5}"#
        try Data(legacy.utf8).write(to: url)
        let store = Store(fileURL: url)
        #expect(store.collection == ["the_tithe": 2])
        #expect(store.shards == 40)
        #expect(store.pity == 0)
        try? FileManager.default.removeItem(at: url)
    }

    /// Pity accumulates across pulls, so the 10-pull guarantee can be reached.
    /// Owning the whole pool forces every pull to be a dupe, so no reset hides
    /// a counter that never moves — the defect this test exists for.
    @MainActor
    @Test func pityAccumulatesAcrossPulls() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flow-\(UUID().uuidString).json")
        var store = Store(fileURL: url)
        store.shards = Collection.pullCost * 3
        let pool = CardCatalog.seed.player + CardCatalog.seed.weapons
        store.collection = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, 1) })
        store.save()
        let flow = GameFlow(store: store, catalog: .seed)
        #expect(flow.pullsToGuarantee == Collection.pityGuarantee)
        _ = flow.pull()
        #expect(flow.store.pity == 1)
        _ = flow.pull()
        #expect(flow.store.pity == 2)
        #expect(flow.pullsToGuarantee == Collection.pityGuarantee - 2)
        try? FileManager.default.removeItem(at: url)
    }
}
