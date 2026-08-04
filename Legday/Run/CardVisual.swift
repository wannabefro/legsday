import SpriteKit
import LegdaySim

/// The dealt Fate Card: parchment body, spine, title, and both sides with their
/// prices. The drag fills toward the commit threshold rather than snapping a
/// highlight on, so what the card shows cannot disagree with what commits (R22).
final class CardVisual: SKNode {
    private static let size = CGSize(width: 290, height: 196)
    private static let radius: CGFloat = 12

    private let body = SKShapeNode(rectOf: CardVisual.size, cornerRadius: CardVisual.radius)
    private let crop = SKCropNode()
    private let fill = SKShapeNode(rectOf: CardVisual.size)
    private let spine = SKShapeNode(rectOf: CGSize(width: 258, height: 4))
    private let title = CardVisual.text(size: 20, bold: true)
    private let deathTag = CardVisual.text(size: 12, bold: false)
    private let leftLabel = CardVisual.text(size: 16, bold: false)
    private let rightLabel = CardVisual.text(size: 16, bold: false)
    private let leftPrice = CardVisual.text(size: 14, bold: false)
    private let rightPrice = CardVisual.text(size: 14, bold: false)
    private let takeMark = CardVisual.text(size: 11, bold: true)
    private let holdHint = CardVisual.text(size: 12, bold: false)
    private let holdTrack = SKShapeNode(rectOf: CGSize(width: 120, height: 2), cornerRadius: 1)
    private let holdFill = SKShapeNode(rectOf: CGSize(width: 120, height: 2), cornerRadius: 1)

    private static let ink = PlaceholderAtlas.rgb(0x241C12)
    private static let dormant = PlaceholderAtlas.rgb(0x6B5A3D)
    private static let priceIdle = PlaceholderAtlas.rgb(0x8C7A57)
    private static let priceLit = PlaceholderAtlas.rgb(0x7A2E1E)
    private static let gold = PlaceholderAtlas.rgb(0xC99A2E)

    override init() {
        super.init()
        body.fillColor = PlaceholderAtlas.rgb(0xE9DCBC)
        body.strokeColor = SKColor(white: 0.14, alpha: 0.45)
        body.lineWidth = 1

        let mask = SKShapeNode(rectOf: CardVisual.size, cornerRadius: CardVisual.radius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        fill.strokeColor = .clear
        fill.fillColor = CardVisual.gold
        crop.addChild(fill)
        crop.zPosition = 1
        body.addChild(crop)

        spine.position = CGPoint(x: 0, y: 90)
        title.position = CGPoint(x: 0, y: 54)
        deathTag.position = CGPoint(x: 0, y: 34)
        deathTag.fontColor = CardVisual.dormant
        leftLabel.position = CGPoint(x: -127, y: -38)
        leftLabel.horizontalAlignmentMode = .left
        rightLabel.position = CGPoint(x: 127, y: -38)
        rightLabel.horizontalAlignmentMode = .right
        leftPrice.position = CGPoint(x: -127, y: -56)
        leftPrice.horizontalAlignmentMode = .left
        rightPrice.position = CGPoint(x: 127, y: -56)
        rightPrice.horizontalAlignmentMode = .right
        takeMark.position = CGPoint(x: 0, y: 74)
        takeMark.fontColor = CardVisual.priceLit
        holdHint.position = CGPoint(x: 0, y: -74)
        holdHint.fontColor = CardVisual.dormant
        holdTrack.position = CGPoint(x: 0, y: -88)
        holdTrack.fillColor = SKColor(white: 0.14, alpha: 0.2)
        holdTrack.strokeColor = .clear
        holdFill.fillColor = CardVisual.gold
        holdFill.strokeColor = .clear
        holdTrack.addChild(holdFill)

        for n in [spine, title, deathTag, leftLabel, rightLabel,
                  leftPrice, rightPrice, takeMark, holdHint, holdTrack] {
            n.zPosition = 2
            body.addChild(n)
        }
        addChild(body)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(card: ActiveCard?, offer: CardOffer?, sceneSize: CGSize) {
        guard let card else {
            body.isHidden = true
            return
        }
        body.isHidden = false

        let risen = 0.4 * sceneSize.height - (1 - CGFloat(card.rise)) * 240
        body.position = CGPoint(x: sceneSize.width / 2 + CGFloat(card.offset), y: risen)
        body.zRotation = CGFloat(card.tilt)

        spine.fillColor = Self.spineColor(card.def.spine)
        spine.strokeColor = .clear
        title.text = card.def.title
        deathTag.text = card.deathDealt ? "your deck is spent — Death deals" : ""

        let left = offer?.left ?? card.def.left
        let right = offer?.right ?? card.def.right
        leftLabel.text = "← \(left.label)"
        rightLabel.text = "\(right.label) →"
        leftPrice.text = left.subtitle
        rightPrice.text = right.subtitle

        updateDragFill(card: card, sceneWidth: sceneSize.width)
        updateSignature(card: card, offer: offer)
    }

    /// The fill tracks the thumb to the commit threshold, then locks. Only a
    /// locked side is bold, so the card never claims a side it will not take.
    private func updateDragFill(card: ActiveCard, sceneWidth: CGFloat) {
        let threshold = sceneWidth * CGFloat(RunSim.commitThreshold)
        let travel = min(1, abs(CGFloat(card.offset)) / max(threshold, 1))
        let locked = travel >= 1
        let toLeft = card.offset < 0

        if abs(card.offset) < 0.5 {
            fill.isHidden = true
        } else {
            fill.isHidden = false
            let w = Self.size.width * travel
            fill.xScale = max(travel, 0.001)
            fill.position = CGPoint(x: toLeft ? -(Self.size.width - w) / 2
                                             : (Self.size.width - w) / 2, y: 0)
            fill.alpha = locked ? 0.30 : 0.16
        }

        let lLit = locked && toLeft, rLit = locked && !toLeft
        leftLabel.fontColor = lLit ? Self.ink : Self.dormant
        rightLabel.fontColor = rLit ? Self.ink : Self.dormant
        leftPrice.fontColor = lLit ? Self.priceLit : Self.priceIdle
        rightPrice.fontColor = rLit ? Self.priceLit : Self.priceIdle
        takeMark.text = locked && !card.committing ? "RELEASE TO TAKE" : ""
    }

    /// A tier-3 weapon arms its signature after `RunSim.holdArm` of stillness.
    /// The bar is that progress — the sim tracked it and nothing drew it.
    private func updateSignature(card: ActiveCard, offer: CardOffer?) {
        guard let sig = offer?.signature else {
            holdHint.isHidden = true
            holdTrack.isHidden = true
            return
        }
        holdHint.isHidden = false
        holdTrack.isHidden = false
        let armed = card.signatureArmed
        holdHint.text = armed ? "⟡ armed — release to swing" : "⟡ hold — \(sig.label)"
        holdHint.fontColor = armed ? Self.gold : Self.dormant
        let k = min(1, CGFloat(card.holdTime / RunSim.holdArm))
        holdFill.xScale = max(k, 0.001)
        holdFill.position = CGPoint(x: -60 + 60 * k, y: 0)
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
        l.fontColor = ink
        l.verticalAlignmentMode = .center
        return l
    }
}
