import Foundation

/// The Pilgrim's lantern: a single damped bob driven by the pivot's motion
/// (R20). Deterministic, integrated at the sim's scaled dt — so it slows with
/// the world during a card, itself a storybook beat.
public struct Pendulum: Equatable, Sendable {
    public private(set) var angle: Double        // radians from rest (hanging down)
    public private(set) var angularVel: Double

    private let length: Double
    private let gravity: Double
    private let damping: Double

    public init(length: Double = 26, gravity: Double = 40, damping: Double = 2.2) {
        self.angle = 0
        self.angularVel = 0
        self.length = length
        self.gravity = gravity
        self.damping = damping
    }

    /// Advance one step. `pivotDriveX` is the pivot's horizontal motion (px/s):
    /// a moving pivot swings the bob; a still pivot lets it settle to rest.
    public mutating func update(dt: Double, pivotDriveX: Double) {
        let restoring = -(gravity / length) * sin(angle)
        let drive = -(pivotDriveX / length) * cos(angle)
        let damp = -damping * angularVel
        angularVel += (restoring + drive + damp) * dt
        angle += angularVel * dt
    }
}
