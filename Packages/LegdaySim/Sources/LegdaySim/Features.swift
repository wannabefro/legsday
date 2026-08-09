import Foundation

/// A zone's furniture. A briar bed buried in the cliff is scenery, so
/// every piece sits inside the channel.
public struct Feature: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable {
        case briar
        case cairn
    }

    public let id: Int
    public let kind: Kind
    /// Anchored to the climb, not the screen, so it holds still as the world moves.
    public var terrainY: Double
    public var x: Double
    /// Briar: the circle. Cairn: half the side of the box.
    public var extent: Double
    public var hp: Int
    public var struckAt: Double
    public var rotation: Double

    public init(id: Int, kind: Kind, terrainY: Double, x: Double, extent: Double,
                hp: Int, rotation: Double) {
        self.id = id
        self.kind = kind
        self.terrainY = terrainY
        self.x = x
        self.extent = extent
        self.hp = hp
        self.struckAt = -1
        self.rotation = rotation
    }
}

extension Feature {
    /// What each stage is furnished with, and how often. Source: the prototype's
    /// per-stage `feat` and `featN`.
    public struct Furniture: Equatable, Sendable {
        public let kind: Feature.Kind?
        public let rate: Double
    }

    public static let byStageID: [String: Furniture] = [
        "low_road": Furniture(kind: .briar, rate: 1.0),
        "orchard": Furniture(kind: .briar, rate: 1.5),
        "ossuary": Furniture(kind: .cairn, rate: 1.8),
        "spire": Furniture(kind: .cairn, rate: 1.0),
        "reckoning": Furniture(kind: nil, rate: 0),
    ]

    /// A phrase's share of the stage's rate. A gate is a moment, not a place.
    public static func density(in phrase: Gorge.Segment.Kind?) -> Double {
        switch phrase {
        case .gate: return 0
        case .chamber: return 1.8
        case .squeeze: return 0.6
        case .bend: return 0.8
        default: return 1.0
        }
    }

    /// Below this a cairn stops being furniture and becomes a wall.
    public static let cairnMinimumChannel: Double = 150

    /// Seconds of accumulated rate that buy one piece.
    public static let placeInterval: Double = 2.6
    /// A briar slows the thumb this much. A cairn cannot be walked through at all.
    public static let heroBriarSeek: Double = 0.38
    /// Per 1/60s of foe velocity kept while snagged.
    public static let foeBriarDrag: Double = 0.90
    public static let cairnHP = 3
    public static let strikeFlash: Double = 0.18
    static let minimumChannel: Double = 70
    static let edgeInset: Double = 30
}

extension RunSim {
    /// Place on the stage's clock, then drop what the screen has passed.
    mutating func updateFeatures(dt: Double) {
        let furniture = Feature.byStageID[state.stage.id]
            ?? Feature.byStageID["low_road"]!
        if let kind = furniture.kind, furniture.rate > 0 {
            let phrase = state.gorge.segment(at: terrainY(of: -40))
            state.featureAcc += dt * furniture.rate * Feature.density(in: phrase)
            while state.featureAcc > Feature.placeInterval {
                state.featureAcc -= Feature.placeInterval
                placeFeature(kind)
            }
        }
        state.features.removeAll { $0.terrainY < state.worldY - 80 }
    }

    private mutating func placeFeature(_ kind: Feature.Kind) {
        let terrainY = terrainY(of: -40)
        let edges = state.gorge.edges(at: terrainY)
        let channel = edges.right - edges.left
        guard channel >= Feature.minimumChannel else { return }
        guard kind != .cairn || channel >= Feature.cairnMinimumChannel else { return }
        var x = state.rng.range(edges.left + Feature.edgeInset,
                                edges.right - Feature.edgeInset)
        // A briar bed inside the island is furniture nobody can reach.
        if let island = state.gorge.spine(at: terrainY),
           x > island.left, x < island.right {
            x = x - island.left < island.right - x
                ? island.left - Feature.edgeInset
                : island.right + Feature.edgeInset
            guard x > edges.left, x < edges.right else { return }
        }
        let extent = kind == .briar
            ? state.height * state.rng.range(0.045, 0.070)
            : state.width * 0.065
        state.features.append(Feature(id: state.nextFeatureId, kind: kind,
                                      terrainY: terrainY, x: x, extent: extent,
                                      hp: kind == .cairn ? Feature.cairnHP : 0,
                                      rotation: state.rng.range(0, 6.283)))
        state.nextFeatureId += 1
    }

    /// Screen y of a feature this step. The render layer computes the same value.
    public func screenY(of feature: Feature) -> Double {
        state.worldY + state.height - feature.terrainY
    }

    func inBriar(_ point: Vec2) -> Bool {
        state.features.contains { f in
            guard f.kind == .briar else { return false }
            return (point - Vec2(f.x, screenY(of: f))).length < f.extent
        }
    }

    /// Circle against every cairn: leave by the nearest face, and lose that axis.
    func pushOutOfCairns(_ point: Vec2, velocity: inout Vec2, radius: Double) -> Vec2 {
        var p = point
        for f in state.features where f.kind == .cairn {
            let cy = screenY(of: f)
            let minX = f.x - f.extent, maxX = f.x + f.extent
            let minY = cy - f.extent, maxY = cy + f.extent
            let nearest = Vec2(min(max(p.x, minX), maxX), min(max(p.y, minY), maxY))
            let away = p - nearest
            let d = away.length
            guard d < radius else { continue }
            if d < 0.001 {
                let out = [p.x - minX, maxX - p.x, p.y - minY, maxY - p.y]
                let shortest = out.min()!
                if shortest == out[0] { p.x = minX - radius }
                else if shortest == out[1] { p.x = maxX + radius }
                else if shortest == out[2] { p.y = minY - radius }
                else { p.y = maxY + radius }
            } else {
                p = nearest + Vec2(away.x / d * radius, away.y / d * radius)
                if abs(away.x) > abs(away.y) { velocity.x = 0 } else { velocity.y = 0 }
            }
        }
        return p
    }

    /// The cairn a shot meets first, if any. Rock stops a shot as surely as a cairn.
    func cairnBlocking(from a: Vec2, to b: Vec2) -> Int? {
        for f in state.features.indices where state.features[f].kind == .cairn {
            let feature = state.features[f]
            let cy = screenY(of: feature)
            for s in 0...12 {
                let t = Double(s) / 12
                let p = Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
                if abs(p.x - feature.x) <= feature.extent,
                   abs(p.y - cy) <= feature.extent {
                    return f
                }
            }
        }
        return nil
    }

    mutating func strikeCairn(at index: Int) {
        state.features[index].struckAt = state.time
        state.features[index].hp -= 1
        guard state.features[index].hp <= 0 else { return }
        let felled = state.features[index]
        state.frameEvents.append(.cairnBroken(at: Vec2(felled.x, screenY(of: felled))))
        state.features.remove(at: index)
    }
}
