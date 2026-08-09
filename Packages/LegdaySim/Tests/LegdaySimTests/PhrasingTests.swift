import Foundation
import Testing
@testable import LegdaySim

/// The gorge is a sentence, not a corridor. Each segment has a length, a
/// width and a drift, and the transitions carry the meaning.
struct PhrasingTests {
    private static let W = 393.0
    private static let band = Gorge.bandHeight
    private static let screenBands = 22

    private static func filled(seed: UInt64, stage: String = "low_road",
                               through: Double = 120_000) -> Gorge {
        var g = Gorge(width: W, seed: seed)
        g.generate(throughWorldY: through, stageID: stage)
        return g
    }

    /// One reading per band, so a segment of 3 bands is never stepped over.
    private static func kinds(_ g: Gorge, count: Int) -> [Gorge.Segment.Kind] {
        (0..<count).compactMap { g.segment(at: Double($0) * band) }
    }

    private static func runs(_ kinds: [Gorge.Segment.Kind]) -> [Gorge.Segment.Kind] {
        var out: [Gorge.Segment.Kind] = []
        for k in kinds where out.last != k { out.append(k) }
        return out
    }

    @Test func aGateAlwaysOpensIntoAChamber() {
        let order = Self.runs(Self.kinds(Self.filled(seed: 7), count: 3_000))
        var gates = 0
        for (i, kind) in order.enumerated() where kind == .gate && i + 1 < order.count {
            gates += 1
            #expect(order[i + 1] == .chamber)
        }
        #expect(gates >= 5)
    }

    @Test func everyTransitionIsOneTheGrammarAllows() {
        let order = Self.runs(Self.kinds(Self.filled(seed: 21), count: 3_000))
        for i in 1..<order.count {
            let legal = Gorge.followers(after: order[i - 1])
            #expect(legal.contains(order[i]))
        }
    }

    @Test func aSegmentNeverFollowsItself() {
        for kind in Gorge.Segment.Kind.allCases {
            #expect(!Gorge.followers(after: kind).contains(kind))
        }
    }

    @Test func everySegmentKindAppearsOnALongClimb() {
        let seen = Set(Self.kinds(Self.filled(seed: 3), count: 3_000))
        #expect(seen == Set(Gorge.Segment.Kind.allCases))
    }

    @Test func theChannelNeverClosesBelowTheMinimum() {
        for stage in Gorge.widthRanges.keys {
            let g = Self.filled(seed: 5, stage: stage)
            for i in 0..<2_000 {
                let e = g.edges(at: Double(i) * Self.band)
                #expect(e.right - e.left >= Gorge.minimumChannel - 0.5)
            }
        }
    }

    @Test func eachZoneKeepsItsOwnCeiling() {
        for (stage, range) in Gorge.widthRanges {
            let g = Self.filled(seed: 9, stage: stage)
            var widest = 0.0
            for i in 0..<2_000 {
                let e = g.edges(at: Double(i) * Self.band)
                widest = max(widest, e.right - e.left)
            }
            #expect(widest <= range.upper * Self.W + 0.5)
        }
    }

    /// The complaint this replaces: a screen of gorge that goes nowhere. The
    /// old random walk leaned on 30% of screens. This measures 45 to 56.
    @Test func mostScreensNowCarryALean() {
        var leaning = 0, windows = 0
        for seed in UInt64(1)...8 {
            let g = Self.filled(seed: seed)
            let centres = (0..<2_000).map { i -> Double in
                let e = g.edges(at: Double(i) * Self.band)
                return (e.left + e.right) / 2 / Self.W
            }
            for s in stride(from: 0, to: centres.count - Self.screenBands, by: Self.screenBands) {
                windows += 1
                let travel = abs(centres[s + Self.screenBands] - centres[s])
                if travel > 0.08 { leaning += 1 }
            }
        }
        let share = Double(leaning) / Double(windows)
        #expect(share > 0.40, "leaning screens: \(Int(share * 100))%")
    }

    @Test func theSameSeedReplaysTheSameGorge() {
        let a = Self.filled(seed: 44, through: 20_000)
        let b = Self.filled(seed: 44, through: 20_000)
        #expect(a.fingerprint == b.fingerprint)
        #expect(Self.filled(seed: 45, through: 20_000).fingerprint != a.fingerprint)
    }

    /// Generation depends on climb height alone, so a coarse pass must agree.
    @Test func generatingInOneStepMatchesGeneratingInMany() {
        var stepped = Gorge(width: Self.W, seed: 88)
        for i in 1...400 { stepped.generate(throughWorldY: Double(i) * 40, stageID: "orchard") }
        var once = Gorge(width: Self.W, seed: 88)
        once.generate(throughWorldY: 400 * 40, stageID: "orchard")
        #expect(stepped.fingerprint == once.fingerprint)
    }
}
