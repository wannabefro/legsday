import SpriteKit
import LegdaySim

/// The air each zone carries. It drifts on its own clock, so the
/// world stops sliding as one image.
final class AirNode: SKNode {
    struct Air {
        let count: Int
        let color: Int
        /// Points per second. Negative rises.
        let fall: Double
        let drift: Double
        let size: Double
    }

    /// The prototype's shapes. Its counts and colours vanished against this
    /// channel, so both are lifted.
    static let byStageID: [String: Air] = [
        "low_road": Air(count: 34, color: 0x8C7A57, fall: 34, drift: 10, size: 2.2),
        "orchard": Air(count: 46, color: 0xA8BA48, fall: -22, drift: 26, size: 2.4),
        "ossuary": Air(count: 24, color: 0xA98CD4, fall: -8, drift: 6, size: 3.0),
        "spire": Air(count: 38, color: 0xE0B84A, fall: -40, drift: 8, size: 1.8),
        "reckoning": Air(count: 56, color: 0xB6AAC4, fall: 52, drift: 18, size: 2.0),
    ]

    private struct Speck {
        var node: SKSpriteNode
        var x: Double
        var y: Double
        var phase: Double
        var scale: Double
    }

    private var specks: [Speck] = []
    private var rng = SeededRandom(seed: 0xA1_2D0F)
    private var stageID = ""
    private let size: CGSize
    private lazy var dot = SpriteAtlas.circle(radius: 4, color: .white)

    init(sceneSize: CGSize) {
        size = sceneSize
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(state: RunState, dt: Double) {
        let air = Self.byStageID[state.stage.id] ?? Self.byStageID["low_road"]!
        if state.stage.id != stageID {
            stageID = state.stage.id
            reseed(air)
        }
        for i in specks.indices {
            var s = specks[i]
            s.phase += dt * 1.4
            s.y += air.fall * s.scale * dt
            s.x += sin(s.phase) * air.drift * dt
            if s.y < -20 { s.y = Double(size.height) + 16; s.x = rng.range(0, Double(size.width)) }
            if s.y > Double(size.height) + 20 { s.y = -16; s.x = rng.range(0, Double(size.width)) }
            s.node.position = CGPoint(x: s.x, y: Double(size.height) - s.y)
            s.node.alpha = CGFloat(0.26 + 0.34 * (0.5 + 0.5 * sin(s.phase)))
            specks[i] = s
        }
    }

    private func reseed(_ air: Air) {
        for s in specks { s.node.removeFromParent() }
        specks.removeAll(keepingCapacity: true)
        for _ in 0..<air.count {
            let node = SKSpriteNode(texture: dot)
            node.color = SpriteAtlas.rgb(air.color)
            node.colorBlendFactor = 1
            let scale = rng.range(0.6, 1.4)
            node.size = CGSize(width: air.size * scale * 2, height: air.size * scale * 2)
            Lighting.lit(node)
            addChild(node)
            specks.append(Speck(node: node, x: rng.range(0, Double(size.width)),
                                y: rng.range(0, Double(size.height)),
                                phase: rng.range(0, 6.283), scale: scale))
        }
    }
}
