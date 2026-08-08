import Foundation

public struct Gorge: Sendable {
    public struct WidthRange: Equatable, Sendable {
        public let lower: Double
        public let upper: Double

        public init(_ lower: Double, _ upper: Double) {
            self.lower = lower
            self.upper = upper
        }
    }

    public struct Edges: Equatable, Sendable {
        public let left: Double
        public let right: Double
    }

    public static let bandHeight: Double = 34
    public static let widthRanges: [String: WidthRange] = [
        "low_road": WidthRange(0.52, 0.86),
        "orchard": WidthRange(0.38, 0.66),
        "ossuary": WidthRange(0.42, 0.74),
        "spire": WidthRange(0.30, 0.52),
        "reckoning": WidthRange(0.26, 0.44),
    ]

    private struct Band: Sendable {
        var center: Double
        var width: Double
    }

    private struct Profile: Sendable {
        var bands: [Band] = [Band(center: 0.5, width: 0)]
        var center = 0.5
        var width = 0.0
        var goalCenter = 0.5
        var goalWidth = 0.0
        var hold = 0
    }

    private struct Shape: Sendable {
        let widths: WidthRange
        let jitter: Double
        let hold: ClosedRange<Int>
    }

    private static let shapes: [String: Shape] = [
        "low_road": Shape(widths: widthRanges["low_road"]!, jitter: 0.022, hold: 4...9),
        "orchard": Shape(widths: widthRanges["orchard"]!, jitter: 0.040, hold: 2...4),
        "ossuary": Shape(widths: widthRanges["ossuary"]!, jitter: 0.010, hold: 3...6),
        "spire": Shape(widths: widthRanges["spire"]!, jitter: 0.002, hold: 6...12),
        "reckoning": Shape(widths: widthRanges["reckoning"]!, jitter: 0.030, hold: 2...5),
    ]

    private let width: Double
    private var profile: Profile?
    /// Its own stream, so drawing the walls never moves the run's draws.
    private var rng: SeededRandom

    public init(width: Double, seed: UInt64) {
        self.width = width
        self.rng = SeededRandom(seed: seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x5DEE_CE66)
    }

    var fingerprint: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ bits: UInt64) { hash = (hash ^ bits) &* 0x0000_0100_0000_01B3 }
        mix(width.bitPattern)
        mix(rng.state)
        if let profile {
            mix(profile.center.bitPattern)
            mix(profile.width.bitPattern)
            mix(profile.goalCenter.bitPattern)
            mix(profile.goalWidth.bitPattern)
            mix(UInt64(bitPattern: Int64(profile.hold)))
            for band in profile.bands {
                mix(band.center.bitPattern)
                mix(band.width.bitPattern)
            }
        }
        return hash
    }

    /// Generation depends on climb height and nothing else.
    public mutating func generate(throughWorldY worldY: Double, stageID: String) {
        let shape = Self.shapes[stageID] ?? Self.shapes["low_road"]!
        let index = Int((max(0, worldY) / Self.bandHeight).rounded(.down))
        var current = profile ?? Self.makeProfile(shape: shape)
        while current.bands.count <= index + 1 {
            Self.pushBand(into: &current, shape: shape, using: &rng)
        }
        profile = current
    }

    public func edges(at worldY: Double) -> Edges {
        guard let current = profile, current.bands.count >= 2 else {
            return Edges(left: 0, right: width)
        }
        let position = max(0, worldY) / Self.bandHeight
        var index = Int(position.rounded(.down))
        var fraction = position - Double(index)
        if index >= current.bands.count - 1 {
            index = current.bands.count - 2
            fraction = 1
        }
        let a = current.bands[index]
        let b = current.bands[index + 1]
        let center = a.center + (b.center - a.center) * fraction
        let channelWidth = a.width + (b.width - a.width) * fraction
        return Edges(left: (center - channelWidth / 2) * width,
                     right: (center + channelWidth / 2) * width)
    }

    public func clamp(_ point: Vec2, radius: Double, at worldY: Double) -> Vec2 {
        var velocity = Vec2.zero
        return clamp(point, velocity: &velocity, radius: radius, at: worldY)
    }

    public func clamp(_ point: Vec2, velocity: inout Vec2, radius: Double,
                      at worldY: Double) -> Vec2 {
        let boundary = edges(at: worldY)
        var clamped = point
        if clamped.x < boundary.left + radius {
            clamped.x = boundary.left + radius
            if velocity.x < 0 { velocity.x = 0 }
        }
        if clamped.x > boundary.right - radius {
            clamped.x = boundary.right - radius
            if velocity.x > 0 { velocity.x = 0 }
        }
        return clamped
    }

    private static func makeProfile(shape: Shape) -> Profile {
        let band = Band(center: 0.5, width: shape.widths.upper.nextDown)
        return Profile(bands: [band], center: band.center, width: band.width,
                       goalCenter: band.center, goalWidth: band.width, hold: 0)
    }

    private static func pushBand(into profile: inout Profile, shape: Shape,
                                 using rng: inout SeededRandom) {
        if profile.hold <= 0 {
            profile.hold = shape.hold.lowerBound
                + Int(rng.unit() * Double(shape.hold.upperBound - shape.hold.lowerBound))
            let base = rng.unit() < 0.42 ? shape.widths.lower : shape.widths.upper
            profile.goalWidth = min(max(base * rng.range(0.86, 1.06), shape.widths.lower),
                                    shape.widths.upper)
            profile.goalCenter = 0.5 + (rng.unit() - 0.5) * (0.92 - profile.goalWidth)
        }
        profile.hold -= 1
        profile.width += (profile.goalWidth - profile.width) * 0.34
        profile.width = min(max(profile.width, shape.widths.lower.nextUp),
                            shape.widths.upper.nextDown)
        profile.center += (profile.goalCenter - profile.center) * 0.34
        let jittered = profile.center + (rng.unit() - 0.5) * shape.jitter
        let half = profile.width / 2
        profile.bands.append(Band(center: min(max(jittered, half), 1 - half),
                                  width: profile.width))
    }
}
