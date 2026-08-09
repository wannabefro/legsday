import SpriteKit
import LegdaySim

/// Persistent HUD in the top safe area only (R5): three readings, the live
/// modifiers, and the deck as pips.
final class HudNode: SKNode {
    private let essenceLabel = HudNode.label(align: .left)
    private let fathomsLabel = HudNode.label(align: .center)
    private let statusLabel = HudNode.label(align: .right)
    private let modsLabel = HudNode.label(align: .left)
    private let stageLabel = HudNode.label(align: .center)
    private let pips = SKNode()
    private let sceneSize: CGSize
    private let pipsY: CGFloat

    /// Ink on the strip, not parchment on the world.
    private static let muted = SKColor(red: 0.23, green: 0.17, blue: 0.11, alpha: 1)
    private static let dim = SKColor(red: 0.42, green: 0.32, blue: 0.22, alpha: 1)
    private let strip = SKShapeNode()

    init(sceneSize: CGSize, safeTop: CGFloat) {
        self.sceneSize = sceneSize
        self.pipsY = sceneSize.height - safeTop - 62
        super.init()
        let y = sceneSize.height - safeTop - 24
        essenceLabel.position = CGPoint(x: 18, y: y)
        fathomsLabel.position = CGPoint(x: sceneSize.width / 2, y: y)
        // The top row holds the pause button and a widening fathom count.
        statusLabel.position = CGPoint(x: sceneSize.width - 18, y: pipsY)
        modsLabel.position = CGPoint(x: 18, y: y - 20)
        modsLabel.fontSize = 12
        modsLabel.fontColor = Self.dim
        stageLabel.position = CGPoint(x: sceneSize.width / 2, y: pipsY - 16)
        stageLabel.fontSize = 12
        stageLabel.fontColor = Self.muted
        pips.position = CGPoint(x: 18, y: pipsY)
        // The run is an obituary being written, so the numbers live on a torn page.
        strip.path = Self.tornStrip(width: sceneSize.width,
                                    top: sceneSize.height,
                                    bottom: pipsY - 30)
        strip.fillColor = SpriteAtlas.rgb(0xE9DCBC).withAlphaComponent(0.90)
        strip.strokeColor = SpriteAtlas.rgb(0x17120E).withAlphaComponent(0.45)
        strip.lineWidth = 1
        strip.zPosition = -1
        addChild(strip)
        [essenceLabel, fathomsLabel, statusLabel, modsLabel, stageLabel, pips].forEach(addChild)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(essence: Double, fathoms: Double, felled: Int, mods: Mods,
                deck: DeckReading, stage: String) {
        // ✧ is essence, spent inside the run. ◈ is shards, which outlive it.
        essenceLabel.text = "✧ \(Int(essence))"
        fathomsLabel.text = "\(Int(fathoms)) FATHOMS"
        statusLabel.text = "\(felled) felled"
        modsLabel.text = HudNode.modsSummary(mods)
        stageLabel.text = stage
        syncPips(deck)
    }

    /// A parchment band whose lower edge is torn, never ruled.
    private static func tornStrip(width w: CGFloat, top: CGFloat, bottom: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: top))
        path.addLine(to: CGPoint(x: w, y: top))
        path.addLine(to: CGPoint(x: w, y: bottom))
        var seed = SeededRandom(seed: 0x7EA2_1000)
        var x = w
        while x > 0 {
            x -= 11
            path.addLine(to: CGPoint(x: max(0, x), y: bottom + seed.range(-5, 5)))
        }
        path.addLine(to: CGPoint(x: 0, y: bottom))
        path.closeSubpath()
        return path
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

    /// Rebuild the pip row: your remaining deck, the gate, then Death's cards.
    private func syncPips(_ d: DeckReading) {
        pips.removeAllChildren()
        var x: CGFloat = 0
        for i in 0..<d.deckSize {
            let spent = i >= d.remaining
            pips.addChild(Self.pip(at: x, spent: spent, death: false))
            x += 12
        }
        if d.deathSize > 0 {
            let gate = SKShapeNode(rectOf: CGSize(width: 1, height: 18))
            gate.fillColor = d.pastGate ? SpriteAtlas.rgb(0x7A2E1E) : Self.dim
            gate.strokeColor = .clear
            gate.position = CGPoint(x: x + 4, y: 0)
            pips.addChild(gate)
            x += 12
            for _ in 0..<d.deathSize {
                pips.addChild(Self.pip(at: x, spent: false, death: true))
                x += 12
            }
        }
    }

    private static func pip(at x: CGFloat, spent: Bool, death: Bool) -> SKShapeNode {
        let n = SKShapeNode(rectOf: CGSize(width: 9, height: 14), cornerRadius: 2)
        n.position = CGPoint(x: x, y: 0)
        if death {
            n.fillColor = SpriteAtlas.rgb(0x050303)
            n.strokeColor = muted.withAlphaComponent(0.45)
        } else if spent {
            n.fillColor = .clear
            n.strokeColor = muted.withAlphaComponent(0.3)
        } else {
            n.fillColor = muted.withAlphaComponent(0.85)
            n.strokeColor = .clear
        }
        n.lineWidth = 1
        return n
    }

    private static func label(align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "Georgia-Bold")
        l.fontSize = 16
        l.fontColor = muted
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
        return l
    }

    private static func pct(_ x: Double) -> String {
        let d = (x - 1) * 100
        return "\(d >= 0 ? "+" : "")\(Int(d.rounded()))%"
    }

    private static func signed(_ x: Double) -> String {
        "\(x >= 0 ? "+" : "")\(Int(x.rounded()))"
    }
}

/// What the HUD needs to draw the deck, gathered in one value.
struct DeckReading: Equatable {
    let deckSize: Int
    let remaining: Int
    let deathSize: Int
    let pastGate: Bool
}
