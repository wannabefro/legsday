import Foundation
import Testing
import LegdaySim

/// The shipped cards.json decodes and matches the in-code seed — so a run plays
/// entirely from bundled data, and the JSON can't silently drift from the seed.
struct CardsBundleTests {
    @Test func shippedCardsMatchSeed() throws {
        let catalog = try CardCatalog.bundled()
        #expect(catalog == CardCatalog.seed)
    }
}
