import SpriteKit
import LegdaySim

/// Two lights work against near-black ambient: the lantern, and the fog.
@MainActor
final class Lighting: SKNode {
    /// World sprites take the light. HUD, cards, motes and bolts stay flat.
    static let worldMask: UInt32 = 1

    private static let fogLightCount = 3
    private static let ambient = 0x1B1822
    private static let lanternHue = 0xFFE29E
    private static let fogHue = 0x8A6FB3
    private static let lanternFalloff: CGFloat = 2.5
    private static let fogFalloff: CGFloat = 1.0

    private let lantern = SKLightNode()
    private var fogLights: [SKLightNode] = []

    override init() {
        super.init()
        lantern.categoryBitMask = Self.worldMask
        lantern.ambientColor = SpriteAtlas.rgb(Self.ambient)
        lantern.lightColor = SpriteAtlas.rgb(Self.lanternHue)
        lantern.falloff = Self.lanternFalloff
        addChild(lantern)

        for _ in 0..<Self.fogLightCount {
            let light = SKLightNode()
            light.categoryBitMask = Self.worldMask
            light.ambientColor = .black   // ambient adds per light, so only one carries it
            light.lightColor = SpriteAtlas.rgb(Self.fogHue)
            light.falloff = Self.fogFalloff
            addChild(light)
            fogLights.append(light)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Three point lights stand in for one wide band along the fog line.
    func update(lanternAt p: CGPoint, fogTopY: CGFloat, sceneSize: CGSize, time: Double) {
        let flicker = 0.86 + 0.14 * sin(time * 11.3) * sin(time * 4.1)
        lantern.position = p
        lantern.lightColor = SpriteAtlas.rgb(Self.lanternHue)
            .withAlphaComponent(CGFloat(flicker))
        for (i, light) in fogLights.enumerated() {
            let share = (CGFloat(i) + 0.5) / CGFloat(Self.fogLightCount)
            light.position = CGPoint(x: sceneSize.width * share, y: fogTopY)
        }
    }

    /// Mark a sprite as taking the world's light.
    static func lit(_ node: SKSpriteNode) { node.lightingBitMask = worldMask }
}
