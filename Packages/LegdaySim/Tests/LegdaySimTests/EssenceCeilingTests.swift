// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
@testable import LegdaySim

private let noSpawn = Tunables(
    scroll: 78, spawn: 0, shove: 120, iframes: 0.55,
    fogGrace: 0.8, fogGrip: 2.4, fogCreep: 1.1, killPush: 0.9,
    downBias: 0.35, cardSlow: 0.005, firstCardCost: 4, cardCostIncrement: 1
)
private let viewport = Vec2(393, 852)
private func makeSim() -> RunSim {
    RunSim(tunables: noSpawn, viewport: viewport, seed: 5)
}

/// Essence buys the next Fate Card, so an essence multiplier is the one mod
/// that pays for more of itself. Ten authored faces multiply it. Left
/// unbounded a bot run reached 2^28 essence and drew 111 cards.
struct EssenceCeilingTests {

    /// Stacking pays until the ceiling, and the ceiling holds exactly.
    @Test func essenceStackingStopsAtTheCeiling() {
        var sim = makeSim()
        sim.apply(.multiply(.essMul, 2))
        #expect(sim.state.mods.essMul == 2)
        sim.apply(.multiply(.essMul, 2))
        #expect(sim.state.mods.essMul == 4)
        // The next double would reach 8; the ceiling is 6.
        sim.apply(.multiply(.essMul, 2))
        #expect(sim.state.mods.essMul == RunSim.essMulCeiling)
    }

    /// A further multiply past the ceiling adds nothing at all.
    @Test func aMultiplyPastTheCeilingIsInert() {
        var sim = makeSim()
        for _ in 0..<12 { sim.apply(.multiply(.essMul, 2)) }
        #expect(sim.state.mods.essMul == RunSim.essMulCeiling)
    }

    /// The ceiling binds the credit, not just the field: a mote at the ceiling
    /// pays 6, never 4096.
    @Test func aMoteAtTheCeilingPaysTheCeiling() {
        var sim = makeSim()
        for _ in 0..<12 { sim.apply(.multiply(.essMul, 2)) }
        sim.debugAddMote(at: sim.state.hero.pos + Vec2(20, 0), value: 1)
        for _ in 0..<Int(1.0 / RunSim.fixedStep) { sim.tick(dt: RunSim.fixedStep, input: .idle) }
        #expect(sim.state.essence == RunSim.essMulCeiling)
    }

    /// No other mod is capped — only the one that buys cards.
    @Test func theCeilingIsEssenceOnly() {
        var sim = makeSim()
        for _ in 0..<12 { sim.apply(.multiply(.magnet, 2)) }
        #expect(sim.state.mods.magnet > RunSim.essMulCeiling)
    }
}
