import Foundation

/// The cloak, sliced into wedges at the shoulders. Each has its own
/// spring, so a turn ripples through the hem.
public struct CloakRig: Equatable, Sendable {
    public static let wedgeCount = 12
    /// Detune per wedge, so the ripple travels rather than pulsing as one.
    static let stiffness: Double = 26
    static let damping: Double = 3.6
    static let swingLimit: Double = 0.42
    static let bounce: Double = -0.25
    static let fromTurnRate: Double = 0.035
    static let fromAcceleration: Double = 0.0005
    static let stretchRate: Double = 10
    static let gaitSpeed: Double = 150

    public struct Wedge: Equatable, Sendable {
        /// Where this wedge sits around the body, in −π…π.
        public let phi: Double
        /// Swing away from rest.
        public var angle: Double = 0
        public var vel: Double = 0
        /// How far the fabric streams out. Trailing fabric stretches, leading tucks.
        public var stretch: Double = 1
    }

    public private(set) var wedges: [Wedge]

    public init() {
        let step = 2 * Double.pi / Double(Self.wedgeCount)
        wedges = (0..<Self.wedgeCount).map {
            Wedge(phi: (Double($0) + 0.5) * step - .pi)
        }
    }

    /// `turnRate` is the body's angular velocity; `accel` the body's own.
    public mutating func update(dt: Double, heading: Double, turnRate: Double,
                                accel: Vec2, velocity: Vec2, speed: Double) {
        let gait = min(1, speed / Self.gaitSpeed)
        let ch = cos(heading), sh = sin(heading)
        for i in wedges.indices {
            var w = wedges[i]
            let cp = cos(w.phi), sp = sin(w.phi)
            let wx = cp * ch - sp * sh, wy = cp * sh + sp * ch
            let across = -wy * accel.x + wx * accel.y
            // Trailing fabric lags more, or the cloak turns as one rigid piece.
            let lag = 0.30 + 0.70 * (1 + sp) * 0.5
            let stiffness = Self.stiffness * (0.82 + 0.36 * Double(i) / Double(Self.wedgeCount))
            let drive = (-turnRate * Self.fromTurnRate + across * Self.fromAcceleration) * lag
            w.vel += (-stiffness * w.angle - Self.damping * w.vel + drive * 60) * dt
            w.angle += w.vel * dt
            if w.angle > Self.swingLimit { w.angle = Self.swingLimit; w.vel *= Self.bounce }
            if w.angle < -Self.swingLimit { w.angle = -Self.swingLimit; w.vel *= Self.bounce }
            let along = speed > 1 ? (wx * velocity.x + wy * velocity.y) / speed : 0
            let want = 1 + 0.20 * gait * max(0, -along) - 0.07 * gait * max(0, along)
            w.stretch += (want - w.stretch) * min(1, dt * Self.stretchRate)
            wedges[i] = w
        }
    }

    /// A shot snaps the hem across the line of fire.
    mutating func kick(heading: Double, unit: Vec2, magnitude: Double = 2.6) {
        let ch = cos(heading), sh = sin(heading)
        for i in wedges.indices {
            let cp = cos(wedges[i].phi), sp = sin(wedges[i].phi)
            let wx = cp * ch - sp * sh, wy = cp * sh + sp * ch
            wedges[i].vel += (-wy * unit.x + wx * unit.y) * magnitude
        }
    }

    var fingerprint: [Double] {
        wedges.flatMap { [$0.angle, $0.vel, $0.stretch] }
    }
}
