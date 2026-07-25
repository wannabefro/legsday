import SpriteKit

/// An id-keyed sprite pool (KTD-4). Syncing to a stable set of ids performs no
/// allocation; sprites whose id vanishes are removed from the tree and recycled
/// for the next new id. This is what keeps foe/mote churn from allocating.
final class NodePool {
    private var active: [Int: SKSpriteNode] = [:]
    private var idle: [SKSpriteNode] = []
    private let parent: SKNode
    private let make: () -> SKSpriteNode

    /// Total sprites ever created — flat in steady state (debug/test probe).
    private(set) var allocationCount = 0

    init(parent: SKNode, make: @escaping () -> SKSpriteNode) {
        self.parent = parent
        self.make = make
    }

    var activeCount: Int { active.count }

    /// Sync the pool to `items`, running `configure` for each. Nodes for ids no
    /// longer present are recycled.
    func sync<Item>(_ items: [Item], id: (Item) -> Int, configure: (Item, SKSpriteNode) -> Void) {
        var seen = Set<Int>()
        seen.reserveCapacity(items.count)
        for item in items {
            let key = id(item)
            seen.insert(key)
            let node = active[key] ?? dequeue()
            active[key] = node
            configure(item, node)
        }
        for (key, node) in active where !seen.contains(key) {
            node.removeFromParent()
            idle.append(node)
            active.removeValue(forKey: key)
        }
    }

    private func dequeue() -> SKSpriteNode {
        if let recycled = idle.popLast() {
            parent.addChild(recycled)
            return recycled
        }
        allocationCount += 1
        let node = make()
        parent.addChild(node)
        return node
    }
}
