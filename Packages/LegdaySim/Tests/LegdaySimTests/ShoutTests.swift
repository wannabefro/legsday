import Foundation
import Testing
@testable import LegdaySim

/// `Fusions.shout` replaced `String.uppercased()`, which links Foundation's
/// case tables and cost 45 MB in the WebAssembly build. Card ids are ASCII
/// snake_case, so the two must agree on every id the game ships.
struct ShoutTests {

    /// The replacement matches the API it replaced, for every shipped id.
    @Test func shoutMatchesUppercasedForEveryShippedId() {
        let ids = CardCatalog.seed.player.map(\.id)
            + CardCatalog.seed.weapons.map(\.id)
            + CardCatalog.seed.death.map(\.id)
            + CardLibrary.fusionSeed.map(\.evolution.id)
        #expect(!ids.isEmpty)
        for id in ids {
            let expected = id.replacingOccurrences(of: "_", with: " ").uppercased()
            #expect(Fusions.shout(id) == expected, "\(id)")
        }
    }

    /// An underscore becomes a space, and a digit is left alone.
    @Test func shoutHandlesTheEdgesOfTheAsciiRange() {
        #expect(Fusions.shout("a_z") == "A Z")
        #expect(Fusions.shout("rune_2") == "RUNE 2")
        #expect(Fusions.shout("") == "")
    }
}
