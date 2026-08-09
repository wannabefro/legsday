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
    private var relic = SKSpriteNode()
    private var relicTerrainY = 0.0
    private var relicRng = SeededRandom(seed: 0xFA11_E4)
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
            node.alpha = seed.range(0.16, 0.40)
        }
        relic.texture = SpriteAtlas.baked("fallen-pilgrim", tint: nil)
        relic.size = CGSize(width: 62, height: 62)
        relic.alpha = 0.42
        relic.isHidden = true
        addChild(relic)
        relicTerrainY = sceneSize.height + 400
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
        updateRelic(state: state, sceneSize: sceneSize)
    }

    /// One body at a time, far apart, so finding one still means something.
    private func updateRelic(state: RunState, sceneSize: CGSize) {
        let y = sceneSize.height - (state.worldY + sceneSize.height - relicTerrainY)
        if y < -120 {
            relicTerrainY += relicRng.range(1_400, 3_600)
            let edges = state.gorge.edges(at: relicTerrainY)
            relic.position.x = CGFloat(relicRng.range(edges.left + 40, edges.right - 40))
            relic.zRotation = CGFloat(relicRng.range(0, 6.28))
            relic.isHidden = false
            return
        }
        relic.position.y = CGFloat(y)
    }

    private func texture(_ material: ZoneLook.Material) -> SKTexture? {
        if let hit = cache[material.rawValue] { return hit }
        let baked = SpriteAtlas.baked(material.sprites[0], tint: nil)
        cache[material.rawValue] = baked
        return baked
    }
}
