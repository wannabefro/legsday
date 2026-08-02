// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

/// U18 — the Finale and keep-running (R17, AE5): Death deals on schedule,
/// either release commits, keep-running ramps the scroll and stops forks.
struct FinaleTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1, finaleTime: 720)

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1, catalog: .seed)
    }

    /// Death deals the Finale at the arrival time even with no essence banked.
    @Test func finaleDealsAtArrivalRegardlessOfEssence() {
        var sim = makeSim()
        // Cross the arrival time: no kills, no essence, no pending card.
        sim.debugMutate { $0.time = 720.01; $0.nextForkTime = 1e9 }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(sim.state.finaleDealt)
        #expect(sim.state.card?.def.id == Finale.cardId)
        #expect(sim.state.card?.deathDealt == true)
        #expect(sim.state.essence == 0) // essence was never a gate
    }

    /// The Finale cannot spring back — any release commits a side. Keep-running
    /// is the right arm.
    @Test func finaleIsMandatoryAndKeepRunningCommits() {
        var sim = makeSim()
        sim.debugMutate { $0.finaleDealt = true
            $0.card = ActiveCard(def: CardLibrary.finaleCard, deathDealt: true) }
        // A release past the 30% threshold — but even a small release commits.
        sim.tick(dt: 0.016, input: Input(phase: .began, location: Vec2(196, 500)))
        sim.tick(dt: 0.05, input: Input(phase: .moved, location: Vec2(250, 500)))
        sim.tick(dt: 0.016, input: Input(phase: .ended, location: Vec2(250, 500)))
        #expect(sim.state.keepRunning)
        #expect(sim.state.card!.committing)
    }

    /// Turn & fight requests the duel (U19 consumes it); a left release commits.
    @Test func turnAndFightRequestsDuel() {
        var sim = makeSim()
        sim.debugMutate { $0.finaleDealt = true
            $0.card = ActiveCard(def: CardLibrary.finaleCard, deathDealt: true) }
        sim.tick(dt: 0.016, input: Input(phase: .began, location: Vec2(196, 500)))
        sim.tick(dt: 0.05, input: Input(phase: .moved, location: Vec2(140, 500)))
        sim.tick(dt: 0.016, input: Input(phase: .ended, location: Vec2(140, 500)))
        #expect(!sim.state.keepRunning)
        #expect(sim.state.duelRequested)
    }

    /// After keep-running, the scroll strictly increases without bound.
    @Test func keepRunningRampsScrollForever() {
        var sim = makeSim()
        sim.debugMutate { $0.finaleDealt = true; $0.keepRunning = true }
        sim.debugMutate { $0.time = 720 }
        let a = sim.scrollEff()
        sim.debugMutate { $0.time = 780 } // +60s
        let b = sim.scrollEff()
        sim.debugMutate { $0.time = 900 } // +180s
        let c = sim.scrollEff()
        #expect(b > a)
        #expect(c > b)
        #expect(a == 78) // base at arrival
    }

    /// No forks deal once keep-running is chosen (R17).
    @Test func forksStopAfterKeepRunning() {
        var sim = makeSim()
        sim.debugMutate { $0.finaleDealt = true; $0.keepRunning = true
            $0.time = 900; $0.nextForkTime = 900 }
        for _ in 0..<Int(2.0 / RunSim.fixedStep) {
            sim.tick(dt: RunSim.fixedStep, input: .idle)
        }
        #expect(sim.state.card == nil) // no fork dealt
        #expect(sim.state.forkCount == 0)
    }

    /// The caught-state result keeps distance as score with the standard shape.
    @Test func caughtResultKeepsDistanceAndShape() {
        var sim = makeSim()
        sim.debugMutate { $0.finaleDealt = true; $0.keepRunning = true
            $0.time = 800; $0.worldY = 9000 }
        sim.debugMutate { $0.dead = true }
        let r = sim.result()
        #expect(r.ending == .caught)
        #expect(r.fathoms == 900) // distance retained as score
        #expect(r.shards == 90)   // one per 10 fathoms
        #expect(r.felled == 0)
        #expect(r.cardsDrawn == 0)
    }
}
