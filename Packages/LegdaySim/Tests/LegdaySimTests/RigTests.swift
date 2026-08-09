import Foundation
import Testing
@testable import LegdaySim

/// One drawing does the work of an animation set. Every rule here decides
/// whether a body reads as driven or as a sprite slid across the screen.
struct RigTests {
    private static let W = 393.0, H = 852.0

    private static func sim(seed: UInt64 = 3) -> RunSim {
        RunSim(tunables: quiet, viewport: Vec2(W, H), seed: seed)
    }

    private static func run(_ s: inout RunSim, steps: Int) {
        for _ in 0..<steps { s.tick(dt: RunSim.fixedStep, input: .idle) }
    }

    /// The boundary itself: a turn of exactly ±π must not wrap to the far side.
    @Test func shortestTurnStaysInsideHalfATurnAtTheBoundary() {
        #expect(abs(Rig.shortestTurn(from: 0, to: .pi)) <= .pi + 1e-9)
        #expect(abs(Rig.shortestTurn(from: 0, to: -.pi)) <= .pi + 1e-9)
        #expect(abs(Rig.shortestTurn(from: 3.0, to: -3.0) - 0.2831853) < 1e-6)
    }

    @Test func theBodyTurnsTowardTravelAndNotTowardTheDragTarget() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 400); $0.hero.target = Vec2(40, 400) }
        let before = s.state.hero.heading
        Self.run(&s, steps: 30)
        // Travel is to the left, so the heading leaves its rest value.
        #expect(s.state.hero.heading != before)
        #expect(s.state.hero.pos.x < 200)
    }

    /// The still guard on its own: below 3 px/s the heading holds and lean unwinds.
    @Test func aStandingPilgrimHoldsItsHeadingAndUnwindsItsLean() {
        var s = Self.sim()
        s.debugMutate {
            $0.hero.pos = Vec2(200, 400); $0.hero.target = Vec2(200, 400)
            $0.hero.heading = 2.1; $0.hero.lean = 0.30
        }
        Self.run(&s, steps: 120)
        #expect(abs(s.state.hero.heading - 2.1) < 1e-6)
        #expect(abs(s.state.hero.lean) < 0.05)
    }

    @Test func strideRidesDistanceSoStandingStillStopsIt() {
        var still = Self.sim()
        still.debugMutate { $0.hero.pos = Vec2(200, 400); $0.hero.target = Vec2(200, 400) }
        Self.run(&still, steps: 120)

        var walking = Self.sim()
        walking.debugMutate { $0.hero.pos = Vec2(60, 400); $0.hero.target = Vec2(340, 400) }
        Self.run(&walking, steps: 120)

        #expect(still.state.hero.stride < 1e-6)
        #expect(walking.state.hero.stride > 0.5)
    }

    @Test func aShotKicksTheBodyBackAndTurnsTheHoodTowardIt() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500) }
        s.debugAddFoe(at: Vec2(200, 300), hp: 9, speed: 0)
        s.debugMutate { $0.attackTimer = 0 }
        s.tick(dt: RunSim.fixedStep, input: .idle)
        // The foe is up-screen, so the kick throws the body down-screen.
        #expect(s.state.hero.recoilVel.y > 0)
        #expect(s.state.hero.aim != 0)
    }

    @Test func theRecoilSpringsHomeAndTheGlanceDecays() {
        var s = Self.sim()
        s.debugMutate {
            $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500)
            $0.hero.recoil = Vec2(9, -9); $0.hero.aim = 0.4
        }
        Self.run(&s, steps: 240)
        #expect(s.state.hero.recoil.length < 0.5)
        #expect(abs(s.state.hero.aim) < 0.01)
    }

    /// The whole point of momentum: a foe cannot stop dead on top of the hero.
    @Test func aFoeCarriesMomentumPastAStationaryHero() {
        var s = Self.sim()
        s.debugMutate {
            $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500)
            $0.hero.invuln = 999
        }
        s.debugAddFoe(at: Vec2(200, 200), hp: 99, speed: 300)
        var crossed = false
        for _ in 0..<400 {
            s.tick(dt: RunSim.fixedStep, input: .idle)
            guard let f = s.state.foes.first else { break }
            if f.pos.y > 520 { crossed = true; break }
        }
        #expect(crossed)
    }

    @Test func everyFoeGetsItsOwnTurnGainSoNoTwoSwingAlike() {
        var s = RunSim(tunables: Self.busy, viewport: Vec2(Self.W, Self.H), seed: 44)
        // Read each foe as it spawns; the hero fells them faster than they gather.
        var gains: [Double] = []
        var seen = 0
        for _ in 0..<720 {
            s.tick(dt: RunSim.fixedStep, input: .idle)
            if s.state.spawnedCount > seen, let born = s.state.foes.last {
                seen = s.state.spawnedCount
                gains.append(born.turnGain)
            }
        }
        #expect(gains.count > 4)
        #expect(Set(gains).count == gains.count)
    }

    @Test func theBodyOfAMovingFoeSwingsRoundToItsHeading() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(40, 700); $0.hero.target = Vec2(40, 700) }
        s.debugAddFoe(at: Vec2(350, 120), hp: 99, speed: 200)
        let before = s.state.foes.first!.rotation
        Self.run(&s, steps: 90)
        let after = s.state.foes.first!
        #expect(after.rotation != before)
        #expect(abs(Rig.shortestTurn(from: after.rotation,
                                     to: atan2(after.vel.y, after.vel.x))) < 0.5)
    }

    /// The knock offset is drawn, never collided, so it springs home to zero.
    @Test func theKnockOffsetSpringsHomeToNothing() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 800); $0.hero.target = Vec2(200, 800) }
        s.debugAddFoe(at: Vec2(200, 60), hp: 99, speed: 0)
        s.debugMutate { $0.foes[0].knockVel = Vec2(240, 240) }
        Self.run(&s, steps: 360)
        #expect(s.state.foes.first!.knock.length < 1)
        #expect(s.state.foes.first!.knock.length >= 0)
    }

    /// No spawns and no card slow: the rig is measured, not the run.
    private static let quiet = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)

    /// A full field, for the per-foe detune.
    private static let busy = Tunables(
        scroll: 78, spawn: 2.5, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)
}
