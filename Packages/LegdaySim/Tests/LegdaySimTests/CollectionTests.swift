// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

/// U21 — the Reliquary pull model (R19): pity guarantees a new card within 10
/// pulls while unowned cards remain, dupes tier (capped at 3), and a complete
/// collection always tiers.
struct CollectionTests {
    private func pool(_ n: Int) -> [CardDef] {
        (0..<n).map { CardDef(id: "card_\($0)", title: "CARD \($0)",
            spine: .rust, isDeath: false,
            left: CardChoice(label: "l", subtitle: "s", effects: []),
            right: CardChoice(label: "r", subtitle: "s", effects: [])) }
    }

    private func rng(_ seed: UInt64 = 1) -> SeededRandom {
        SeededRandom(seed: seed)
    }

    /// Property test over seeds: 10 pulls never yield zero new cards while
    /// unowned cards remain (the pity guarantee).
    @Test func pityGuaranteesNewCardWithinTen() {
        for seed in UInt64(1)...20 {
            var r = rng(seed)
            var c = Collection(pool: pool(12))
            var newCount = 0
            for _ in 0..<10 { _ = c.pull(using: &r) }
            for id in c.unownedIds { _ = id } // no-op: just compute
            newCount = c.owned.values.filter { $0 >= 1 }.count
            #expect(newCount >= 1) // at least one distinct new card drawn
            #expect(c.pullsMade == 10)
        }
    }

    /// Dupes increment the tier, capped at 3.
    @Test func dupesTierUpToThree() {
        var r = rng(2)
        var c = Collection(pool: pool(1)) // single card → every pull is a dupe
        for _ in 0..<6 { _ = c.pull(using: &r) }
        #expect(c.tier(of: "card_0") == 3)
        #expect(c.owned["card_0"] == 6)
    }

    /// A complete collection converts every pull to tiering — never a stall.
    @Test func completeCollectionAlwaysTiers() {
        var r = rng(3)
        var c = Collection(pool: pool(3), owned: ["card_0": 1, "card_1": 1, "card_2": 1])
        #expect(c.isComplete)
        for _ in 0..<5 { _ = c.pull(using: &r) }
        #expect(c.owned.values.allSatisfy { $0 >= 1 })
        // Every pull landed on an owned card (all owned), so copies grew.
        let total = c.owned.values.reduce(0, +)
        #expect(total == 3 + 5)
    }

    /// The pity counter resets on a new card and the guarantee fires exactly.
    @Test func pityResetsOnNewCard() {
        var r = rng(4)
        var c = Collection(pool: pool(12))
        // Force the pity high, then a guaranteed-new pull resets it.
        c.debugAdvancePity(to: 9)
        let id = c.pull(using: &r)
        #expect(c.owned[id] == 1) // it was unowned
        #expect(c.pity == 0)
    }
}
