import SpriteKit

/// Essence charging the next Fate Card. A fixed rail with a visible empty state,
/// anchored inside the safe area — the previous indicator was positioned across
/// the raw scene edge and stayed fully off-screen below half charge.
final class ChargeTrack: SKNode {
    private static let width: CGFloat = 10
    private static let height: CGFloat = 120

    private let track = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                    cornerRadius: width / 2)
    private let fill = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                   cornerRadius: width / 2)
    private let corner: SKSpriteNode

    init(sceneSize: CGSize, safeBottom: CGFloat, cornerTexture: SKTexture) {
        corner = SKSpriteNode(texture: cornerTexture)
        super.init()
        let x = sceneSize.width - 18 - Self.width / 2
        let y = safeBottom + 26 + Self.height / 2
        position = CGPoint(x: x, y: y)

        track.fillColor = SKColor(red: 0.69, green: 0.63, blue: 0.49, alpha: 0.13)
        track.strokeColor = SKColor(red: 0.69, green: 0.63, blue: 0.49, alpha: 0.30)
        track.lineWidth = 1
        fill.fillColor = SpriteAtlas.rgb(0xC99A2E)
        fill.strokeColor = .clear
        corner.setScale(0.36)
        corner.zRotation = 0.12
        corner.position = CGPoint(x: 0, y: Self.height / 2 + 20)
        corner.isHidden = true

        addChild(track)
        addChild(fill)
        addChild(corner)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// `charge` toward `need`. At full the card corner rises, which is the one
    /// moment that sprite was ever legible.
    func update(charge: Double, need: Double, cardUp: Bool) {
        let k = need > 0 ? CGFloat(min(1, max(0, charge / need))) : 0
        fill.yScale = max(k, 0.001)
        // Anchored at the base of the track, so it grows upward.
        fill.position = CGPoint(x: 0, y: -Self.height / 2 + Self.height * k / 2)
        fill.alpha = k >= 1 ? 1 : 0.85
        corner.isHidden = !cardUp
        isHidden = cardUp && k <= 0
    }
}
