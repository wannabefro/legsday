import Foundation
import Testing
@testable import LegdaySim

struct GorgeTests {
    private static let W = 393.0

    /// Generate, then read. The render layer reads the same way.
    private static func filled(seed: UInt64, stage: String, through: Double) -> Gorge {
        var g = Gorge(width: W, seed: seed)
        g.generate(throughWorldY: through, stageID: stage)
        return g
    }

    @Test func identicalSeedsProduceIdenticalEdgesAndDifferentSeedsDoNot() {
        let first = Self.filled(seed: 41, stage: "orchard", through: 3_400)
        let replay = Self.filled(seed: 41, stage: "orchard", through: 3_400)
        let other = Self.filled(seed: 42, stage: "orchard", through: 3_400)
        let sample = { (g: Gorge) in (0..<200).map { g.edges(at: Double($0) * 17) } }
        #expect(sample(first) == sample(replay))
        #expect(sample(first) != sample(other))
    }

    /// A zone owns its ceiling. Its floor is the grammar's, because a gate is
    /// meant to close tighter than the zone's resting width.
    @Test func everyStageKeepsItsChannelUnderItsCeilingAndOverTheFloor() {
        var inside = true
        for stage in Ascent.stages {
            let g = Self.filled(seed: 91, stage: stage.id, through: 3_400)
            let range = Gorge.widthRanges[stage.id]!
            for i in 0..<200 {
                let e = g.edges(at: Double(i) * 17)
                let channel = e.right - e.left
                inside = inside && channel >= Gorge.minimumChannel - 0.5
                    && channel / Self.W <= range.upper
            }
        }
        #expect(inside)
        #expect(Gorge.widthRanges.count == Ascent.stages.count)
    }

    @Test func leftEdgeAlwaysPrecedesRightEdgeAtEverySample() {
        let ordered = Ascent.stages.allSatisfy { stage in
            let g = Self.filled(seed: 812, stage: stage.id, through: 2_600)
            return (0..<200).allSatisfy { g.edges(at: Double($0) * 13).left < g.edges(at: Double($0) * 13).right }
        }
        #expect(ordered)
        #expect(!Gorge.widthRanges.isEmpty)
    }

    @Test func heroDrivenIntoLeftWallReturnsInsideAndLosesOutwardVelocity() {
        let g = Self.filled(seed: 6, stage: "ossuary", through: 600)
        let e = g.edges(at: 510)
        var velocity = Vec2(-900, 40)
        let hero = g.clamp(Vec2(e.left - 80, 200), velocity: &velocity, radius: 13, at: 510)
        #expect(hero.x >= e.left + 13)
        #expect(velocity.x == 0)
    }

    @Test func pointExactlyOnEitherBoundaryIsNotMoved() {
        let g = Self.filled(seed: 73, stage: "spire", through: 300)
        let e = g.edges(at: 204)
        #expect(g.clamp(Vec2(e.left, 120), radius: 0, at: 204).x == e.left)
        #expect(g.clamp(Vec2(e.right, 120), radius: 0, at: 204).x == e.right)
    }

    @Test func adjacentWorldPointsHaveOnlySmallInterpolatedEdgeChanges() {
        let g = Self.filled(seed: 508, stage: "reckoning", through: 3_100)
        var largestDelta = 0.0
        for y in 0..<3_000 {
            let a = g.edges(at: Double(y)), b = g.edges(at: Double(y + 1))
            largestDelta = max(largestDelta, abs(a.left - b.left), abs(a.right - b.right))
        }
        #expect(largestDelta < 3)
        #expect(largestDelta > 0)
    }

    @Test func changingStagesKeepsTheExistingBandStreamContinuous() {
        var g = Gorge(width: Self.W, seed: 308)
        g.generate(throughWorldY: 2_800, stageID: "low_road")
        let before = g.edges(at: 2_800)
        g.generate(throughWorldY: 2_801, stageID: "orchard")
        let after = g.edges(at: 2_801)
        #expect(abs(after.left - before.left) < 2)
        #expect(abs(after.right - before.right) < 2)
    }

    /// Reading the gorge must not move the run's RNG, or drawing would change spawns.
    @Test func readingTheGorgeLeavesTheRunRandomStreamUntouched() {
        var sim = RunSim(tunables: Self.tunables, viewport: Vec2(Self.W, 852), seed: 17)
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let before = sim.state.rng.state
        for y in 0..<400 { _ = sim.state.gorge.edges(at: Double(y) * 7) }
        #expect(sim.state.rng.state == before)
        #expect(sim.state.gorge.edges(at: 100).left < sim.state.gorge.edges(at: 100).right)
    }

    @Test func runClampsHeroAndTargetToTheGorgeInsteadOfViewportSides() {
        var sim = RunSim(tunables: Self.tunables, viewport: Vec2(Self.W, 852), seed: 17)
        sim.debugMutate {
            $0.hero.pos.x = -1_000
            $0.hero.target.x = -1_000
            $0.hero.vel.x = -900
        }
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(sim.state.hero.pos.x > 14 && sim.state.hero.target.x > 14)
        #expect(sim.state.hero.vel.x == 0)
    }

    @Test func foesAreHeldInsideTheGorge() {
        var sim = RunSim(tunables: Self.tunables, viewport: Vec2(Self.W, 852), seed: 18)
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let wall = sim.state.gorge.edges(at: sim.state.worldY + sim.state.height - 180).left
        sim.debugAddFoe(at: Vec2(wall - 40, 180), hp: 99, speed: 0)
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        let foe = sim.state.foes.first!
        let edge = sim.state.gorge.edges(at: sim.terrainY(of: foe.pos.y))
        #expect(foe.pos.x >= edge.left + foe.radius)
    }

    @Test func fullFieldOf120FoesStillProducesKills() {
        var sim = RunSim(tunables: Self.tunables, viewport: Vec2(Self.W, 852), seed: 19)
        for _ in 0..<120 {
            sim.debugAddFoe(at: sim.state.hero.pos + Vec2(100, 0), speed: 0)
        }
        #expect(sim.state.foes.count == 120)
        sim.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(sim.state.kills == 1)
        #expect(sim.state.foes.count == 119)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)
}
