import Foundation
import Testing
@testable import LegdaySim

/// Furniture reads the phrase it stands in: a cairn in a gate is a wall.
struct FurnitureGrammarTests {
    private static let W = 393.0, H = 852.0
    private static let laneForAPilgrim: Double = 28

    private static func placed(seeds: ClosedRange<UInt64>, seconds: Double)
        -> [(Feature, Gorge.Segment.Kind?, Gorge.Edges)] {
        var out: [(Feature, Gorge.Segment.Kind?, Gorge.Edges)] = []
        for seed in seeds {
            var s = RunSim(tunables: tunables, viewport: Vec2(W, H), seed: seed)
            var seen = Set<Int>()
            for _ in 0..<Int(seconds / RunSim.fixedStep) {
                s.tick(dt: RunSim.fixedStep, input: .idle)
                for f in s.state.features where !seen.contains(f.id) {
                    seen.insert(f.id)
                    out.append((f, s.state.gorge.segment(at: f.terrainY),
                                s.state.gorge.edges(at: f.terrainY)))
                }
            }
        }
        return out
    }

    @Test func nothingStandsInAGate() {
        let all = Self.placed(seeds: 1...6, seconds: 90)
        #expect(all.count >= 20)
        #expect(all.allSatisfy { $0.1 != .gate })
    }

    /// Guards the test above: a run that never meets a gate proves nothing.
    @Test func theseRunsDoMeetGates() {
        let met = (UInt64(1)...6).contains { seed in
            var g = Gorge(width: Self.W, seed: seed)
            g.generate(throughWorldY: 400 * Gorge.bandHeight, stageID: "low_road")
            return (0..<400).contains {
                g.segment(at: Double($0) * Gorge.bandHeight) == .gate
            }
        }
        #expect(met)
    }

    @Test func aCairnAlwaysLeavesOneLaneWiderThanThePilgrim() {
        let cairns = Self.placed(seeds: 1...6, seconds: 90).filter { $0.0.kind == .cairn }
        #expect(cairns.count >= 10)
        for (f, _, edges) in cairns {
            let widest = max((f.x - f.extent) - edges.left,
                             edges.right - (f.x + f.extent))
            let channel = edges.right - edges.left
            #expect(widest > Self.laneForAPilgrim && channel >= Feature.cairnMinimumChannel)
        }
    }

    @Test func coverThinsAsTheChannelTightens() {
        let order: [Gorge.Segment.Kind] = [.chamber, .breath, .bend, .squeeze, .gate]
        let densities = order.map { Feature.density(in: $0) }
        #expect(densities == densities.sorted(by: >) && densities.last == 0)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)
}
