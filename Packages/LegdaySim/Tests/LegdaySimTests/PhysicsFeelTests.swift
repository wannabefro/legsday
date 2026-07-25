import Foundation
import Testing
@testable import LegdaySim

struct PhysicsFeelTests {
    private let step = RunSim.fixedStep

    /// The lantern settles to rest under damping once the pivot stops moving.
    @Test func pendulumSettlesToRest() {
        var p = Pendulum()
        // Kick it with pivot motion…
        for _ in 0..<12 { p.update(dt: step, pivotDriveX: 320) }
        #expect(abs(p.angle) > 0.01) // actually swinging
        // …then hold the pivot still and let it damp out.
        for _ in 0..<Int(6.0 / step) { p.update(dt: step, pivotDriveX: 0) }
        #expect(abs(p.angle) < 0.01)
        #expect(abs(p.angularVel) < 0.01)
    }

    /// The cloak stays intact (segments near rest length, no NaN) under fast,
    /// erratic pin motion.
    @Test func verletCloakStableUnderFastDrag() {
        var chain = VerletChain(pin: Vec2(200, 400))
        // Whip the pin around hard.
        for i in 0..<600 {
            let t = Double(i)
            let pin = Vec2(200 + 160 * sin(t * 0.5), 400 + 120 * cos(t * 0.37))
            chain.update(dt: step, pin: pin)
        }
        #expect(chain.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        #expect(chain.maxSegmentError < chain.restLength) // no explosion
        #expect(chain.points[0] == Vec2(200 + 160 * sin(599 * 0.5), 400 + 120 * cos(599 * 0.37)))
    }

    /// Determinism holds with the feel integrators active (they're in the
    /// fingerprint): same seed + input stream → identical state.
    @Test func determinismHoldsWithFeelActive() {
        let t = Tunables(scroll: 78, spawn: 1.7, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1)
        var a = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 2024)
        var b = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 2024)
        for i in 0..<1800 {
            let loc = Vec2(196 + 90 * sin(Double(i) * 0.02), 420 + 70 * cos(Double(i) * 0.03))
            let input = Input(phase: i == 0 ? .began : .moved, location: loc)
            a.tick(dt: 1.0 / 60, input: input)
            b.tick(dt: 1.0 / 60, input: input)
        }
        #expect(a.state.fingerprint == b.state.fingerprint)
    }
}
