import SpriteKit
import LegdaySim

/// The channel's furniture. A cairn is a stack, one slab per remaining hit,
/// so its health reads from its shape, never from its brightness.
final class FeatureNode: SKNode {
    private static let slabsPerCairn = 3

    private var briars: [SKSpriteNode] = []
    private var cairns: [SKNode] = []
    private let briarTexture: SKTexture?
    private let slabTexture: SKTexture?

    override init() {
        briarTexture = SpriteAtlas.baked("briar-bed", tint: SpriteAtlas.rgb(0x39421A))
        slabTexture = SpriteAtlas.baked("ground-slab", tint: SpriteAtlas.rgb(0x4A3626))
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(state: RunState) {
        var usedBriars = 0, usedCairns = 0
        for f in state.features {
            let p = CGPoint(x: f.x, y: f.terrainY - state.worldY)
            switch f.kind {
            case .briar:
                layBriar(&usedBriars, at: p, feature: f)
            case .cairn:
                stackCairn(&usedCairns, at: p, feature: f, time: state.time)
            }
        }
        for i in usedBriars..<briars.count { briars[i].isHidden = true }
        for i in usedCairns..<cairns.count { cairns[i].isHidden = true }
    }

    private func layBriar(_ used: inout Int, at p: CGPoint, feature: Feature) {
        let node: SKSpriteNode
        if used < briars.count {
            node = briars[used]
            node.isHidden = false
        } else {
            node = SKSpriteNode(texture: briarTexture)
            node.alpha = 0.5
            Lighting.lit(node)
            addChild(node)
            briars.append(node)
        }
        used += 1
        node.position = p
        node.zRotation = CGFloat(feature.rotation)
        node.size = CGSize(width: feature.extent * 2.2, height: feature.extent * 2.2)
    }

    private func stackCairn(_ used: inout Int, at p: CGPoint, feature: Feature, time: Double) {
        let node: SKNode
        if used < cairns.count {
            node = cairns[used]
            node.isHidden = false
        } else {
            node = SKNode()
            for _ in 0..<Self.slabsPerCairn {
                let slab = SKSpriteNode(texture: slabTexture)
                Lighting.lit(slab)
                node.addChild(slab)
            }
            addChild(node)
            cairns.append(node)
        }
        used += 1
        node.position = p
        node.zRotation = CGFloat(feature.rotation)
        node.alpha = time - feature.struckAt < Feature.strikeFlash ? 0.55 : 1

        let full = feature.extent * 2
        let scale = 0.55 + 0.15 * Double(feature.hp)
        for (i, slab) in node.children.enumerated() {
            guard let slab = slab as? SKSpriteNode else { continue }
            slab.isHidden = i >= feature.hp
            guard !slab.isHidden else { continue }
            let width = full * scale * 1.16 * (1 - Double(i) * 0.16)
            let lift = Double(i) * full * 0.10
            slab.position = CGPoint(x: -lift * 0.5, y: lift)
            slab.zRotation = CGFloat(Double(i) * 0.22)
            slab.zPosition = CGFloat(i)
            slab.size = CGSize(width: width, height: width * 0.82)
        }
    }
}
