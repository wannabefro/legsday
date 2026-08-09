import Foundation
import Testing
@testable import LegdaySim

/// Twelve wedges on twelve springs. If they move as one the cloak is a rigid
/// board, and if they never settle it is a flag in a gale.
struct CloakTests {
    private static func swung(turnRate: Double, steps: Int = 30,
                              heading: Double = 0) -> CloakRig {
        var rig = CloakRig()
        for _ in 0..<steps {
            rig.update(dt: 1.0 / 120, heading: heading, turnRate: turnRate,
                       accel: .zero, velocity: Vec2(0, -120), speed: 120)
        }
        return rig
    }

    @Test func twelveWedgesRingTheBodyAndAllStartAtRest() {
        let rig = CloakRig()
        #expect(rig.wedges.count == 12)
        #expect(rig.wedges.allSatisfy { $0.angle == 0 && $0.vel == 0 && $0.stretch == 1 })
    }

    @Test func aTurnSwingsTheHemAndItSettlesBackWhenTheTurnStops() {
        var rig = Self.swung(turnRate: 6)
        let peak = rig.wedges.map { abs($0.angle) }.max() ?? 0
        for _ in 0..<600 {
            rig.update(dt: 1.0 / 120, heading: 0, turnRate: 0,
                       accel: .zero, velocity: .zero, speed: 0)
        }
        let settled = rig.wedges.map { abs($0.angle) }.max() ?? 0
        #expect(peak > 0.01)
        #expect(settled < peak * 0.1)
    }

    /// The boundary itself: the swing stops at the limit and rebounds inward.
    @Test func theSwingStopsAtTheLimitAndRebounds() {
        let rig = Self.swung(turnRate: 400, steps: 120)
        #expect(rig.wedges.allSatisfy { abs($0.angle) <= CloakRig.swingLimit + 1e-9 })
        #expect(rig.wedges.contains { abs($0.angle) > CloakRig.swingLimit * 0.9 })
    }

    /// Trailing fabric lags more, or the cloak turns as one rigid piece.
    @Test func trailingFabricSwingsFurtherThanLeadingFabric() {
        let rig = Self.swung(turnRate: 6)
        // sin(phi) > 0 is the trailing half at heading 0.
        let trailing = rig.wedges.filter { sin($0.phi) > 0.5 }.map { abs($0.angle) }
        let leading = rig.wedges.filter { sin($0.phi) < -0.5 }.map { abs($0.angle) }
        let trailingMean = trailing.reduce(0, +) / Double(trailing.count)
        let leadingMean = leading.reduce(0, +) / Double(leading.count)
        #expect(!trailing.isEmpty && !leading.isEmpty)
        #expect(trailingMean > leadingMean)
    }

    @Test func aShotSnapsTheHemAcrossTheLineOfFire() {
        var rig = CloakRig()
        rig.kick(heading: 0, unit: Vec2(1, 0))
        let moved = rig.wedges.filter { $0.vel != 0 }
        #expect(moved.count >= 10)
        // A kick across the body throws one side one way and the other back.
        let up = rig.wedges.contains { $0.vel > 0 }
        let down = rig.wedges.contains { $0.vel < 0 }
        #expect(up && down)
    }

    /// The still guard on its own: below 1 px/s no wedge stretches.
    @Test func standingStillLeavesEveryStretchAtOne() {
        var rig = CloakRig()
        for _ in 0..<600 {
            rig.update(dt: 1.0 / 120, heading: 0, turnRate: 0,
                       accel: .zero, velocity: .zero, speed: 0)
        }
        #expect(rig.wedges.allSatisfy { abs($0.stretch - 1) < 1e-6 })
    }

    @Test func fabricBehindTheTravelStreamsOutAndFabricAheadTucksIn() {
        var rig = CloakRig()
        for _ in 0..<240 {
            rig.update(dt: 1.0 / 120, heading: 0, turnRate: 0,
                       accel: .zero, velocity: Vec2(0, -200), speed: 200)
        }
        let widest = rig.wedges.map(\.stretch).max()!
        let tightest = rig.wedges.map(\.stretch).min()!
        #expect(widest > 1)
        #expect(tightest < 1)
    }

    @Test func aRunCarriesTheCloakAndTheStateStaysFingerprinted() {
        var sim = RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 8)
        sim.debugMutate { $0.hero.pos = Vec2(80, 400); $0.hero.target = Vec2(320, 500) }
        for _ in 0..<120 { sim.tick(dt: RunSim.fixedStep, input: .idle) }
        #expect(sim.state.cloak.wedges.contains { $0.angle != 0 })
        #expect(sim.state.cloak.fingerprint.count == 36)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)
}
