import SpriteKit
import LegdaySim

/// The Pilgrim as a sliced rig: a solid hood disc, and a cloak of
/// twelve sprung wedges around it.
final class PilgrimNode: SKNode {
    /// Fractions of body height: the solid core, and how far a wedge may reach.
    private static let coreRadius = 0.26
    private static let outerRadius = 1.60
    private static let wedgePad = 0.055
    /// Where the hood sits in the drawing. Every wedge turns about this point.
    private static let pivot = CGPoint(x: 0.513, y: 0.360)

    private let body = SKNode()
    private var wedges: [SKCropNode] = []
    private var wedgeSprites: [SKSpriteNode] = []
    private let core = SKCropNode()
    private let coreSprite: SKSpriteNode
    private let height: Double

    init(texture: SKTexture?, height: Double = 26) {
        self.height = height
        coreSprite = SKSpriteNode(texture: texture)
        super.init()
        addChild(body)

        let size = Self.fit(texture: texture, height: height)
        let half = Double.pi / Double(CloakRig.wedgeCount)
        for i in 0..<CloakRig.wedgeCount {
            let phi = (Double(i) + 0.5) * (2 * .pi / Double(CloakRig.wedgeCount)) - .pi
            let crop = SKCropNode()
            crop.maskNode = Self.sectorMask(phi: phi, half: half, height: height)
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = size
            sprite.position = Self.offset(size: size)
            crop.addChild(sprite)
            body.addChild(crop)
            wedges.append(crop)
            wedgeSprites.append(sprite)
        }

        let disc = SKShapeNode(circleOfRadius: CGFloat(height * Self.coreRadius))
        disc.fillColor = .white
        disc.strokeColor = .clear
        core.maskNode = disc
        coreSprite.size = size
        coreSprite.position = Self.offset(size: size)
        core.addChild(coreSprite)
        core.zPosition = 1
        body.addChild(core)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(hero: RunState.Hero, time: Double, texture: SKTexture?, alpha: CGFloat) {
        if coreSprite.texture !== texture {
            coreSprite.texture = texture
            for s in wedgeSprites { s.texture = texture }
        }
        self.alpha = alpha
        zRotation = CGFloat(-(hero.heading + hero.lean + hero.aim))

        // Never perfectly still, and the stride swells the body as it lands.
        let gait = min(1, hero.stride * 4)
        let breath = 1 + sin(time * 2.1) * 0.012 * (1 - gait)
        let bob = 1 + sin(hero.stride * 6.2832 * 2) * 0.055 * gait
        body.zRotation = CGFloat(sin(hero.stride * 6.2832) * 0.05 * gait)
        body.xScale = CGFloat(breath)
        body.yScale = CGFloat(bob * breath)

        for (i, w) in cloakWedges.enumerated() where i < wedges.count {
            wedges[i].zRotation = CGFloat(-w.angle)
            wedgeSprites[i].setScale(CGFloat(w.stretch))
        }
    }

    /// Held here so `update` reads one snapshot rather than the whole state.
    var cloakWedges: [CloakRig.Wedge] = []

    /// Shift the drawing so its hood, not its bounding box, sits at the origin.
    private static func offset(size: CGSize) -> CGPoint {
        CGPoint(x: (0.5 - pivot.x) * size.width, y: (pivot.y - 0.5) * size.height)
    }

    private static func fit(texture: SKTexture?, height: Double) -> CGSize {
        guard let t = texture, t.size().height > 0 else {
            return CGSize(width: height, height: height)
        }
        let ratio = t.size().width / t.size().height
        return CGSize(width: height * ratio, height: height)
    }

    /// An annulus sector: the window this wedge of fabric is drawn through.
    private static func sectorMask(phi: Double, half: Double, height: Double) -> SKShapeNode {
        let inner = height * coreRadius * 0.92, outer = height * outerRadius
        // Sim angles run clockwise (y down); the scene's run counter-clockwise.
        let from = -phi - half - wedgePad, to = -phi + half + wedgePad
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: CGFloat(inner),
                    startAngle: CGFloat(from), endAngle: CGFloat(to), clockwise: false)
        path.addArc(center: .zero, radius: CGFloat(outer),
                    startAngle: CGFloat(to), endAngle: CGFloat(from), clockwise: true)
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = .white
        node.strokeColor = .clear
        return node
    }
}
