import SpriteKit

/// The cosmetic corpse layer — the *only* `SKPhysicsWorld` user (KTD-3). Kill
/// events spawn capped, culled debris that tumbles under gravity; nothing flows
/// back into the sim. The visible splash is the sim's own scheduled splash (U4),
/// so no data ever crosses from here into gameplay.
@MainActor
final class CorpseLayer {
    private let parent: SKNode
    private let texture: SKTexture
    private var corpses: [SKSpriteNode] = []
    private let cap: Int

    init(parent: SKNode, texture: SKTexture, cap: Int = 40) {
        self.parent = parent
        self.texture = texture
        self.cap = cap
    }

    var count: Int { corpses.count }

    /// Spawn a tumbling corpse; the oldest is culled once the cap is reached.
    func spawn(at pos: CGPoint, elite: Bool, impulse: CGVector) {
        if corpses.count >= cap { corpses.removeFirst().removeFromParent() }

        let node = SKSpriteNode(texture: texture)
        Lighting.lit(node)
        node.position = pos
        node.setScale(elite ? 1.6 : 1)
        let body = SKPhysicsBody(circleOfRadius: elite ? 15 : 9)
        body.affectedByGravity = true
        body.categoryBitMask = 0
        body.collisionBitMask = 0     // corpses collide with nothing
        body.contactTestBitMask = 0
        body.angularDamping = 0.2
        node.physicsBody = body
        parent.addChild(node)
        corpses.append(node)
        body.applyImpulse(impulse)
        body.applyAngularImpulse(elite ? 0.4 : 0.2)
    }

    /// Remove corpses that have fallen into the fog (below `y`).
    func cull(belowY y: CGFloat) {
        corpses.removeAll { corpse in
            if corpse.position.y < y {
                corpse.removeFromParent()
                return true
            }
            return false
        }
    }
}
