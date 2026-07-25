import Foundation

/// The four relic factions. Rivalries are fixed (Church↔Plague, Grave↔Wild):
/// accepting a faction's offers empowers it and sharpens its rival's threats.
public enum Faction: String, CaseIterable, Equatable, Sendable, Codable {
    case church, plague, grave, wild

    /// The opposed faction whose threats sharpen as this one is favored.
    public var rival: Faction {
        switch self {
        case .church: return .plague
        case .plague: return .church
        case .grave: return .wild
        case .wild: return .grave
        }
    }
}

/// One rival threat card scheduled to interleave into the live stream at a
/// given draw ordinal (R10). `faction` is the *threatening* faction (the rival
/// of the favored one).
public struct ThreatInsertion: Equatable, Sendable {
    public var faction: Faction
    public var atDraw: Int

    public init(faction: Faction, atDraw: Int) {
        self.faction = faction
        self.atDraw = atDraw
    }
}

/// The hostility model (R10): draft faction-weighting → a pure forecast of when
/// and how many rival threat cards interleave. More weight → more threats, and
/// earlier. The forecast is a pure function of the weights so U17 can surface it
/// at draft time and the run can schedule against it identically.
public enum Hostility {
    static let baseEarliest = 12      // draws before the first threat at weight 1
    static let minEarliest = 2        // however heavy, threats never precede this
    static let spacing = 4            // draws between a faction's successive threats
    static let maxThreats = 4         // cap per favored faction
    static let perThreatWeight = 3    // weight needed per additional threat

    /// Rival threat insertions for a set of faction weights, sorted by draw.
    /// `weights` maps a *favored* faction to its draft weight; each contributes
    /// threats of its rival. Zero (or absent) weight contributes nothing.
    public static func forecast(weights: [Faction: Int]) -> [ThreatInsertion] {
        var out: [ThreatInsertion] = []
        for f in Faction.allCases {
            let w = weights[f] ?? 0
            guard w > 0 else { continue }
            let count = min(maxThreats, max(1, w / perThreatWeight))
            let earliest = max(minEarliest, baseEarliest - w)
            for i in 0..<count {
                out.append(ThreatInsertion(faction: f.rival, atDraw: earliest + i * spacing))
            }
        }
        return out.sorted { $0.atDraw < $1.atDraw }
    }
}

public extension CardLibrary {
    /// One threat card per faction, interleaved by hostility (U12). Both sides
    /// hurt — a threat is the rival pressing, not an offer. Kits are placeholder
    /// data like the weapons.
    static let threatSeed: [CardDef] = [
        CardDef(id: "the_inquest", title: "THE INQUEST", spine: .gold, isDeath: false,
            left: CardChoice(label: "tithe or burn", subtitle: "pay half your essence",
                             effects: [.scaleEssence(0.5)]),
            right: CardChoice(label: "the pyres light", subtitle: "fog +30 for 30s",
                              effects: [.timed(.add(.fogAdd, 30), seconds: 30)]),
            faction: .church, isThreat: true),
        CardDef(id: "the_rot", title: "THE ROT", spine: .plague, isDeath: false,
            left: CardChoice(label: "the swarm swells", subtitle: "spawns ×1.6 for 30s",
                             effects: [.timed(.multiply(.spawnMul, 1.6), seconds: 30)]),
            right: CardChoice(label: "the miasma", subtitle: "fog +40 for 30s",
                              effects: [.timed(.add(.fogAdd, 40), seconds: 30)]),
            faction: .plague, isThreat: true),
        CardDef(id: "the_interment", title: "THE INTERMENT", spine: .grave, isDeath: false,
            left: CardChoice(label: "dead weight", subtitle: "stride −15% for 30s",
                             effects: [.timed(.multiply(.gain, 0.85), seconds: 30)]),
            right: CardChoice(label: "the earth pulls", subtitle: "scroll +10% forever",
                              effects: [.multiply(.scrollMul, 1.1)]),
            faction: .grave, isThreat: true),
        CardDef(id: "the_bramble", title: "THE BRAMBLE", spine: .rust, isDeath: false,
            left: CardChoice(label: "thorns bind", subtitle: "attack 20% slower for 30s",
                             effects: [.timed(.multiply(.attackCooldown, 1.2), seconds: 30)]),
            right: CardChoice(label: "the wilds creep", subtitle: "fog +26 for 30s",
                              effects: [.timed(.add(.fogAdd, 26), seconds: 30)]),
            faction: .wild, isThreat: true),
    ]
}

extension RunSim {
    static let affinityWeaponScale = 0.5 // +50% weapon damage per affinity point

    /// Weapon-damage multiplier from accumulated affinity for a faction (R14).
    /// Empowers that faction's weapons and no other's.
    func affinityWeaponMultiplier(for f: Faction) -> Double {
        1 + Double(state.affinity[f] ?? 0) * Self.affinityWeaponScale
    }

    /// Faction histogram over the current drafted deck — the hostility input.
    func deckFactionWeights() -> [Faction: Int] {
        var w: [Faction: Int] = [:]
        for card in state.deck {
            if let f = card.faction { w[f, default: 0] += 1 }
        }
        return w
    }
}
