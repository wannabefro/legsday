import Foundation

/// The Wild chain weapon (R21): a verlet flail that whips with kiting.
/// A heavy head resists; a light head crackles.
public struct ChainRope: Equatable, Sendable {
    public private(set) var points: [Vec2]
    private var prev: [Vec2]
    /// Head tip speed over the last update, px/s — the whip-damage input.
    public private(set) var headSpeed: Double = 0
    private let count: Int
    private let gravity: Double
    private let iterations: Int
    private var restSegment: Double = 0

    public init(pin: Vec2, count: Int, segment: Double) {
        precondition(count >= 2)
        let pts = (0..<count).map { Vec2(pin.x, pin.y + Double($0) * segment) }
        self.points = pts
        self.prev = pts
        self.count = count
        self.gravity = 300
        self.iterations = 12
    }

    public var head: Vec2 { points[count - 1] }

    /// Advance one fixed step; segment and head mass come scaled by growth mods.
    public mutating func update(dt: Double, pin: Vec2, segment: Double, headMass: Double) {
        restSegment = segment
        let prevHead = prev[count - 1]
        for i in 1..<count {
            let cur = points[i]
            let vel = cur - prev[i]
            points[i] = cur + vel + Vec2(0, gravity) * (dt * dt)
            prev[i] = cur
        }
        points[0] = pin
        prev[0] = pin
        for _ in 0..<iterations {
            points[0] = pin
            for i in 0..<(count - 1) {
                let a = points[i], b = points[i + 1]
                let delta = b - a
                let d = max(delta.length, 1e-6)
                let diff = (d - segment) / d
                let wA = i == 0 ? 0.0 : 1.0
                let wB = i == count - 2 ? 1.0 / headMass : 1.0
                let wSum = wA + wB
                guard wSum > 0 else { continue }
                let shift = delta * diff
                points[i] = a + shift * (wA / wSum)
                points[i + 1] = b - shift * (wB / wSum)
            }
        }
        points[0] = pin
        headSpeed = (points[count - 1] - prevHead).length / dt
    }

    /// Largest deviation of any segment from the last-applied rest length — a
    /// stability probe (the cloak's `maxSegmentError`).
    public var maxSegmentError: Double {
        var worst = 0.0
        for i in 0..<(count - 1) {
            let d = (points[i + 1] - points[i]).length
            worst = max(worst, abs(d - restSegment))
        }
        return worst
    }
}

/// The chain head's damage model (R21): hits above a whip-speed threshold,
/// harder as the whip is faster.
public struct RopeConfig: Equatable, Sendable {
    public var headRadius: Double
    public var threshold: Double
    public var damageScale: Double
}

/// Base tuning for the chain weapon's two forms. Placeholder-by-design like the
/// other weapon kits — the structure is the deliverable.
public enum Chain {
    public static let id = "the_wild_chain"

    public struct Form: Equatable, Sendable {
        public var segments: Int
        public var segment: Double
        public var headMass: Double
        public var threshold: Double
        public var damageScale: Double
    }

    public static let longLash = Form(segments: 8, segment: 9, headMass: 0.8,
                                      threshold: 400, damageScale: 0.02)
    public static let heavyHead = Form(segments: 5, segment: 11, headMass: 3.0,
                                       threshold: 360, damageScale: 0.035)
    public static let headRadius: Double = 12
}
