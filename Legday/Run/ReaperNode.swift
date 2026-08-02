import SpriteKit
import LegdaySim

/// U23 presentation over U19's duel state: the Reaper silhouette and its
/// telegraphs. Placeholder shapes, same pipeline as U7.
final class ReaperNode: SKNode {
    private let body = SKSpriteNode()
    private let telegraphLine = SKShapeNode()
    private let telegraphRing = SKShapeNode(circleOfRadius: 30)
    private let arena = SKShapeNode()

    override init() {
        super.init()
        body.color = PlaceholderAtlas.rgb(0x241C12)
        body.colorBlendFactor = 1
        body.size = CGSize(width: 34, height: 84)
        body.position = .zero
        addChild(body)

        telegraphLine.strokeColor = SKColor(white: 0.9, alpha: 0.5)
        telegraphLine.lineWidth = 2
        telegraphRing.strokeColor = PlaceholderAtlas.rgb(0xC99A2E)
        telegraphRing.lineWidth = 2
        telegraphRing.fillColor = .clear
        telegraphRing.isHidden = true
        addChild(telegraphLine)
        addChild(telegraphRing)

        arena.fillColor = SKColor(white: 0.05, alpha: 0.35)
        arena.strokeColor = SKColor(white: 0.6, alpha: 0.25)
        arena.lineWidth = 1
        arena.isHidden = true
        addChild(arena)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Mirror the duel state onto the silhouette and telegraphs.
    func update(duel: DuelState, fogTopY: CGFloat, sceneSize: CGSize) {
        isHidden = false
        body.position = pt(duel.reaperPos, size: sceneSize)

        // Per-phase decay: later phases crack and fade the silhouette.
        let decay: CGFloat = [1.0, 0.75, 0.5][max(0, min(2, duel.phase - 1))]
        body.alpha = decay
        body.setScale(1 + CGFloat(duel.phase - 1) * 0.12)
        body.color = decay > 0.6 ? PlaceholderAtlas.rgb(0x241C12)
            : PlaceholderAtlas.rgb(0x3A2A1E)

        // Telegraph: a ring at the Reaper and a line to the hero for the windup.
        if let pattern = duel.telegraph {
            telegraphRing.isHidden = false
            telegraphRing.strokeColor = color(for: pattern)
            telegraphLine.isHidden = false
            let path = CGMutablePath()
            path.move(to: pt(duel.reaperPos, size: sceneSize))
            path.addLine(to: CGPoint(x: sceneSize.width / 2,
                                     y: sceneSize.height - 300))
            telegraphLine.path = path
        } else {
            telegraphRing.isHidden = true
            telegraphLine.isHidden = true
        }

        // The arena floor band.
        let a = duel.arena
        let y = sceneSize.height - CGFloat(a.maxY)
        let h = CGFloat(a.maxY - a.minY)
        arena.path = CGPath(rect: CGRect(x: CGFloat(a.minX), y: y,
                                         width: CGFloat(a.maxX - a.minX), height: h),
                            transform: nil)
        arena.isHidden = false
    }

    func hide() {
        isHidden = true
        telegraphRing.isHidden = true
        telegraphLine.isHidden = true
        arena.isHidden = true
    }

    private func pt(_ p: Vec2, size: CGSize) -> CGPoint {
        CGPoint(x: p.x, y: size.height - p.y)
    }

    private func color(for pattern: ReaperPattern) -> SKColor {
        switch pattern {
        case .sweep: return SKColor(white: 0.9, alpha: 0.6)
        case .slam: return PlaceholderAtlas.rgb(0xC99A2E)
        case .fogSurge: return PlaceholderAtlas.rgb(0x8A6FB3)
        }
    }
}
