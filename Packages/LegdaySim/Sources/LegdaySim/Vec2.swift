import Foundation

/// A 2D vector in the sim's reference coordinate space (points; +y is downward,
/// matching the graybox's screen space). Plain-struct so state fingerprints are
/// bit-deterministic across processes.
public struct Vec2: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double = 0, _ y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (v: Vec2, s: Double) -> Vec2 { Vec2(v.x * s, v.y * s) }

    public var length: Double { (x * x + y * y).squareRoot() }
}
