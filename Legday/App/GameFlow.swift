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
    /// Last pulled relic and its reveal state — held here so the Reliquary
    /// view (recreated on store change) keeps the banner.
    var lastPull: String?
    var revealShown = false
    private var revealTask: Task<Void, Never>?

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

    /// Pulls left until the pity guarantee forces a new relic (R19).
    var pullsToGuarantee: Int {
        max(0, Collection.pityGuarantee - store.pity)
    }

    /// One pull: spend shards, draw, persist; returns the drawn card id.
    /// The pity counter is carried in and back out, or the guarantee never fires.
    func pull() -> String {
        guard store.shards >= Collection.pullCost else { return "" }
        var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))
        var rel = Collection(pool: draftableCards, owned: store.collection,
                             pity: store.pity)
        let drawn = rel.pull(using: &rng)
        lastPull = drawn
        revealShown = true
        store.spendShards(Collection.pullCost)
        store.pity = rel.pity
        store.addToCollection(drawn)
        revealTask?.cancel()
        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            self?.revealShown = false
        }
        return drawn
    }

    /// Dismiss the pull reveal early (navigation away).
    func dismissReveal() {
        revealTask?.cancel()
        revealShown = false
    }

    /// Back to the draft for another run.
    func nextDraft() {
        stage = Draft.isUnlocked(collection: store.collection) ? .draft
            : .run(Draft(picks: [], opener: nil))
    }

    /// Cold-start collection: a subset of the draftable pool (R9 sub-13), so
    /// pulls unlock cards and the draft appears at 13+.
    static let seedCollection: [String: Int] = [
        "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2,
        "the_thurible": 1,
    ]

#if DEBUG
    /// Testing seam: own every draftable card at max tier and bank shards, so a
    /// playtest reaches the draft, the weapons and the Reliquary without grinding.
    func debugUnlockAll() {
        for c in draftableCards { store.collection[c.id] = Collection.maxTier }
        store.shards += Collection.pullCost * 25
        store.save()
    }

    /// Testing seam: back to the cold start, to replay the sub-13 gate.
    func debugResetProgress() {
        store.collection = GameFlow.seedCollection
        store.shards = 0
        store.bestFathoms = 0
        store.save()
    }

    /// Testing seam: the Reliquary is normally only reachable after a run.
    func debugToReliquary() {
        stage = .reliquary
    }
#endif
}