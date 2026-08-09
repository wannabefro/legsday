import Foundation
import Testing
@testable import LegdaySim

/// A fork is the greed-against-distance pillar drawn in terrain: two lanes,
/// and the tight one pays double. Both must stay passable or it is a wall.
struct ForkTests {
    private static let W = 393.0

    private static func filled(seed: UInt64, stage: String = "low_road",
                               through: Double = 6_000, width: Double = W) -> Gorge {
        var g = Gorge(width: width, seed: seed)
        g.generate(throughWorldY: through, stageID: stage)
        return g
    }

    private static func forkHeight(_ g: Gorge, upTo: Double = 6_000) -> Double? {
        stride(from: 0.0, to: upTo, by: 17).first { g.spine(at: $0) != nil }
    }

    @Test func theLowRoadForksAtLeastOnceInSixThousandPoints() {
        let g = Self.filled(seed: 11)
        #expect(Self.forkHeight(g) != nil)
        #expect(g.spine(at: 0) == nil)
    }

    @Test func bothLanesStayWiderThanThePilgrim() {
        var narrowest = Double.infinity
        for seed in UInt64(1)...12 {
            let g = Self.filled(seed: seed)
            for i in 0..<400 {
                let y = Double(i) * 15
                guard let island = g.spine(at: y) else { continue }
                let e = g.edges(at: y)
                narrowest = min(narrowest, island.left - e.left, e.right - island.right)
            }
        }
        #expect(narrowest < .infinity)
        #expect(narrowest > 28)
    }

    @Test func theIslandAlwaysSitsInsideTheChannel() {
        var inside = true
        for seed in UInt64(20)...28 {
            let g = Self.filled(seed: seed)
            for i in 0..<400 {
                let y = Double(i) * 15
                guard let island = g.spine(at: y) else { continue }
                let e = g.edges(at: y)
                inside = inside && island.left > e.left && island.right < e.right
                inside = inside && island.left < island.right
            }
        }
        #expect(inside)
    }

    /// The guard on its own: too narrow a channel cannot hold a fork.
    @Test func aChannelBelowTheMinimumNeverForks() {
        let g = Self.filled(seed: 5, width: Gorge.forkMinimumChannel - 1)
        #expect(Self.forkHeight(g) == nil)
        #expect(g.edges(at: 900).right - g.edges(at: 900).left < Gorge.forkMinimumChannel)
    }

    @Test func aLaneIsNamedNarrowOnlyWhenItIsTheTighterOne() {
        let g = Self.filled(seed: 11)
        guard let y = Self.forkHeight(g), let island = g.spine(at: y) else {
            Issue.record("no fork found"); return
        }
        let e = g.edges(at: y)
        let leftWidth = island.left - e.left, rightWidth = e.right - island.right
        let leftLane = g.lane(ofX: (e.left + island.left) / 2, at: y)
        let rightLane = g.lane(ofX: (island.right + e.right) / 2, at: y)
        #expect(leftLane == (leftWidth <= rightWidth ? .narrow : .wide))
        #expect(rightLane == (rightWidth <= leftWidth ? .narrow : .wide))
    }

    @Test func aPointOnTheIslandIsInNoLaneAndAnUnforkedChannelIsOpen() {
        let g = Self.filled(seed: 11)
        guard let y = Self.forkHeight(g), let island = g.spine(at: y) else {
            Issue.record("no fork found"); return
        }
        #expect(g.lane(ofX: (island.left + island.right) / 2, at: y) == .open)
        #expect(g.lane(ofX: 200, at: 0) == .open)
    }

    @Test func aBodyDrivenAtTheIslandLeavesByTheNearerFace() {
        let g = Self.filled(seed: 11)
        guard let y = Self.forkHeight(g), let island = g.spine(at: y) else {
            Issue.record("no fork found"); return
        }
        let fromLeft = g.clamp(Vec2(island.left + 2, 0), radius: 13, at: y)
        let fromRight = g.clamp(Vec2(island.right - 2, 0), radius: 13, at: y)
        #expect(fromLeft.x <= island.left - 13 + 1e-9)
        #expect(fromRight.x >= island.right + 13 - 1e-9)
    }

    @Test func drivingIntoTheIslandKillsTheVelocityThatCarriedYouThere() {
        let g = Self.filled(seed: 11)
        guard let y = Self.forkHeight(g), let island = g.spine(at: y) else {
            Issue.record("no fork found"); return
        }
        var velocity = Vec2(600, 0)
        _ = g.clamp(Vec2(island.left + 2, 0), velocity: &velocity, radius: 13, at: y)
        #expect(velocity.x == 0)
        #expect(velocity.y == 0)
    }

    @Test func aKillInTheNarrowLanePaysDoubleWhatTheWideLanePays() {
        func banked(narrow: Bool) -> Double {
            var sim = RunSim(tunables: Self.tunables, viewport: Vec2(Self.W, 852), seed: 11)
            var screenY = -1.0
            // Climb until a fork is somewhere on screen, then stand in one lane.
            for _ in 0..<24_000 {
                sim.tick(dt: RunSim.fixedStep, input: .idle)
                let candidate = stride(from: 80.0, to: 800.0, by: 10).first {
                    sim.state.gorge.spine(at: sim.terrainY(of: $0)) != nil
                }
                if let candidate { screenY = candidate; break }
            }
            guard screenY > 0 else { return -1 }
            let terrain = sim.terrainY(of: screenY)
            guard let island = sim.state.gorge.spine(at: terrain) else { return -1 }
            let e = sim.state.gorge.edges(at: terrain)
            let leftIsNarrow = island.left - e.left <= e.right - island.right
            let x = (leftIsNarrow == narrow)
                ? (e.left + island.left) / 2
                : (island.right + e.right) / 2
            sim.debugMutate { $0.hero.pos = Vec2(x, screenY) }
            return sim.narrowLaneBonus()
        }
        #expect(banked(narrow: true) == RunSim.narrowLanePay)
        #expect(banked(narrow: false) == 1)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)
}
