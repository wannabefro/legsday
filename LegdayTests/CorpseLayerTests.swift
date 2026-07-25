import Foundation
import Testing
import SpriteKit
@testable import Legday

/// KTD-3: the corpse layer is capped (oldest culled) and culls debris that
/// falls into the fog. Cosmetic-only; nothing flows back to the sim.
struct CorpseLayerTests {
    @MainActor
    @Test func capNeverExceededOldestCulled() {
        let parent = SKNode()
        let layer = CorpseLayer(parent: parent, texture: SKTexture(), cap: 5)
        for _ in 0..<20 {
            layer.spawn(at: .zero, elite: false, impulse: .zero)
        }
        #expect(layer.count == 5)
        #expect(parent.children.count == 5) // recycled from the tree too
    }

    @MainActor
    @Test func cullRemovesCorpsesBelowLine() {
        let parent = SKNode()
        let layer = CorpseLayer(parent: parent, texture: SKTexture(), cap: 10)
        layer.spawn(at: CGPoint(x: 0, y: 100), elite: false, impulse: .zero)
        layer.spawn(at: CGPoint(x: 0, y: -30), elite: false, impulse: .zero)
        layer.cull(belowY: 0)
        #expect(layer.count == 1) // only the y=100 corpse survives
    }
}
