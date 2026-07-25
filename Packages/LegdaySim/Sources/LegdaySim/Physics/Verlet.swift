import Foundation

/// The Pilgrim's cloak: a short verlet chain pinned to the hero, trailing with
/// movement (R20). Deterministic; integrated at the sim's scaled dt. Distance
/// constraints keep it from stretching under fast drag.
public struct VerletChain: Equatable, Sendable {
    public private(set) var points: [Vec2]
    private var prev: [Vec2]
    private let segment: Double
    private let gravity: Double
    private let iterations: Int

    public init(pin: Vec2, count: Int = 6, segment: Double = 7, gravity: Double = 220) {
        precondition(count >= 2)
        // Hang straight down from the pin at rest.
        let pts = (0..<count).map { Vec2(pin.x, pin.y + Double($0) * segment) }
        self.points = pts
        self.prev = pts
        self.segment = segment
        self.gravity = gravity
        self.iterations = 4
    }

    public var restLength: Double { segment }

    public mutating func update(dt: Double, pin: Vec2) {
        // Verlet integration (index 0 is pinned to the hero).
        for i in 1..<points.count {
            let current = points[i]
            let velocity = current - prev[i]
            points[i] = current + velocity + Vec2(0, gravity) * (dt * dt)
            prev[i] = current
        }
        points[0] = pin
        prev[0] = pin

        // Satisfy distance constraints (relax a few times for stiffness).
        for _ in 0..<iterations {
            points[0] = pin
            for i in 0..<(points.count - 1) {
                let a = points[i], b = points[i + 1]
                let delta = b - a
                let d = max(delta.length, 1e-6)
                let diff = (d - segment) / d
                if i == 0 {
                    points[i + 1] = b - delta * diff // only the free end moves
                } else {
                    let shift = delta * (0.5 * diff)
                    points[i] = a + shift
                    points[i + 1] = b - shift
                }
            }
        }
    }

    /// The largest deviation of any segment from its rest length — a stability
    /// probe.
    public var maxSegmentError: Double {
        var worst = 0.0
        for i in 0..<(points.count - 1) {
            let d = (points[i + 1] - points[i]).length
            worst = max(worst, abs(d - segment))
        }
        return worst
    }
}
