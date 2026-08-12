import Foundation
import Testing
@testable import LegdaySim

/// The canonical tunables JSON, matching `Legday/Resources/tunables.json`.
/// Kept in-package so the Codable contract is host-testable with no simulator
/// (KTD-1). The app-hosted `TunablesBundleTests` verifies the shipped resource.
private let canonicalJSON = """
{
  "scroll": 78,
  "spawn": 1.2,
  "shove": 120,
  "iframes": 0.55,
  "fogGrace": 0.8,
  "fogGrip": 2.4,
  "fogCreep": 1.5,
  "fogCeiling": 190,
  "killPush": 0.9,
  "downBias": 0.35,
  "cardSlow": 0.005,
  "firstCardCost": 5,
  "cardCostIncrement": 10
}
"""

struct TunablesTests {
    /// Every field decodes to the shipped value. Most are the graybox `S`
    /// defaults; `firstCardCost` is 5, not the graybox 20, so a run draws its
    /// whole drafted deck. `fogCeiling` was a constant until it was measured.
    @Test func decodesToShippedValues() throws {
        let t = try Tunables.decoded(from: Data(canonicalJSON.utf8))
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

    /// A JSON missing any key must fail decode — no silent defaults (U1 contract).
    @Test func missingKeyFailsDecode() throws {
        let missingScroll = """
        {
          "spawn": 1.7, "shove": 120, "iframes": 0.55, "fogGrace": 0.8,
          "fogGrip": 2.4, "fogCreep": 1.1, "killPush": 0.9, "downBias": 0.35,
          "cardSlow": 0.005, "firstCardCost": 4, "cardCostIncrement": 1
        }
        """
        #expect(throws: DecodingError.self) {
            try Tunables.decoded(from: Data(missingScroll.utf8))
        }
    }
}
