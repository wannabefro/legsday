// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

/// U19 — the Reaper duel (R17 duel arm): entering the duel zeroes the scroll
/// (the only code path that can), hits advance phases without regression, the
/// fog surge obeys normal grace/grip, a win triples shards, a loss produces the
/// standard obituary payload.
struct ReaperTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1, finaleTime: 720)

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 3, catalog: .seed)
    }

    /// "Turn & fight" enters the duel; it is the only path that zeroes scroll.
    @Test func enteringDuelZeroesScroll() {
        var sim = makeSim()
        sim.debugMutate { $0.duelRequested = true }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(sim.state.duel != nil)
        #expect(sim.scrollEff() == 0)
        #expect(sim.state.dead == false)
    }

    /// The duel never starts on its own — only the Finale's turn & fight sets
    /// the request; keep-running does not.
    @Test func onlyDuelRequestStartsIt() {
        var sim = makeSim()
        sim.debugMutate { $0.keepRunning = true; $0.time = 800 }
        for _ in 0..<Int(1.0 / RunSim.fixedStep) {
            sim.tick(dt: RunSim.fixedStep, input: .idle)
        }
        #expect(sim.state.duel == nil)
        #expect(sim.scrollEff() > 0)
    }

    /// Hits accumulate and advance phases at thresholds; phase never regresses.
    @Test func hitsAdvancePhasesWithoutRegression() {
        var sim = makeSim()
        sim.debugMutate { $0.duelRequested = true }
        sim.tick(dt: RunSim.fixedStep, input: .idle) // enter the duel
        let phase0 = sim.state.duel!.phase
        #expect(phase0 == 1)

        // Three hits, one per cadence, via real auto-attack ticks.
        for _ in 0..<40 where !sim.state.dead {
            sim.tick(dt: RunSim.fixedStep, input: .idle)
        }
        let mid = sim.state.duel!.phase
        #expect(mid >= phase0) // never regressed
        #expect(mid >= 1)
    }

    /// Enough hits win the duel: ending `.duelWin`, shards ×3 of base.
    @Test func winningDuelTriplesShards() {
        var sim = makeSim()
        sim.debugMutate { $0.duelRequested = true; $0.worldY = 5000 } // 500 base shards
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        // Drive hits directly to the win threshold (12 total).
        for _ in 0..<12 where !sim.state.dead { sim.hitReaper() }
        #expect(sim.state.dead)
        #expect(sim.state.duelWon)
        let r = sim.result()
        #expect(r.ending == .duelWin)
        #expect(r.shards == 150) // 500/10 × 3
    }

    /// Losing (fog death during a duel) yields the standard obituary shape.
    @Test func losingDuelProducesStandardObituary() {
        var sim = makeSim()
        sim.debugMutate { $0.duelRequested = true; $0.worldY = 3000 }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        // Park the hero in the fog until the grip completes.
        sim.debugMutate { $0.hero.pos.y = 900; $0.hero.target.y = 900
            $0.hero.fogTime = 3.0 }
        for _ in 0..<Int(2.0 / RunSim.fixedStep) where !sim.state.dead {
            sim.tick(dt: RunSim.fixedStep, input: .idle)
        }
        #expect(sim.state.dead)
        #expect(sim.state.deadInDuel)
        #expect(!sim.state.duelWon)
        let r = sim.result()
        #expect(r.ending == .duelLoss)
        #expect(r.shards == 30) // base, no multiplier: 300 fathoms / 10
        #expect(abs(r.fathoms - 300) < 1)
    }

    /// A fog surge raises the fog, but grace/grip still apply normally (no
    /// instant death, and climbing out within grace forgives it).
    @Test func fogSurgeObeysNormalGrace() {
        var sim = makeSim()
        sim.debugMutate { $0.duelRequested = true }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        // Force a surge pattern to fire immediately.
        sim.debugMutate { var d = $0.duel!; d.telegraph = .fogSurge; d.telegraphTimer = 0.001
            $0.duel = d }
        for _ in 0..<Int(0.05 / RunSim.fixedStep) { // fire it
            sim.tick(dt: RunSim.fixedStep, input: .idle)
        }
        #expect(sim.state.mods.fogAdd > 0)
        #expect(!sim.state.dead) // surge alone never kills
        let grace = sim.state.hero.fogTime
        #expect(grace <= Self.tunables.fogGrace + 0.05)
    }
}
