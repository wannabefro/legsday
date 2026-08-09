import SpriteKit
import LegdaySim

/// The floor is what the place is made of, scrolling. Marks recycle above the top.
final class FloorNode: SKNode {
    private struct Mark {
        var node: SKSpriteNode
        var terrainY: Double
        var x: Double
        var width: Double
    }

    private var marks: [Mark] = []
    private var cache: [String: SKTexture] = [:]
    private var lastMaterial: ZoneLook.Material?

    init(sceneSize: CGSize, count: Int = 26) {
        super.init()
        var seed = SeededRandom(seed: 0xF100_0000)
        for _ in 0..<count {
            let node = SKSpriteNode()
            addChild(node)
            marks.append(Mark(node: node,
                              terrainY: seed.range(0, sceneSize.height),
                              x: seed.range(0, sceneSize.width),
                              width: seed.range(34, 88)))
            node.zRotation = CGFloat(seed.range(0, 6.28))
            node.alpha = seed.range(0.10, 0.30)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(state: RunState, sceneSize: CGSize) {
        let look = ZoneLook.of(state.stage)
        if look.floor != lastMaterial {
            lastMaterial = look.floor
            let tex = texture(look.floor)
            for m in marks { m.node.texture = tex }
        }
        for i in marks.indices {
            var m = marks[i]
            let y = sceneSize.height - (state.worldY + sceneSize.height - m.terrainY)
            if y < -m.width {
                m.terrainY += Double(marks.count) * 44
                marks[i] = m
                continue
            }
            m.node.position = CGPoint(x: m.x, y: y)
            m.node.size = CGSize(width: m.width, height: m.width)
        }
    }

    private func texture(_ material: ZoneLook.Material) -> SKTexture? {
        if let hit = cache[material.rawValue] { return hit }
        let baked = SpriteAtlas.baked(material.sprite, tint: nil)
        cache[material.rawValue] = baked
        return baked
    }
}
