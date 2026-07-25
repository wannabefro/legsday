import Foundation

/// The run's card content as data (KTD-7): the drafted-deck source (`player`)
/// and Death's deck (`death`). U10 loads this from bundled `cards.json`; the
/// in-code `CardLibrary` seed remains the canonical default (and the source the
/// JSON is generated from), so tests construct sims without a bundle.
public struct CardCatalog: Codable, Equatable, Sendable {
    public var player: [CardDef]
    /// Weapon relic cards (form/growth/signature). Drafted in via U17; kept out
    /// of the ordinary `player` deck so the two pools stay distinct.
    public var weapons: [CardDef]
    /// Rival threat cards interleaved by hostility (U12); one per faction.
    public var threats: [CardDef]
    /// World-owned fork cards dealt on a cadence (U13).
    public var forks: [CardDef]
    public var death: [CardDef]

    public init(player: [CardDef], weapons: [CardDef] = [], threats: [CardDef] = [],
                forks: [CardDef] = [], death: [CardDef]) {
        self.player = player
        self.weapons = weapons
        self.threats = threats
        self.forks = forks
        self.death = death
    }

    private enum CodingKeys: String, CodingKey { case player, weapons, threats, forks, death }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        player = try c.decode([CardDef].self, forKey: .player)
        weapons = try c.decodeIfPresent([CardDef].self, forKey: .weapons) ?? []
        threats = try c.decodeIfPresent([CardDef].self, forKey: .threats) ?? []
        forks = try c.decodeIfPresent([CardDef].self, forKey: .forks) ?? []
        death = try c.decode([CardDef].self, forKey: .death)
    }

    /// The in-code seed set (graybox parity + U11 weapons + U12 threats + U13 forks).
    public static let seed = CardCatalog(player: CardLibrary.playerSeed,
                                         weapons: CardLibrary.weaponSeed,
                                         threats: CardLibrary.threatSeed,
                                         forks: CardLibrary.forkSeed,
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
