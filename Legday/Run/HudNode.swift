import SpriteKit

/// Persistent HUD in the top safe area only (R5): essence, fathoms, felled,
/// fates remaining. A camera-independent scene child pinned to the top.
final class HudNode: SKNode {
    private let essenceLabel = HudNode.label(align: .left)
    private let fathomsLabel = HudNode.label(align: .center)
    private let statusLabel = HudNode.label(align: .right)
    private let sceneSize: CGSize

    init(sceneSize: CGSize, safeTop: CGFloat) {
        self.sceneSize = sceneSize
        super.init()
        let y = sceneSize.height - safeTop - 24
        essenceLabel.position = CGPoint(x: 18, y: y)
        fathomsLabel.position = CGPoint(x: sceneSize.width / 2, y: y)
        statusLabel.position = CGPoint(x: sceneSize.width - 18, y: y)
        [essenceLabel, fathomsLabel, statusLabel].forEach(addChild)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(essence: Double, fathoms: Double, felled: Int, fates: Int) {
        essenceLabel.text = "◈ \(Int(essence))"
        fathomsLabel.text = "\(Int(fathoms)) FATHOMS"
        statusLabel.text = "\(felled) felled · \(fates) fates"
    }

    private static func label(align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "Georgia-Bold")
        l.fontSize = 15
        l.fontColor = SKColor(red: 0.69, green: 0.63, blue: 0.49, alpha: 1) // #B0A17C
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
        return l
    }
}
