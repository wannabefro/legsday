import Foundation

/// The run's card content as data (KTD-7): the drafted-deck source (`player`)
/// and Death's deck (`death`). U10 loads this from bundled `cards.json`; the
/// in-code `CardLibrary` seed remains the canonical default (and the source the
/// JSON is generated from), so tests construct sims without a bundle.
public struct CardCatalog: Codable, Equatable, Sendable {
    public var player: [CardDef]
    public var death: [CardDef]

    public init(player: [CardDef], death: [CardDef]) {
        self.player = player
        self.death = death
    }

    /// The in-code seed set (graybox parity).
    public static let seed = CardCatalog(player: CardLibrary.playerSeed,
                                         death: CardLibrary.deathSeed)
}

public extension CardCatalog {
    enum LoadError: Error, Equatable { case resourceMissing }

    /// Decodes a catalog from JSON. An unknown effect name / malformed card
    /// throws (no silent fallback) — the U10 contract.
    static func decoded(from data: Data) throws -> CardCatalog {
        try JSONDecoder().decode(CardCatalog.self, from: data)
    }

    /// Loads `cards.json` from the given bundle (the app bundle by default).
    static func bundled(in bundle: Bundle = .main) throws -> CardCatalog {
        guard let url = bundle.url(forResource: "cards", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        return try decoded(from: Data(contentsOf: url))
    }
}
