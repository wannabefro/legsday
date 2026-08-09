import SpriteKit
import LegdaySim

/// What a blow looks like. The sim decides who dies, this decides whether
/// it is felt. Cosmetic only (KTD-3).
@MainActor
enum StrikeLayer {
    private static let shardCount = 7
    private static let shardSpread = 0.30

    /// Seven ink shards along the shot axis, and one ring opening behind them.
    static func burst(in parent: SKNode, at p: CGPoint, along angle: CGFloat,
                      elite: Bool) {
        let scale: CGFloat = elite ? 1.5 : 1
        for i in 0..<shardCount {
            let heading = angle + CGFloat(i - shardCount / 2) * CGFloat(shardSpread)
            let shard = SKShapeNode(rectOf: CGSize(width: 11 * scale, height: 1.4))
            shard.fillColor = SpriteAtlas.rgb(0xE9DCBC)
            shard.strokeColor = .clear
            shard.zRotation = heading
            shard.position = CGPoint(x: p.x + cos(heading) * 6, y: p.y + sin(heading) * 6)
            shard.alpha = 0.75
            parent.addChild(shard)
            let travel = CGFloat.random(in: 26...44) * scale
            shard.run(.sequence([
                .group([
                    .moveBy(x: cos(heading) * travel, y: sin(heading) * travel, duration: 0.26),
                    .fadeOut(withDuration: 0.26),
                ]),
                .removeFromParent(),
            ]))
        }

        let ring = SKShapeNode(circleOfRadius: 6)
        ring.strokeColor = SpriteAtlas.rgb(0xC99A2E)
        ring.fillColor = .clear
        ring.lineWidth = 2.4
        ring.position = p
        ring.alpha = 0.6
        parent.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 7 * scale, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// The shot itself. Each weapon's form is already in the sim; only the
    /// drawing was shared.
    static func attack(in parent: SKNode, from a: CGPoint, to b: CGPoint,
                       weapon: String?) {
        switch weapon {
        case "the_thurible": arc(in: parent, from: a, to: b)
        case "the_passing_bell": ring(in: parent, at: a, reach: hypot(b.x - a.x, b.y - a.y))
        case "the_censer_rot": blot(in: parent, from: a, to: b)
        default: shaft(in: parent, from: a, to: b)
        }
    }

    /// Tapered, parchment, with a bright head. A line reads as a scratch.
    private static func shaft(in parent: SKNode, from a: CGPoint, to b: CGPoint) {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let line = SKShapeNode(path: path)
        line.strokeColor = SpriteAtlas.rgb(0xE9DCBC)
        line.lineWidth = 3
        line.lineCap = .round
        line.alpha = 0.95
        parent.addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))

        let head = SKShapeNode(circleOfRadius: 3)
        head.fillColor = SpriteAtlas.rgb(0xFFF6DE)
        head.strokeColor = .clear
        head.position = a
        parent.addChild(head)
        head.run(.sequence([
            .group([.move(to: b, duration: 0.07), .fadeOut(withDuration: 0.12)]),
            .removeFromParent(),
        ]))
    }

    /// A gold band sweeping across everything in front, fading behind itself.
    private static func arc(in parent: SKNode, from a: CGPoint, to b: CGPoint) {
        let heading = atan2(b.y - a.y, b.x - a.x)
        let reach = hypot(b.x - a.x, b.y - a.y)
        for i in 0..<4 {
            let lag = CGFloat(i) * 0.14
            let path = CGMutablePath()
            path.addArc(center: a, radius: reach,
                        startAngle: heading - 0.85 + lag, endAngle: heading - 0.45 + lag,
                        clockwise: false)
            let band = SKShapeNode(path: path)
            band.strokeColor = SpriteAtlas.rgb(0xC99A2E)
            band.lineWidth = CGFloat(7 - i)
            band.lineCap = .round
            band.alpha = 0.55 - CGFloat(i) * 0.11
            parent.addChild(band)
            band.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .fadeOut(withDuration: 0.22),
                .removeFromParent(),
            ]))
        }
    }

    /// A toll needs no target: one ring outward, thinning as it goes.
    private static func ring(in parent: SKNode, at a: CGPoint, reach: CGFloat) {
        for (i, width) in [4.0, 1.2].enumerated() {
            let node = SKShapeNode(circleOfRadius: 8)
            node.strokeColor = SpriteAtlas.rgb(0x8A6FB3)
            node.fillColor = .clear
            node.lineWidth = CGFloat(width)
            node.position = a
            node.alpha = i == 0 ? 0.85 : 0.35
            parent.addChild(node)
            node.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([.scale(to: max(2, reach / 8), duration: 0.34),
                        .fadeOut(withDuration: 0.34)]),
                .removeFromParent(),
            ]))
        }
    }

    /// A blot lobbed out, then a pool that breathes while it eats.
    private static func blot(in parent: SKNode, from a: CGPoint, to b: CGPoint) {
        let seed = SKShapeNode(circleOfRadius: 5.5)
        seed.fillColor = SpriteAtlas.rgb(0x8FA03A)
        seed.strokeColor = .clear
        seed.position = a
        parent.addChild(seed)
        seed.run(.sequence([.move(to: b, duration: 0.18), .removeFromParent()]))

        let pool = SKShapeNode(ellipseOf: CGSize(width: 58, height: 46))
        pool.fillColor = SpriteAtlas.rgb(0x8FA03A).withAlphaComponent(0.30)
        pool.strokeColor = SpriteAtlas.rgb(0x8FA03A).withAlphaComponent(0.5)
        pool.lineWidth = 1.2
        pool.position = b
        pool.alpha = 0
        pool.setScale(0.3)
        parent.addChild(pool)
        pool.run(.sequence([
            .wait(forDuration: 0.18),
            .group([.fadeIn(withDuration: 0.1), .scale(to: 1, duration: 0.14)]),
            .repeat(.sequence([.scale(to: 1.05, duration: 0.3),
                               .scale(to: 0.95, duration: 0.3)]), count: 3),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
    }
}
