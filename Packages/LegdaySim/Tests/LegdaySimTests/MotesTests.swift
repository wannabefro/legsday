import Foundation
import Testing
@testable import LegdaySim

// spawn: 0 isolates mote mechanics from ambient foe drops.
private let noSpawn = Tunables(
    scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim(seed: UInt64 = 11) -> RunSim {
    RunSim(tunables: noSpawn, viewport: viewport, seed: seed)
}
private let step = RunSim.fixedStep

struct MotesTests {

    /// A mote outside magnet range sinks at the world rate and is lost to the
    /// fog with no essence gained.
    @Test func distantMoteSinksAndIsLostToFog() {
        var sim = makeSim()
        sim.debugAddMote(at: Vec2(50, 400), value: 1) // far from hero (~196,357)
        let sinkRate = noSpawn.scroll * 0.95 + 2

        // One second of sink, before it reaches the fog.
        for _ in 0..<60 { sim.tick(dt: 1.0 / 60, input: .idle) }
        #expect(sim.state.motes.count == 1)
        #expect(abs(sim.state.motes[0].pos.y - (400 + sinkRate)) < 1.0)
        #expect(sim.state.essence == 0)

        // Run until it crosses the fog line and is claimed.
        for _ in 0..<Int(6.0 / step) { sim.tick(dt: step, input: .idle) }
        #expect(sim.state.motes.isEmpty)
        #expect(sim.state.essence == 0) // never collected
    }

    /// A mote inside reach credits essence, and charge for the next card.
    @Test func moteInReachCreditsEssence() {
        var sim = makeSim()
        let hero = sim.state.hero.pos
        sim.debugAddMote(at: hero + Vec2(20, 0), value: 1) // inside 16+34·0.35≈27.9
        for _ in 0..<Int(1.0 / step) { sim.tick(dt: step, input: .idle) }
        #expect(sim.state.motes.isEmpty)          // collected
        #expect(sim.state.essence == 1)           // essMul default 1
        #expect(sim.state.charge == 1)            // feeds the next card (U6)
    }

    /// The Pilgrim must go to the essence. Nothing is ever pulled to her.
    @Test func aMoteJustOutOfReachIsNeverPulledIn() {
        var sim = makeSim()
        sim.debugAddMote(at: sim.state.hero.pos + Vec2(40, 0), value: 1)
        for _ in 0..<Int(1.0 / step) { sim.tick(dt: step, input: .idle) }
        #expect(sim.state.essence == 0)
        #expect(sim.state.motes.count == 1)
    }

    /// essMul scales the essence credited on collection.
    @Test func essMulScalesCredit() {
        var sim = makeSim()
        sim.debugMutate { $0.mods.essMul = 2 }
        let hero = sim.state.hero.pos
        sim.debugAddMote(at: hero + Vec2(20, 0), value: 3)
        for _ in 0..<Int(1.0 / step) { sim.tick(dt: step, input: .idle) }
        #expect(sim.state.essence == 6) // 2 · 3
    }

    /// The mote lands below her even when the foe she felled was above her.
    @Test func aMoteAlwaysLandsBelowThePilgrim() {
        var sim = makeSim()
        let hero = sim.state.hero.pos
        let foe = Foe(id: 1, pos: Vec2(hero.x, hero.y - 200), radius: 9, hp: 1,
                      speed: 60, elite: true, turnGain: 10, wobble: 0)
        sim.debugDropMote(from: foe)
        #expect(sim.state.motes.count == 1)
        #expect(sim.state.motes[0].pos.y == hero.y + RunSim.dropBelow)
    }

    /// A foe below her drops its mote below itself, not below her.
    @Test func aFoeBelowHerDropsBelowItself() {
        var sim = makeSim()
        let hero = sim.state.hero.pos
        let foe = Foe(id: 1, pos: Vec2(hero.x, hero.y + 150), radius: 9, hp: 1,
                      speed: 60, elite: true, turnGain: 10, wobble: 0)
        sim.debugDropMote(from: foe)
        #expect(sim.state.motes[0].pos.y == foe.pos.y + RunSim.dropBelow)
    }

    /// A wider magnet snags a mote the base reach would let sink past.
    @Test func magnetGrowthWidensTheReach() {
        func collected(magnet: Double) -> Bool {
            var sim = makeSim()
            sim.debugMutate { $0.mods.magnet = magnet }
            // At dist 30: outside base reach (27.9), inside a ×1.6 reach (35.0).
            sim.debugAddMote(at: sim.state.hero.pos + Vec2(30, 0), value: 1)
            for _ in 0..<Int(1.5 / step) { sim.tick(dt: step, input: .idle) }
            return sim.state.essence > 0
        }
        #expect(collected(magnet: 34) == false)       // base: sinks away
        #expect(collected(magnet: 34 * 1.6) == true)  // boosted: snagged
    }
}
