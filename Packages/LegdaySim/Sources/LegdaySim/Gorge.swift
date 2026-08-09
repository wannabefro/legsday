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

    /// The island a fork puts in the middle of the channel. Both lanes stay
    /// passable; the narrow one pays better.
    public struct Spine: Equatable, Sendable {
        public let left: Double
        public let right: Double
    }

    public enum Lane: Equatable, Sendable {
        case open
        case narrow
        case wide
    }

    public static let bandHeight: Double = 34
    /// Bands between forks, and how long one lasts. The gap matches the
    /// fork card's 450-fathom cadence.
    public static let forkGap = 118
    public static let forkLength = 14
    /// Island half-width and offset, as fractions of the channel.
    static let spineHalfShare = 0.20
    static let spineOffsetShare = 0.14
    /// A channel narrower than this cannot hold a fork and stays open.
    static let forkMinimumChannel = 150.0
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
        /// Island centre and half-width, both as fractions of the viewport.
        var spineCenter: Double = 0
        var spineHalf: Double = 0
    }

    private struct Profile: Sendable {
        var bands: [Band] = [Band(center: 0.5, width: 0)]
        var center = 0.5
        var width = 0.0
        var goalCenter = 0.5
        var goalWidth = 0.0
        var hold = 0
        var untilFork = Gorge.forkGap
        var forkAge = 0
        var forkSide = 1.0
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
                mix(band.spineCenter.bitPattern)
                mix(band.spineHalf.bitPattern)
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
            Self.pushBand(into: &current, shape: shape, viewport: width, using: &rng)
        }
        profile = current
    }

    /// The island at this height, or nil where the channel is single.
    public func spine(at worldY: Double) -> Spine? {
        let (a, b, fraction) = sample(at: worldY)
        guard a.spineHalf > 0, b.spineHalf > 0 else { return nil }
        let center = a.spineCenter + (b.spineCenter - a.spineCenter) * fraction
        let half = a.spineHalf + (b.spineHalf - a.spineHalf) * fraction
        guard half > 0.001 else { return nil }
        return Spine(left: (center - half) * width, right: (center + half) * width)
    }

    /// Which lane a point stands in. The narrow lane is the one that pays.
    public func lane(ofX x: Double, at worldY: Double) -> Lane {
        guard let island = spine(at: worldY) else { return .open }
        let bounds = edges(at: worldY)
        let leftLane = island.left - bounds.left
        let rightLane = bounds.right - island.right
        if x < island.left { return leftLane <= rightLane ? .narrow : .wide }
        if x > island.right { return rightLane <= leftLane ? .narrow : .wide }
        return .open
    }

    private func sample(at worldY: Double) -> (Band, Band, Double) {
        guard let current = profile, current.bands.count >= 2 else {
            return (Band(center: 0.5, width: 1), Band(center: 0.5, width: 1), 0)
        }
        let position = max(0, worldY) / Self.bandHeight
        var index = Int(position.rounded(.down))
        var fraction = position - Double(index)
        if index >= current.bands.count - 1 {
            index = current.bands.count - 2
            fraction = 1
        }
        return (current.bands[index], current.bands[index + 1], fraction)
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
        guard let island = spine(at: worldY),
              clamped.x > island.left - radius, clamped.x < island.right + radius else {
            return clamped
        }
        // Leave by the nearer face, so a body never tunnels through the island.
        if clamped.x - island.left < island.right - clamped.x {
            clamped.x = island.left - radius
            if velocity.x > 0 { velocity.x = 0 }
        } else {
            clamped.x = island.right + radius
            if velocity.x < 0 { velocity.x = 0 }
        }
        return clamped
    }

    private static func makeProfile(shape: Shape) -> Profile {
        let band = Band(center: 0.5, width: shape.widths.upper.nextDown)
        return Profile(bands: [band], center: band.center, width: band.width,
                       goalCenter: band.center, goalWidth: band.width, hold: 0)
    }

    private static func pushBand(into profile: inout Profile, shape: Shape,
                                 viewport: Double, using rng: inout SeededRandom) {
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
        let center = min(max(jittered, half), 1 - half)
        var band = Band(center: center, width: profile.width)
        advanceFork(&profile, channel: profile.width * viewport, using: &rng)
        if profile.forkAge > 0 {
            let taper = sin(Double(profile.forkAge) / Double(Gorge.forkLength) * .pi)
            band.spineHalf = profile.width * Gorge.spineHalfShare * taper
            band.spineCenter = center + profile.forkSide * profile.width
                * Gorge.spineOffsetShare
        }
        profile.bands.append(band)
    }

    /// A fork opens on its own clock, and only where both lanes would be passable.
    private static func advanceFork(_ profile: inout Profile, channel: Double,
                                    using rng: inout SeededRandom) {
        if profile.forkAge > 0 {
            profile.forkAge = profile.forkAge < forkLength ? profile.forkAge + 1 : 0
            if profile.forkAge == 0 { profile.untilFork = forkGap }
            return
        }
        profile.untilFork -= 1
        guard profile.untilFork <= 0 else { return }
        guard channel >= forkMinimumChannel else { return }
        profile.forkAge = 1
        profile.forkSide = rng.unit() < 0.5 ? -1 : 1
    }
}
