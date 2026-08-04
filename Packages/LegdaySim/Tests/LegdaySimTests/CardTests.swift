import Foundation
import Testing
@testable import LegdaySim

// spawn: 0 isolates the card system from ambient combat/charge.
private let cardDefaults = Tunables(
    scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim(seed: UInt64 = 21) -> RunSim {
    RunSim(tunables: cardDefaults, viewport: viewport, seed: seed)
}
private let step = RunSim.fixedStep
private func knuckle() -> CardDef { CardLibrary.playerSeed.first { $0.id == "second_knuckle" }! }
private let gate = DeathDeck.gateTime(finaleTime: cardDefaults.finaleTime)

struct CardTests {

    /// The card cost escalates 4 → 5 → 6 (firstCardCost, +increment).
    @Test func costSequenceEscalates() {
        var sim = makeSim()
        #expect(sim.state.essNeed == 4)
        sim.debugMutate { $0.charge = 4 }
        sim.tick(dt: 1.0 / 60, input: .idle)
        #expect(sim.state.card != nil)
        #expect(sim.state.essNeed == 5)
        #expect(sim.state.charge == 0)

        sim.debugMutate { $0.card = nil; $0.charge = 5 }
        sim.tick(dt: 1.0 / 60, input: .idle)
        #expect(sim.state.essNeed == 6)
    }

    /// AE3 (R11/R21): past the gate a spent deck falls to Death (flagged), and
    /// Death's deck cycles.
    @Test func deckExhaustionDealsDeathAndCyclesPastTheGate() {
        var sim = makeSim()
        sim.debugMutate { $0.time = gate + 1 }
        let deckSize = CardLibrary.playerSeed.count * 2
        for _ in 0..<deckSize {
            sim.drawCard()
            #expect(sim.state.card!.deathDealt == false)
            sim.debugMutate { $0.card = nil }
        }
        sim.drawCard()
        #expect(sim.state.card!.deathDealt == true) // Death deals
        sim.debugMutate { $0.card = nil }

        // Keep drawing past the death deck's size — it reshuffles and cycles.
        for _ in 0..<(CardLibrary.deathSeed.count + 2) {
            sim.drawCard()
            #expect(sim.state.card!.deathDealt == true)
            sim.debugMutate { $0.card = nil }
        }
    }

    /// R21: before the gate the player's own deck reshuffles instead, so an
    /// early run never collapses onto the three Death cards.
    @Test func deckReshufflesBeforeTheGate() {
        var sim = makeSim()
        let deckSize = CardLibrary.playerSeed.count * 2
        for _ in 0..<(deckSize * 2 + 3) {
            sim.drawCard()
            #expect(sim.state.card!.deathDealt == false)
            sim.debugMutate { $0.card = nil }
        }
        #expect(sim.state.deckSource.count == deckSize)
    }

    /// R21 boundary: the gate is exclusive — at exactly gateTime Death deals.
    @Test func deathTakesTheDeckAtTheGateItself() {
        var sim = makeSim()
        sim.debugMutate { $0.time = gate; $0.deck = [] }
        sim.drawCard()
        #expect(sim.state.card!.deathDealt == true)

        var young = makeSim()
        young.debugMutate { $0.time = gate.nextDown; $0.deck = [] }
        young.drawCard()
        #expect(young.state.card!.deathDealt == false)
    }

    /// R22: the view draws `commitThreshold`, so the constant must be the one
    /// the sim actually enforces. A highlight that disagrees with the rule is
    /// the defect this locks shut. Boundary, not a value near it.
    @Test func commitThresholdIsExactlyWhatCommits() {
        let edge = viewport.x * RunSim.commitThreshold

        var below = makeSim()
        below.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        below.dragCard(offset: edge)          // at the threshold, not past it
        below.releaseCard()
        #expect(below.state.card!.committing == false)
        #expect(below.state.card!.offset == 0) // sprung back, nothing applied

        var above = makeSim()
        above.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        above.dragCard(offset: edge.nextUp)
        above.releaseCard()
        #expect(above.state.card!.committing == true)
    }

    /// The HUD marks the gate, so the sim must answer where it is.
    @Test func pastDeathGateFlipsAtTheGateTime() {
        var sim = makeSim()
        let gateTime = sim.deathGateTime
        #expect(gateTime == cardDefaults.finaleTime * DeathDeck.gateFraction)
        #expect(sim.pastDeathGate == false)
        sim.debugMutate { $0.time = gateTime.nextDown }
        #expect(sim.pastDeathGate == false)
        sim.debugMutate { $0.time = gateTime }
        #expect(sim.pastDeathGate == true)
    }

    /// R21 guard: with no deck to reshuffle, Death deals however young the run.
    @Test func emptyDeckSourceFallsToDeathBeforeTheGate() {
        var sim = makeSim()
        sim.debugMutate { $0.time = 0; $0.deck = []; $0.deckSource = [] }
        sim.drawCard()
        #expect(sim.state.card!.deathDealt == true)
    }

    /// AE2 (R8): while a card is up, the world nearly freezes but the Pilgrim
    /// drifts at full scroll — 3s of deliberation advances ~15ms of sim time
    /// and costs ~3s × scroll of altitude.
    @Test func cardFreezesWorldWhileHeroDrifts() {
        var sim = makeSim()
        sim.debugMutate { $0.charge = 4 }
        sim.tick(dt: 1.0 / 60, input: .idle)          // deal the card
        #expect(sim.state.card != nil)
        for _ in 0..<60 { sim.tick(dt: 1.0 / 60, input: .idle) } // let ts settle to ~0.005

        let t0 = sim.state.time
        let y0 = sim.state.hero.target.y
        for _ in 0..<180 { sim.tick(dt: 1.0 / 60, input: .idle) } // 3s deliberation
        let dTime = sim.state.time - t0
        let dY = sim.state.hero.target.y - y0

        #expect(dTime > 0 && dTime < 0.03)             // ~15ms of game time
        #expect(abs(dY - cardDefaults.scroll * 3) < 15) // ~234px of altitude lost
    }

    /// Committing applies exactly the chosen side's effects, once.
    @Test func commitAppliesChosenSideEffects() {
        var right = makeSim()
        right.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let cd = right.state.mods.attackCooldown
        right.commitCard(1) // right: attack 20% faster → ×0.8
        #expect(abs(right.state.mods.attackCooldown - cd * 0.8) < 1e-9)
        #expect(right.state.card!.committing)

        var left = makeSim()
        left.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        left.commitCard(-1) // left: +1 bolt + timed fog +26
        #expect(left.state.mods.bolts == 2)
        #expect(left.state.mods.fogAdd == 26)
        #expect(left.state.timedEffects.count == 1)
    }

    /// A release below the 30% threshold springs the card back, unapplied;
    /// past it commits.
    @Test func springBackBelowThresholdThenCommitPastIt() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }
        let cd = sim.state.mods.attackCooldown

        sim.dragCard(offset: viewport.x * 0.2) // below 30%
        sim.releaseCard()
        #expect(sim.state.card != nil)
        #expect(!sim.state.card!.committing)
        #expect(sim.state.card!.offset == 0)                 // sprung back
        #expect(sim.state.mods.attackCooldown == cd)         // nothing applied

        sim.dragCard(offset: viewport.x * 0.4) // past 30%
        sim.releaseCard()
        #expect(sim.state.card!.committing)                  // committed
    }

    /// A timed effect applies now and undoes symmetrically when its window ends.
    @Test func timedEffectAppliesAndUndoes() {
        var sim = makeSim()
        sim.apply(.timed(.add(.fogAdd, 26), seconds: 1.0))
        #expect(sim.state.mods.fogAdd == 26)
        #expect(sim.state.timedEffects.count == 1)

        for _ in 0..<Int(1.3 / step) { sim.tick(dt: step, input: .idle) }
        #expect(abs(sim.state.mods.fogAdd) < 1e-9)
        #expect(sim.state.timedEffects.isEmpty)
    }

    /// The ease curve is monotonic in both directions with no jump at commit.
    @Test func timescaleEaseIsMonotonicBothDirections() {
        var sim = makeSim()
        sim.debugMutate { $0.card = ActiveCard(def: knuckle(), deathDealt: false) }

        var last = sim.timescale.current // 1.0
        for _ in 0..<40 {
            sim.tick(dt: 1.0 / 60, input: .idle)
            #expect(sim.timescale.current <= last + 1e-9) // eases down monotonically
            last = sim.timescale.current
        }
        #expect(sim.timescale.current < 0.02) // reached ~cardSlow

        sim.commitCard(1) // begin ease-out
        last = sim.timescale.current
        for _ in 0..<120 {
            sim.tick(dt: 1.0 / 60, input: .idle)
            #expect(sim.timescale.current >= last - 1e-9) // eases up monotonically
            last = sim.timescale.current
        }
        #expect(sim.timescale.current > 0.9) // eased back toward full speed
    }
}
