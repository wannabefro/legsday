import Foundation
import Testing
import LegdaySim

/// App-hosted test: verifies the *shipped* `tunables.json` in the app bundle
/// decodes and matches the graybox defaults. The package's `TunablesTests`
/// covers the Codable contract host-side; this one guards the real resource
/// against drift.
struct TunablesBundleTests {
    @Test func shippedTunablesDecodeToGrayboxDefaults() throws {
        let t = try Tunables.bundled()
        #expect(t.scroll == 78)
        #expect(t.spawn == 1.7)
        #expect(t.shove == 120)
        #expect(t.iframes == 0.55)
        #expect(t.fogGrace == 0.8)
        #expect(t.fogGrip == 2.4)
        #expect(t.fogCreep == 1.1)
        #expect(t.killPush == 0.9)
        #expect(t.downBias == 0.35)
        #expect(t.cardSlow == 0.005)
        #expect(t.firstCardCost == 4)
        #expect(t.cardCostIncrement == 1)
    }
}
