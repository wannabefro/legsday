import SpriteKit
import LegdaySim

/// The pool the lantern throws, under every figure. Two beating sines
/// flicker it, so it never settles into a disc.
final class LanternLight: SKNode {
    private static let radiusShare = 2.6

    private let pool: SKSpriteNode
    private let reach: Double

    init(bodyHeight: Double = 26) {
        reach = bodyHeight * Self.radiusShare
        pool = SKSpriteNode(texture: Self.gradient(radius: reach))
        pool.blendMode = .add
        super.init()
        addChild(pool)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(at position: CGPoint, time: Double) {
        let flicker = 0.86 + 0.14 * sin(time * 11.3) * sin(time * 4.1)
        pool.position = position
        pool.setScale(CGFloat(flicker))
    }

    /// Baked once: three stops of gold falling to nothing, as the prototype has.
    private static func gradient(radius: Double) -> SKTexture {
        let side = CGFloat(radius * 2)
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let colors = [
                UIColor(red: 0.788, green: 0.604, blue: 0.180, alpha: 0.30).cgColor,
                UIColor(red: 0.788, green: 0.604, blue: 0.180, alpha: 0.11).cgColor,
                UIColor(red: 0.788, green: 0.604, blue: 0.180, alpha: 0).cgColor,
            ]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0, 0.45, 1]) else { return }
            let centre = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                             endCenter: centre, endRadius: side / 2,
                                             options: [])
        }
        return SKTexture(image: image)
    }
}
