import Foundation
import Testing
@testable import LegdaySim

/// The Ascent — five named stages resolved from fathoms (unit 1).
struct AscentTests {
    @Test func tableHasFiveStagesInOrder() {
        #expect(Ascent.stages.count == 5)
        #expect(Ascent.stages.map(\.fromFathoms) == [0, 280, 620, 960, 1200])
        #expect(Ascent.stages.last!.name == "THE RECKONING")
    }

    /// A fathom inside a stage resolves to it; the boundary is inclusive on the
    /// start. The last stage has no end.
    @Test func stageBoundariesResolve() {
        #expect(Ascent.stage(atFathoms: 0).name == "THE LOW ROAD")
        #expect(Ascent.stage(atFathoms: 279).name == "THE LOW ROAD")
        #expect(Ascent.stage(atFathoms: 280).name == "THE ORCHARD")
        #expect(Ascent.stage(atFathoms: 619).name == "THE ORCHARD")
        #expect(Ascent.stage(atFathoms: 620).name == "THE OSSUARY")
        #expect(Ascent.stage(atFathoms: 959).name == "THE OSSUARY")
        #expect(Ascent.stage(atFathoms: 960).name == "THE SPIRE")
        #expect(Ascent.stage(atFathoms: 1199).name == "THE SPIRE")
        #expect(Ascent.stage(atFathoms: 1200).name == "THE RECKONING")
        #expect(Ascent.stage(atFathoms: 999_999).name == "THE RECKONING")
    }

    /// The table's multipliers match the agreed design doc values.
    @Test func stageMultipliersMatchDoc() {
        func stage(_ name: String) -> AscentStage { Ascent.stages.first { $0.name == name }! }
        #expect(stage("THE ORCHARD").spawn == 1.15)
        #expect(stage("THE ORCHARD").fogCreep == 1.05)
        #expect(stage("THE SPIRE").scroll == 1.10)
        #expect(stage("THE RECKONING").faction == nil)
        #expect(stage("THE SPIRE").faction == .church)
    }

    /// On entry to a stage, its faction's threat card is shuffled into the deck.
    @Test func stageEntrySeedsItsThreatCard() {
        let t = Tunables(scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4,
                         cardCostIncrement: 1)
        var sim = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 3,
                         catalog: .seed)
        let before = Set(sim.state.deck.map(\.id))
        // Enter THE ORCHARD (plague).
        sim.debugMutate { $0.worldY = 280 * 10 }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let after = Set(sim.state.deck.map(\.id))
        let plague = CardLibrary.threatSeed.first { $0.faction == .plague }!
        #expect(after.contains(plague.id))
        #expect(!before.contains(plague.id))
        // Once only — re-entering the same stage does not double-seed.
        let count = sim.state.deck.filter { $0.id == plague.id }.count
        #expect(count == 1)
    }

    /// THE LOW ROAD does not seed, even though its table faction is wild.
    @Test func lowRoadDoesNotSeedItsThreat() {
        let t = Tunables(scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4,
                         cardCostIncrement: 1)
        var sim = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 3,
                         catalog: .seed)
        // The LOW ROAD is the starting stage; a step at its start must not seed.
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let wild = CardLibrary.threatSeed.first { $0.faction == .wild }!
        #expect(!sim.state.deck.contains(where: { $0.id == wild.id }))
        #expect(sim.state.seededStages.isEmpty)
    }

    /// The stage multiplier scales the base spawn rate before Mods.
    @Test func spawnRateScalesWithStage() {
        let t = Tunables(scroll: 78, spawn: 1.7, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4,
                         cardCostIncrement: 1)
        var sim = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 1)
        let low = sim.spawnRate()
        sim.debugMutate { $0.worldY = Ascent.spireFathoms * 10
            $0.stage = Ascent.stage(atFathoms: $0.worldY / 10) }
        let spire = sim.spawnRate()
        #expect(abs(spire / low - 1.50) < 0.001)
    }

    /// Entering a stage emits one stageEntered frame event.
    @Test func stageEntryEmitsEvent() {
        let t = Tunables(scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
                         fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
                         downBias: 0.35, cardSlow: 0.005, firstCardCost: 4,
                         cardCostIncrement: 1)
        var sim = RunSim(tunables: t, viewport: Vec2(393, 852), seed: 3)
        sim.debugMutate { $0.worldY = 280 * 10 }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let entered = sim.state.frameEvents.compactMap { event -> String? in
            if case let .stageEntered(s) = event { return s.name }
            return nil
        }
        #expect(entered == ["THE ORCHARD"])
    }
}
