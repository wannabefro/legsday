// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

/// U17 — draft validation (R9): the 2-copy cap, the Opener rule, the 13-card
/// unlock, and the sub-13 whole-collection deck.
struct DraftTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    /// The draftable pool: player cards plus weapons (drafted via U17).
    private static var ids: [String] {
        (CardLibrary.playerSeed + CardLibrary.weaponSeed).map(\.id)
    }

    /// Twelve picks with an Opener is valid; the opener must be among them.
    @Test func twelveWithOpenerIsValid() {
        let picks = Array(Self.ids.prefix(12))
        #expect(Draft(picks: picks, opener: picks.first).isValid)
        #expect(!Draft(picks: picks, opener: "not_picked").isValid)
        #expect(Draft(picks: picks, opener: nil).isValid) // sub-13 whole-collection form
    }

    /// A small collection drafts fewer than 12 — up to the max is valid.
    @Test func smallerDraftIsValid() {
        let picks = Array(Self.ids.prefix(6)) // six distinct, one copy each
        #expect(picks.count < Draft.maxCards)
        #expect(Draft(picks: picks, opener: picks.first).isValid)
    }

    /// A 13th pick is rejected; exactly 12 is fine.
    @Test func thirteenthPickIsRejected() {
        // 8 distinct cards: 13 picks via repeats, none over 2.
        let picks = Self.ids + Self.ids.prefix(5)
        #expect(picks.count == 13)
        #expect(!Draft(picks: picks, opener: Self.ids[0]).isValid)
        #expect(Draft(picks: Array(picks.prefix(12)), opener: Self.ids[0]).isValid) // 12
    }

    /// A 3rd copy of any card is rejected — the 2-copy cap.
    @Test func thirdCopyIsRejected() {
        let picks = [Self.ids[0], Self.ids[0], Self.ids[0], Self.ids[1]]
        #expect(!Draft(picks: picks, opener: Self.ids[0]).isValid)
        #expect(Draft(picks: [Self.ids[0], Self.ids[0], Self.ids[1]], opener: Self.ids[0]).isValid)
    }

    /// The draft unlocks once the collection holds 13+ cards (R9).
    @Test func draftUnlocksAtThirteen() {
        #expect(!Draft.isUnlocked(collection: [:]))
        #expect(!Draft.isUnlocked(collection: ["a": 6, "b": 6]))
        #expect(Draft.isUnlocked(collection: ["a": 6, "b": 7]))
        #expect(Draft.isUnlocked(collection: ["a": 13]))
    }

    /// Sub-13: the run deck is the whole collection, no draft, no Opener.
    @Test func subThirteenCollectionBuildsWholeCollectionDeck() {
        let collection = ["second_knuckle": 2, "the_tithe": 1]
        let sim = RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1,
                         catalog: .seed, collection: collection)
        let expected = ["second_knuckle", "second_knuckle", "the_tithe"].sorted()
        #expect(sim.state.deck.map(\.id).sorted() == expected)
    }

    /// The deck resolves picks to cards, the Opener first (first draw).
    @Test func draftBuildsDeckWithOpenerFirst() {
        let picks = ["second_knuckle", "the_tithe", "pilgrims_pace"]
        let draft = Draft(picks: picks, opener: "the_tithe")
        let sim = RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1,
                         catalog: .seed, draft: draft)
        #expect(sim.state.deck.map(\.id) == ["the_tithe", "second_knuckle", "pilgrims_pace"])
        #expect(sim.state.deck.first?.id == draft.opener)
    }

    /// Hostility forecast follows the draft's faction weighting (R10). Weapon
    /// cards carry factions; the player seed does not.
    @Test func draftDeckDrivesHostilityForecast() {
        let church = Draft(picks: ["the_thurible", "the_thurible", "the_thurible"], opener: nil)
        let neutral = Draft(picks: ["second_knuckle", "lantern_oil", "the_tithe"], opener: nil)
        func threats(_ d: Draft) -> [ThreatInsertion] {
            let sim = RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 2,
                             catalog: .seed, draft: d)
            return sim.state.scheduledThreats
        }
        #expect(threats(church).count > threats(neutral).count)
        #expect(threats(church).allSatisfy { $0.faction == .plague }) // Church → Plague
    }
}
