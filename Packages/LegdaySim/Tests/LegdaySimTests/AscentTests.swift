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
}
