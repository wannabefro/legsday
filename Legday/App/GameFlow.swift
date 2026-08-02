import SwiftUI
import SpriteKit
import LegdaySim

/// KTD-6 shell split: SwiftUI meta screens, SpriteKit run. GameFlow owns
/// navigation; U20/U22 extend it with results, title, and persistence.
@MainActor
@Observable
final class GameFlow {
    enum Stage: Equatable {
        case draft
        case run(Draft)
    }

    /// The collection of owned cards (id → copies). Seeded until U20's Store
    /// and U21's Reliquary provide persistence.
    var collection: [String: Int]
    /// The card content a run plays from (bundled cards.json, U10).
    let catalog: CardCatalog
    private(set) var stage: Stage = .draft

    init(collection: [String: Int] = GameFlow.seedCollection,
         catalog: CardCatalog = (try? CardCatalog.bundled()) ?? .seed) {
        self.collection = collection
        self.catalog = catalog
        if Draft.isUnlocked(collection: collection) {
            stage = .draft
        } else {
            stage = .run(Draft(picks: [], opener: nil)) // sub-13: whole collection
        }
    }

    /// The draftable pool the UI shows — player cards plus weapons.
    var draftableCards: [CardDef] {
        catalog.player + catalog.weapons
    }

    /// Confirm the draft and enter the run.
    func confirm(_ draft: Draft) {
        stage = .run(draft)
    }

    /// The scene for the current stage. Created per run (never reused) so each
    /// run gets a fresh sim (KTD-4).
    func makeScene(for draft: Draft, seed: UInt64) -> RunScene {
        let scene = RunScene(draft: draft, collection: collection, seed: seed)
        scene.scaleMode = .resizeFill
        return scene
    }

    /// Seed collection: enough cards to unlock the draft (13+) and include
    /// weapon variety. Placeholder until U20/U21.
    static let seedCollection: [String: Int] = [
        "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2,
        "pilgrims_pace": 2, "the_tithe": 2,
        "the_thurible": 1, "the_passing_bell": 1, "the_wild_chain": 1,
    ]
}
