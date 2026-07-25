import Foundation
import Testing
@testable import LegdaySim

struct SpringLineTests {
    private let step = RunSim.fixedStep

    /// A ripple injected at center propagates outward to neighbors.
    @Test func ripplePropagatesOutward() {
        var line = SpringLine(nodeCount: 48)
        line.inject(atFraction: 0.5, magnitude: 100) // center ≈ node 24
        for _ in 0..<60 { line.update(dt: step) }
        // The ripple has traveled ~12 nodes out from center.
        #expect(abs(line.heights[12]) > 1e-4)
        #expect(line.heights.allSatisfy { $0.isFinite })
    }

    /// Energy decays to rest — the surface stills, with no self-oscillation or
    /// blow-up at the fixed step.
    @Test func energyDecaysToRest() {
        var line = SpringLine(nodeCount: 48)
        line.inject(atFraction: 0.5, magnitude: 100)
        let initial = line.energy
        #expect(initial > 0)
        for _ in 0..<Int(6.0 / step) { line.update(dt: step) } // 6s
        #expect(line.energy < initial * 1e-4)
        #expect(line.heights.allSatisfy { $0.isFinite })
        #expect(line.velocities.allSatisfy { $0.isFinite })
    }

    /// An extreme injection stays finite (no NaN/Inf) and still settles.
    @Test func largeInjectionStaysFinite() {
        var line = SpringLine(nodeCount: 48)
        line.inject(atFraction: 0.5, magnitude: 1_000_000)
        let initial = line.energy
        for _ in 0..<Int(8.0 / step) { line.update(dt: step) }
        #expect(line.heights.allSatisfy { $0.isFinite })
        #expect(line.velocities.allSatisfy { $0.isFinite })
        #expect(line.energy < initial * 1e-4) // settles, never diverges
    }
}
