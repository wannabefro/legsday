import SpriteKit
import LegdaySim

/// U7 display-only Fate Card: the charge corner rising from the fog, and the
/// dealt card (parchment body, spine, title, L/R choices) tilting with the sim's
/// offset. U8 adds the touch interaction and the full CardNode treatment.
final class CardVisual: SKNode {
    private let charge = SKSpriteNode()
    private let body = SKShapeNode(rectOf: CGSize(width: 290, height: 172), cornerRadius: 12)
    private let spine = SKShapeNode(rectOf: CGSize(width: 258, height: 4))
    private let title = CardVisual.text(size: 17, bold: true)
    private let deathTag = CardVisual.text(size: 11, bold: false)
    private let leftLabel = CardVisual.text(size: 12, bold: false)
    private let rightLabel = CardVisual.text(size: 12, bold: false)
    private let holdHint = CardVisual.text(size: 11, bold: false) // tier-3 signature (U11)

    init(sceneSize: CGSize) {
        super.init()
        charge.texture = PlaceholderAtlas().cardCharge
        charge.zRotation = 0.12
        addChild(charge)

        body.fillColor = PlaceholderAtlas.rgb(0xE9DCBC)
        body.strokeColor = SKColor(white: 0.14, alpha: 0.45)
        body.lineWidth = 1
        spine.position = CGPoint(x: 0, y: 78)
        title.position = CGPoint(x: 0, y: 44)
        deathTag.position = CGPoint(x: 0, y: 26)
        deathTag.fontColor = PlaceholderAtlas.rgb(0x6B5A3D)
        leftLabel.position = CGPoint(x: -127, y: -52)
        leftLabel.horizontalAlignmentMode = .left
        rightLabel.position = CGPoint(x: 127, y: -52)
        rightLabel.horizontalAlignmentMode = .right
        holdHint.position = CGPoint(x: 0, y: -72)
        holdHint.fontColor = PlaceholderAtlas.rgb(0x6B5A3D)
        [spine, title, deathTag, leftLabel, rightLabel, holdHint].forEach(body.addChild)
        addChild(body)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(card: ActiveCard?, offer: CardOffer?, charge chargeValue: Double,
                essNeed: Double, sceneSize: CGSize) {
        guard let card else {
            body.isHidden = true
            charge.isHidden = false
            let k = essNeed > 0 ? min(1, chargeValue / essNeed) : 0
            charge.position = CGPoint(x: sceneSize.width - 40, y: CGFloat(k) * 66 - 33)
            return
        }
        charge.isHidden = true
        body.isHidden = false

        let risen = 0.4 * sceneSize.height - (1 - CGFloat(card.rise)) * 240
        body.position = CGPoint(x: sceneSize.width / 2 + CGFloat(card.offset), y: risen)
        body.zRotation = CGFloat(card.tilt) // rotational-spring inertia (R20)

        spine.fillColor = Self.spineColor(card.def.spine)
        spine.strokeColor = .clear
        title.text = card.def.title
        deathTag.text = card.deathDealt ? "your deck is spent — Death deals" : ""

        // The offer resolves weapon forms/growth at deal time (U11); ordinary
        // cards pass their static L/R straight through.
        let left = offer?.left ?? card.def.left
        let right = offer?.right ?? card.def.right
        let w = sceneSize.width
        let lLit = card.offset < -w * 0.12, rLit = card.offset > w * 0.12
        leftLabel.text = "← \(left.label)"
        rightLabel.text = "\(right.label) →"
        leftLabel.fontColor = lLit ? PlaceholderAtlas.rgb(0x241C12) : PlaceholderAtlas.rgb(0x6B5A3D)
        rightLabel.fontColor = rLit ? PlaceholderAtlas.rgb(0x241C12) : PlaceholderAtlas.rgb(0x6B5A3D)

        if let sig = offer?.signature {
            holdHint.isHidden = false
            holdHint.text = "⟡ hold — \(sig.label)"
            holdHint.fontColor = card.signatureArmed
                ? PlaceholderAtlas.rgb(0xC99A2E) : PlaceholderAtlas.rgb(0x6B5A3D)
        } else {
            holdHint.isHidden = true
        }
    }

    private static func spineColor(_ spine: CardSpine) -> SKColor {
        switch spine {
        case .rust: return PlaceholderAtlas.rgb(0xC06430)
        case .gold: return PlaceholderAtlas.rgb(0xC99A2E)
        case .grave: return PlaceholderAtlas.rgb(0x8A6FB3)
        case .plague: return PlaceholderAtlas.rgb(0x8FA03A)
        case .inkspine: return PlaceholderAtlas.rgb(0x050303)
        }
    }

    private static func text(size: CGFloat, bold: Bool) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: bold ? "Georgia-Bold" : "Georgia")
        l.fontSize = size
        l.fontColor = PlaceholderAtlas.rgb(0x241C12)
        l.verticalAlignmentMode = .center
        return l
    }
}
