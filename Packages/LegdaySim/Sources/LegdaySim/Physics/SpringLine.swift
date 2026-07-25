/// A 1D spring-mesh water surface (KTD-3): a chain of nodes that each spring
/// back to a flat rest line, diffuse to their neighbors, and damp toward
/// stillness. Kill-pushes and splashes inject velocity at an x position, so the
/// fog line ripples. This lives in the sim (deterministic, timescale-obedient)
/// but is *read-only feedback* — the flat rest line, not these displacements,
/// decides death.
public struct SpringLine: Equatable, Sendable {
    /// Vertical displacement of each node from the flat rest line.
    public private(set) var heights: [Double]
    /// Per-node velocity.
    public private(set) var velocities: [Double]

    private let tension: Double   // restoring pull toward rest
    private let spread: Double    // neighbor diffusion
    private let damping: Double   // energy bleed

    public init(nodeCount: Int, tension: Double = 120, spread: Double = 1200, damping: Double = 2.5) {
        precondition(nodeCount >= 2)
        self.heights = [Double](repeating: 0, count: nodeCount)
        self.velocities = [Double](repeating: 0, count: nodeCount)
        self.tension = tension
        self.spread = spread
        self.damping = damping
    }

    public var count: Int { heights.count }

    public mutating func update(dt: Double) {
        let n = heights.count
        // Spring each node back to rest, with damping.
        for i in 0..<n {
            let accel = -tension * heights[i] - damping * velocities[i]
            velocities[i] += accel * dt
        }
        for i in 0..<n {
            heights[i] += velocities[i] * dt
        }
        // Diffuse toward neighbors (discrete Laplacian on displacement).
        var delta = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let left = i > 0 ? heights[i - 1] : heights[i]
            let right = i < n - 1 ? heights[i + 1] : heights[i]
            delta[i] = spread * (left + right - 2 * heights[i])
        }
        for i in 0..<n {
            velocities[i] += delta[i] * dt
        }
    }

    /// Inject a ripple at a fractional position (0…1 across the line), spread
    /// over the node and its immediate neighbors.
    public mutating func inject(atFraction f: Double, magnitude: Double) {
        let n = heights.count
        let idx = min(max(Int((f * Double(n - 1)).rounded()), 0), n - 1)
        velocities[idx] += magnitude
        if idx > 0 { velocities[idx - 1] += magnitude * 0.5 }
        if idx < n - 1 { velocities[idx + 1] += magnitude * 0.5 }
    }

    /// Total kinetic + potential energy — a stillness probe for tests.
    public var energy: Double {
        var e = 0.0
        for i in 0..<heights.count {
            e += velocities[i] * velocities[i] + heights[i] * heights[i]
        }
        return e
    }
}
