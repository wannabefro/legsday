// comment-density: ignore-file — consecutive `#expect` macros read as one comment
import Foundation
import Testing
import LegdaySim

/// App-hosted test: verifies the *shipped* `tunables.json` decodes to the
/// 2–3 minute run tuning. The package's `TunablesTests` covers the Codable
/// contract host-side; this one guards the real resource against drift.
struct TunablesBundleTests {
    /// The shipped resource matches the canonical 2–3 minute tuning values.
    @Test func shippedTunablesDecodeToGrayboxDefaults() throws {
        let t = try Tunables.bundled()
        #expect(t.scroll == 78)
        #expect(t.spawn == 0.3)
        #expect(t.shove == 120)
        #expect(t.iframes == 0.55)
        #expect(t.fogGrace == 0.8)
        #expect(t.fogGrip == 2.4)
        #expect(t.fogCreep == 1.5)
        #expect(t.killPush == 0.9)
        #expect(t.downBias == 0.35)
        #expect(t.cardSlow == 0.005)
        #expect(t.firstCardCost == 20)
        #expect(t.cardCostIncrement == 5)
        #expect(t.finaleTime == 150)
    }
}
