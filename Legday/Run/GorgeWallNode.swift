import SpriteKit
import LegdaySim

/// The two cliffs, drawn from the band function the sim clamps against.
final class GorgeWallNode: SKNode {
    private static let band = Gorge.bandHeight
    private static let tile = Gorge.bandHeight * 1.55

    private let deadRock = SKShapeNode()
    private var tiles: [SKSpriteNode] = []
    private var cache: [String: SKTexture] = [:]

    override init() {
        super.init()
        deadRock.strokeColor = .clear
        deadRock.lineWidth = 0
        addChild(deadRock)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func update(state: RunState, sceneSize: CGSize) {
        let look = ZoneLook.of(state.stage)
        let courses = look.depth + 1
        let first = Int((state.worldY / Self.band).rounded(.down)) - 1
        let count = Int(sceneSize.height / Self.band) + 3

        deadRock.fillColor = SpriteAtlas.rgb(0x1E1813)
        deadRock.path = rockPath(state: state, sceneSize: sceneSize, first: first, count: count)

        var used = 0
        for step in 0..<count {
            let terrainY = Double(first + step) * Self.band + Self.band / 2
            guard terrainY >= 0 else { continue }
            let e = state.gorge.edges(at: terrainY)
            let y = sceneSize.height - (state.worldY + sceneSize.height - terrainY)
            guard y > -Self.tile, y < sceneSize.height + Self.tile else { continue }

            for side in 0..<2 {
                let edge = side == 0 ? e.left : e.right
                let dir: Double = side == 0 ? -1 : 1
                for course in 0..<courses {
                    let x = edge + dir * (Double(course) * Self.tile * 0.62 + Self.tile * 0.30)
                    guard x > -Self.tile, x < sceneSize.width + Self.tile else { break }
                    place(&used, at: CGPoint(x: x, y: y), course: course,
                          look: look, seedIndex: first + step + side, time: state.time)
                }
            }
            // The island a fork puts between the two lanes.
            if let island = state.gorge.spine(at: terrainY) {
                let span = island.right - island.left
                let count = max(1, Int((span / (Self.tile * 0.62)).rounded()))
                for slot in 0..<count {
                    let x = island.left + span * (Double(slot) + 0.5) / Double(count)
                    place(&used, at: CGPoint(x: x, y: y), course: 0,
                          look: look, seedIndex: first + step + slot + 97, time: state.time)
                }
            }
        }
        for i in used..<tiles.count { tiles[i].isHidden = true }
    }

    private func place(_ used: inout Int, at p: CGPoint, course: Int,
                       look: ZoneLook, seedIndex: Int, time: Double) {
        let node: SKSpriteNode
        if used < tiles.count {
            node = tiles[used]
            node.isHidden = false
        } else {
            node = SKSpriteNode()
            Lighting.lit(node)
            addChild(node)
            tiles.append(node)
        }
        used += 1

        let variants = look.wall.sprites.count
        node.texture = texture(look.wall, rock: look.rock,
                               variant: abs(seedIndex &+ course &* 7) % variants)
        let rest = Double(seedIndex &* 2_654_435_761 % 628) / 100
        // Rock and masonry hold still. Mist and briar are not rock.
        switch look.wall {
        case .masonry:
            node.position = p
            node.zRotation = 0                      // it was built, so it is not tumbled
            node.size = CGSize(width: Self.tile * 0.92, height: Self.band * 0.98)
            node.alpha = course == 0 ? 0.90 : 0.55
        case .fog:
            let breath = sin(time * 0.42 + rest)
            node.position = CGPoint(x: p.x + CGFloat(breath) * 7, y: p.y)
            node.zRotation = CGFloat(rest + breath * 0.06)
            node.size = CGSize(width: Self.tile * 1.4, height: Self.tile * 1.4)
            node.alpha = CGFloat(0.28 + 0.12 * (0.5 + 0.5 * sin(time * 0.63 + rest)))
        case .briar:
            node.position = p
            node.zRotation = CGFloat(rest + sin(time * 1.1 + rest) * 0.035)
            node.size = CGSize(width: Self.tile, height: Self.tile)
            node.alpha = Self.courseAlpha(course)
        default:
            node.position = p
            node.zRotation = CGFloat(rest)
            node.size = CGSize(width: Self.tile, height: Self.tile)
            node.alpha = Self.courseAlpha(course)
        }
    }

    /// The lip is the boundary you must not cross, so it reads. The mass
    /// behind it recedes.
    private static func courseAlpha(_ course: Int) -> CGFloat {
        max(0.32, 0.88 - CGFloat(course) * 0.26)
    }

    /// Solid ground behind the face, so a cliff has mass rather than an outline.
    private func rockPath(state: RunState, sceneSize: CGSize, first: Int, count: Int) -> CGPath {
        let path = CGMutablePath()
        var left: [CGPoint] = [], right: [CGPoint] = []
        for step in 0...count {
            let terrainY = max(0, Double(first + step) * Self.band)
            let e = state.gorge.edges(at: terrainY)
            let y = terrainY - state.worldY
            left.append(CGPoint(x: e.left, y: y))
            right.append(CGPoint(x: e.right, y: y))
        }
        for step in 0...count {
            let terrainY = max(0, Double(first + step) * Self.band)
            guard let island = state.gorge.spine(at: terrainY) else { continue }
            let y = terrainY - state.worldY
            path.addRect(CGRect(x: island.left, y: y - Self.band / 2,
                                width: island.right - island.left, height: Self.band + 1))
        }
        guard let lo = left.first, let hi = left.last else { return path }
        path.move(to: CGPoint(x: 0, y: lo.y))
        path.addLines(between: left)
        path.addLine(to: CGPoint(x: 0, y: hi.y))
        path.closeSubpath()
        path.move(to: CGPoint(x: sceneSize.width, y: right[0].y))
        path.addLines(between: right)
        path.addLine(to: CGPoint(x: sceneSize.width, y: right[right.count - 1].y))
        path.closeSubpath()
        return path
    }

    private func texture(_ material: ZoneLook.Material, rock: Int, variant: Int) -> SKTexture? {
        let key = "\(material.rawValue)-\(rock)-\(variant)"
        if let hit = cache[key] { return hit }
        // Raw parchment outshines the Pilgrim, so the cliff takes the zone's stone.
        let baked = SpriteAtlas.baked(material.sprites[variant],
                                      tint: material == .fog ? nil : SpriteAtlas.rgb(rock))
        cache[key] = baked
        return baked
    }
}
