import SpriteKit

/// U1 stub: an empty scene painted the graybox background (#0F0C0A). U7 fills
/// this with the sim sync/render layer, pooled sprites, fog surface, and HUD.
final class RunScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0x0F / 255.0, green: 0x0C / 255.0, blue: 0x0A / 255.0, alpha: 1)
    }
}
