import Foundation
import Testing
@testable import LegdaySim

/// U14 — rival champions (R16): summoned by hostility thresholds or risk-route
/// shrines, they anchor the fog while alive and pay fog/motes/one rival offer on
/// fell. Covers the second half of AE4.
struct HeraldTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1)
    }

    private static let churchCard = CardDef(id: "c", title: "CHURCH RITE", spine: .gold,
        isDeath: false, left: CardChoice(label: "a", subtitle: "", effects: []),
        right: CardChoice(label: "b", subtitle: "", effects: []), faction: .church)

    private func commitChurch(_ sim: inout RunSim) {
        sim.debugMutate { $0.card = ActiveCard(def: Self.churchCard, deathDealt: false) }
        sim.commitCard(-1)
    }

    /// Church affinity crossing the threshold summons exactly one Plague Herald;
    /// further offers do not respawn it.
    @Test func hostilityCrossingSummonsOneHerald() {
        var sim = makeSim()
        commitChurch(&sim); commitChurch(&sim) // affinity 2 — below threshold
        #expect(sim.state.herald == nil)
        commitChurch(&sim) // affinity 3 == threshold
        #expect(sim.state.herald?.faction == .plague)
        #expect(sim.state.herald?.guardian == false)

        let before = sim.state.herald
        commitChurch(&sim) // affinity 4 — Herald already lives
        #expect(sim.state.herald == before) // no respawn
    }

    /// A risk-route shrine summons a guardian champion on the next step.
    @Test func shrineSummonsGuardianHerald() {
        var sim = makeSim()
        sim.debugMutate { $0.shrinePending = true }
        sim.tick(dt: 0.016, input: Input(phase: .idle, location: Vec2(196, 400)))
        #expect(sim.state.herald != nil)
        #expect(sim.state.herald?.guardian == true)
        #expect(!sim.state.shrinePending)
    }

    /// Kill-push is halved while a Herald lives (the fog holds).
    @Test func killPushHalvedDuringHerald() {
        let foe = Foe(id: 1, pos: Vec2(200, 300), radius: 9, hp: 1, speed: 0, elite: false)

        var base = makeSim()
        base.debugMutate { $0.fogPressure = 100 }
        base.applyFogKill(foe)
        let baseDrop = 100 - base.state.fogPressure

        var withHerald = makeSim()
        withHerald.debugMutate {
            $0.fogPressure = 100
            $0.herald = Herald(faction: .plague, pos: Vec2(0, 40), hp: 8, slamTimer: 2.5, guardian: false)
        }
        withHerald.applyFogKill(foe)
        let heraldDrop = 100 - withHerald.state.fogPressure

        #expect(baseDrop > 0)
        #expect(abs(heraldDrop - baseDrop * Heralds.killPushFactor) < 1e-9)
    }

    /// Fog creep is accelerated only while a Herald lives.
    @Test func fogCreepAcceleratedOnlyWhileHeraldLives() {
        let idle = Input(phase: .idle, location: Vec2(196, 400))
        var withHerald = makeSim()
        withHerald.debugMutate {
            // Far from the hero and very durable → survives the window unfelled.
            $0.herald = Herald(faction: .plague, pos: Vec2(20, 40), hp: 9999, slamTimer: 999, guardian: false)
        }
        var without = makeSim()
        for _ in 0..<40 {
            withHerald.tick(dt: 0.05, input: idle)
            without.tick(dt: 0.05, input: idle)
        }
        #expect(withHerald.state.herald != nil) // still alive
        #expect(withHerald.state.fogPressure > without.state.fogPressure)
    }

    /// Felling the Plague Herald queues exactly one Plague offer and bursts motes.
    @Test func fellingHeraldQueuesOneRivalOffer() {
        var sim = makeSim()
        sim.debugMutate {
            $0.herald = Herald(faction: .plague, pos: $0.hero.pos, hp: 1, slamTimer: 2.5, guardian: false)
            $0.fogPressure = 100
            $0.attackTimer = 0
        }
        let motesBefore = sim.state.motes.count
        sim.autoAttack(dt: 0.1) // in range, hp 1 → felled

        #expect(sim.state.herald == nil)
        #expect(sim.state.pendingOffers.count == 1)
        #expect(sim.state.pendingOffers.first?.faction == .plague)
        #expect(sim.state.motes.count == motesBefore + Heralds.moteBurst) // mote burst
        #expect(sim.state.fogPressure < 100) // fog pushback burst
    }

    /// A queued rival offer deals ahead of the normal cadence.
    @Test func rivalOfferDealsFromQueue() {
        var sim = makeSim()
        let plagueOffer = CardLibrary.rivalOfferSeed.first { $0.faction == .plague }!
        sim.debugMutate { $0.pendingOffers = [plagueOffer] }
        sim.tick(dt: 0.016, input: Input(phase: .idle, location: Vec2(196, 400)))
        #expect(sim.state.card?.def.id == plagueOffer.id)
        #expect(sim.state.pendingOffers.isEmpty)
    }
}
