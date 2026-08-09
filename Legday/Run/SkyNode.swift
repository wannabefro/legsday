import SpriteKit
import LegdaySim

/// Carrion birds, high above the gorge. They scroll slower, so the walls read as deep.
final class SkyNode: SKNode {
    private static let parallax = 0.34

    private let flock = SKSpriteNode()
    private var terrainY = 0.0
    private var driftX = 0.0
    private var rng = SeededRandom(seed: 0xB1_2D5)

    init(sceneSize: CGSize) {
        super.init()
        // A bird above the lantern is a silhouette, never a pale shape.
        flock.texture = SpriteAtlas.baked("carrion-birds", tint: SpriteAtlas.rgb(0x14100C))
        flock.size = CGSize(width: 130, height: 130)
        flock.alpha = 0.5
        addChild(flock)
        terrainY = sceneSize.height + 600
        driftX = sceneSize.width * 0.5
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(state: RunState, sceneSize: CGSize) {
        let y = sceneSize.height - (state.worldY * Self.parallax + sceneSize.height - terrainY)
        if y < -160 {
            terrainY += rng.range(900, 2_200)
            driftX = rng.range(60, sceneSize.width - 60)
            flock.zRotation = CGFloat(rng.range(-0.5, 0.5))
            return
        }
        flock.position = CGPoint(x: driftX + sin(state.time * 0.11) * 46, y: y)
    }
}
