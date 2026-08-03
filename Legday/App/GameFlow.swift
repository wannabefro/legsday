import SwiftUI
import SpriteKit
import LegdaySim

/// KTD-6 shell split: SwiftUI meta screens, SpriteKit run. GameFlow owns the
/// navigation and the persisted meta Store (U20).
@MainActor
@Observable
final class GameFlow {
    enum Stage: Equatable {
        case title
        case draft
        case run(Draft)
        case results(RunResult)
        case reliquary
    }

    /// The persisted meta state (collection, shards, best distance).
    var store: Store
    /// The card content a run plays from (bundled cards.json, U10).
    let catalog: CardCatalog
    private(set) var stage: Stage = .draft

    init(store: Store = Store(),
         catalog: CardCatalog = (try? CardCatalog.bundled()) ?? .seed) {
        self.store = store
        self.catalog = catalog
        // Seed the collection once so a first run has cards to draft.
        if store.collection.isEmpty {
            var seeded = store
            seeded.collection = GameFlow.seedCollection
            seeded.save()
            self.store = seeded
        }
        stage = .title
    }

    /// Leave the title: draft if unlocked, otherwise straight to a run with
    /// the whole collection (R9).
    func begin() {
        stage = Draft.isUnlocked(collection: store.collection) ? .draft
            : .run(Draft(picks: [], opener: nil))
    }

    /// The draftable pool the UI shows — player cards plus weapons.
    var draftableCards: [CardDef] {
        catalog.player + catalog.weapons
    }

    /// Confirm the draft and enter the run.
    func confirm(_ draft: Draft) {
        stage = .run(draft)
    }

    /// A fresh scene per run (KTD-4); the run reports its result back once.
    func makeScene(for draft: Draft, seed: UInt64) -> RunScene {
        let scene = RunScene(draft: draft, collection: store.collection,
                             seed: seed) { [weak self] result in
            self?.finishRun(result)
        }
        scene.scaleMode = .resizeFill
        return scene
    }

    /// Bank the run's shards and best distance, then show the obituary.
    func finishRun(_ result: RunResult) {
        store.record(result)
        stage = .results(result)
    }

    /// The obituary leads to the Reliquary to spend shards (R19).
    func toReliquary() {
        stage = .reliquary
    }

    /// One pull: spend shards, draw from the seeded catalog, persist.
    func pull() {
        guard store.shards >= Collection.pullCost else { return }
        var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))
        var rel = Collection(pool: draftableCards, owned: store.collection)
        let drawn = rel.pull(using: &rng)
        store.spendShards(Collection.pullCost)
        store.addToCollection(drawn)
    }

    /// Back to the draft for another run.
    func nextDraft() {
        stage = Draft.isUnlocked(collection: store.collection) ? .draft
            : .run(Draft(picks: [], opener: nil))
    }

    /// Cold-start collection: a small subset of the draftable pool (R9's
    /// sub-13 path), so pulls unlock cards and the draft appears at 13+.
    static let seedCollection: [String: Int] = [
        "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2,
        "the_thurible": 1,
    ]
}
