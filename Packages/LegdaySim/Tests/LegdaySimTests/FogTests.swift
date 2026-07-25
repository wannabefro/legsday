import Foundation
import Testing
@testable import LegdaySim

private let defaults = Tunables(
    scroll: 78, spawn: 1.7, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim(seed: UInt64 = 5) -> RunSim {
    RunSim(tunables: defaults, viewport: viewport, seed: seed)
}
private let step = RunSim.fixedStep

/// Puts the hero deep in the fog and holds them there.
private func sinkHero(_ sim: inout RunSim, y: Double) {
    sim.debugMutate {
        $0.hero.pos.y = y
        $0.hero.target.y = y
    }
}

struct FogTests {

    /// AE1 (R4): a dip into the fog inside the grace window applies no grip and
    /// the fog timer decays back to zero on climbing out.
    @Test func dipInsideGraceIsForgiven() {
        var sim = makeSim()
        sinkHero(&sim, y: 810) // below the ~740 fog line
        for _ in 0..<Int(0.5 / step) { sim.tick(dt: step, input: .idle) } // 0.5s < grace
        #expect(!sim.state.heroGripped)
        #expect(!sim.state.dead)
        #expect(sim.state.hero.fogTime > 0)

        // Climb out and hold above the line; the timer decays to zero.
        sim.debugMutate { $0.hero.pos.y = 300; $0.hero.target.y = 300 }
        for _ in 0..<Int(2.0 / step) { sim.tick(dt: step, input: .idle) }
        #expect(sim.state.hero.fogTime == 0)
        #expect(!sim.state.dead)
    }

    /// R4: staying past grace grips, and death lands at grace+grip elapsed.
    @Test func stayPastGraceGripsThenKills() {
        var sim = makeSim()
        sinkHero(&sim, y: 835)
        var grippedSeen = false
        var timeToDeath = 0.0
        for _ in 0..<Int(5.0 / step) {
            sim.tick(dt: step, input: .idle)
            if sim.state.heroGripped { grippedSeen = true }
            if sim.state.dead { break }
            timeToDeath += step
        }
        #expect(grippedSeen)
        #expect(sim.state.dead)
        // fogTime accrues 1:1 while submerged; death at grace(0.8)+grip(2.4)=3.2s.
        #expect(abs(timeToDeath - 3.2) < 0.1)
    }

    /// Success-envelope: an unmoving hero, shoved down by the swarm, is
    /// eventually caught — the fog+shove loop is lethal (not instant).
    @Test func stationaryHeroEventuallyCaught() {
        var sim = makeSim(seed: 99)
        var elapsed = 0.0
        var caught = false
        for _ in 0..<Int(180.0 / step) {
            // Commit any dealt card so the world doesn't freeze on it.
            if let c = sim.state.card, !c.committing { sim.commitCard(1) }
            sim.tick(dt: step, input: .idle)
            elapsed += step
            if sim.state.dead { caught = true; break }
        }
        #expect(caught)
        #expect(elapsed > 1.0)   // not an instant death
    }

    /// R5: each kill pushes the fog back by killPush; an elite by ×3.
    @Test func killPushesFogBack() {
        let normal = Foe(id: 0, pos: Vec2(196, 200), radius: 10, hp: 0, speed: 0, elite: false)
        let elite = Foe(id: 1, pos: Vec2(196, 200), radius: 15, hp: 0, speed: 0, elite: true)

        var a = makeSim()
        a.debugMutate { $0.fogPressure = 50 }
        a.applyFogKill(normal)
        #expect(abs(a.state.fogPressure - (50 - defaults.killPush)) < 1e-9)

        var b = makeSim()
        b.debugMutate { $0.fogPressure = 50 }
        b.applyFogKill(elite)
        #expect(abs(b.state.fogPressure - (50 - defaults.killPush * 3)) < 1e-9)
    }

    /// KTD-3: the spring surface is read-only feedback — a huge ripple never
    /// changes whether or when the hero dies.
    @Test func springRippleDoesNotAffectDeath() {
        func timeToDeath(injectRipples: Bool) -> Double {
            var sim = makeSim(seed: 3)
            sinkHero(&sim, y: 835)
            var t = 0.0
            for _ in 0..<Int(5.0 / step) {
                if injectRipples {
                    sim.debugMutate { $0.fogSurface.inject(atFraction: 0.5, magnitude: 5000) }
                }
                sim.tick(dt: step, input: .idle)
                if sim.state.dead { break }
                t += step
            }
            return t
        }
        #expect(abs(timeToDeath(injectRipples: true) - timeToDeath(injectRipples: false)) < 1e-9)
    }

    /// KTD-3: a splash scheduled from an extreme kill height stays finite.
    @Test func extremeKillHeightSplashIsFinite() {
        var sim = makeSim()
        let high = Foe(id: 0, pos: Vec2(196, -100_000), radius: 10, hp: 0, speed: 0, elite: false)
        sim.applyFogKill(high)
        let splash = sim.state.pendingSplashes.last
        #expect(splash != nil)
        #expect(splash!.dueTime.isFinite)
        #expect(splash!.magnitude.isFinite && splash!.magnitude > 0)
    }
}
