// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
import LegdaySim

/// App-hosted test: verifies the *shipped* `tunables.json` decodes to the
/// 2–3 minute run tuning. The package's `TunablesTests` covers the Codable
/// contract host-side; this one guards the real resource against drift.
struct TunablesBundleTests {
    /// Card costs are 5 and +5. Measured over 40 bot runs: that draws 14 cards,
    /// about one pass of the drafted deck. An increment of 1 drew 111, because
    /// essence income compounds and a linear price cannot follow it.
    @Test func shippedTunablesDecodeToGrayboxDefaults() throws {
        let t = try Tunables.bundled()
        #expect(t.scroll == 78)
        #expect(t.spawn == 1.2)
        #expect(t.shove == 120)
        #expect(t.iframes == 0.55)
        #expect(t.fogGrace == 0.8)
        #expect(t.fogGrip == 2.4)
        #expect(t.fogCreep == 1.5)
        #expect(t.fogCeiling == 190)
        #expect(t.killPush == 0.9)
        #expect(t.downBias == 0.35)
        #expect(t.cardSlow == 0.005)
        #expect(t.firstCardCost == 5)
        #expect(t.cardCostIncrement == 10)
    }
}
