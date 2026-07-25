import Foundation
import Testing
import SpriteKit
@testable import Legday

/// KTD-4: the node pool never allocates during steady state — a stable id set
/// reuses sprites, and a new id reuses a recycled one before allocating.
struct NodePoolTests {
    private struct Entity { let id: Int }

    @Test @MainActor func stableIdSetDoesNotAllocate() {
        let parent = SKNode()
        let pool = NodePool(parent: parent) { SKSpriteNode() }
        let items = [Entity(id: 1), Entity(id: 2), Entity(id: 3)]

        pool.sync(items, id: { $0.id }) { _, _ in }
        #expect(pool.allocationCount == 3)
        #expect(pool.activeCount == 3)

        // Same ids again — no new sprites.
        pool.sync(items, id: { $0.id }) { _, _ in }
        #expect(pool.allocationCount == 3)
    }

    @Test @MainActor func vanishedIdRecyclesForNewId() {
        let parent = SKNode()
        let pool = NodePool(parent: parent) { SKSpriteNode() }
        pool.sync([Entity(id: 1), Entity(id: 2), Entity(id: 3)], id: { $0.id }) { _, _ in }
        #expect(pool.allocationCount == 3)

        // One leaves (recycled), then a brand-new id reuses the idle sprite.
        pool.sync([Entity(id: 1), Entity(id: 2)], id: { $0.id }) { _, _ in }
        #expect(pool.activeCount == 2)
        pool.sync([Entity(id: 1), Entity(id: 2), Entity(id: 9)], id: { $0.id }) { _, _ in }
        #expect(pool.allocationCount == 3) // reused, no new allocation
        #expect(pool.activeCount == 3)
    }
}
