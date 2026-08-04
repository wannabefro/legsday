import SpriteKit
import LegdaySim

/// Persistent HUD in the top safe area only (R5): essence, fathoms, felled,
/// fates remaining. A camera-independent scene child pinned to the top.
final class HudNode: SKNode {
    private let essenceLabel = HudNode.label(align: .left)
    private let fathomsLabel = HudNode.label(align: .center)
    private let statusLabel = HudNode.label(align: .right)
    /// What the cards have done to this run — the only readout of live mods.
    private let modsLabel = HudNode.label(align: .left)
    private let sceneSize: CGSize

    init(sceneSize: CGSize, safeTop: CGFloat) {
        self.sceneSize = sceneSize
        super.init()
        let y = sceneSize.height - safeTop - 24
        essenceLabel.position = CGPoint(x: 18, y: y)
        fathomsLabel.position = CGPoint(x: sceneSize.width / 2, y: y)
        statusLabel.position = CGPoint(x: sceneSize.width - 18, y: y)
        modsLabel.position = CGPoint(x: 18, y: y - 20)
        modsLabel.fontSize = 12
        modsLabel.fontColor = SKColor(red: 0.55, green: 0.50, blue: 0.38, alpha: 1)
        [essenceLabel, fathomsLabel, statusLabel, modsLabel].forEach(addChild)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(essence: Double, fathoms: Double, felled: Int, fates: Int, mods: Mods) {
        essenceLabel.text = "◈ \(Int(essence))"
        fathomsLabel.text = "\(Int(fathoms)) FATHOMS"
        statusLabel.text = "\(felled) felled · \(fates) fates"
        modsLabel.text = HudNode.modsSummary(mods)
    }

    /// Only what a card has changed. A run with no cards taken shows nothing.
    static func modsSummary(_ m: Mods) -> String {
        let base = Mods()
        var parts: [String] = []
        if m.bolts != base.bolts { parts.append("\(m.bolts) bolts") }
        if m.attackCooldown != base.attackCooldown {
            parts.append("atk \(pct(base.attackCooldown / m.attackCooldown))")
        }
        if m.footing != base.footing { parts.append("footing \(pct(m.footing))") }
        if m.magnet != base.magnet { parts.append("magnet \(pct(m.magnet / base.magnet))") }
        if m.gain != base.gain { parts.append("stride \(pct(m.gain))") }
        if m.essMul != base.essMul { parts.append("essence \(pct(m.essMul))") }
        if m.scrollMul != base.scrollMul { parts.append("scroll \(pct(m.scrollMul))") }
        if m.moteSink != base.moteSink { parts.append("sink \(pct(m.moteSink))") }
        if m.spawnMul != base.spawnMul { parts.append("spawns \(pct(m.spawnMul))") }
        if m.fogAdd != base.fogAdd { parts.append("fog \(signed(m.fogAdd))") }
        return parts.joined(separator: " · ")
    }

    private static func pct(_ x: Double) -> String {
        let d = (x - 1) * 100
        return "\(d >= 0 ? "+" : "")\(Int(d.rounded()))%"
    }

    private static func signed(_ x: Double) -> String {
        "\(x >= 0 ? "+" : "")\(Int(x.rounded()))"
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
