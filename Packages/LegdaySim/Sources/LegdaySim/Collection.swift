import Foundation

/// Reliquary pulls (R19/U21): yield an unowned card or tier an owned one;
/// pity guarantees a new card within 10 pulls.
public struct Collection: Equatable, Sendable {
    /// The cards a pull can yield — the draftable pool.
    public let pool: [CardDef]
    /// Owned copies per card id.
    public var owned: [String: Int]
    /// Pulls since the last new card — the pity counter.
    public private(set) var pity: Int
    /// Total pulls made (for tests and pacing).
    public private(set) var pullsMade: Int

    public static let pityGuarantee = 10
    public static let pullCost = 20
    public static let maxTier = 3

    public init(pool: [CardDef], owned: [String: Int] = [:], pity: Int = 0, pullsMade: Int = 0) {
        self.pool = pool
        self.owned = owned
        self.pity = pity
        self.pullsMade = pullsMade
    }

    /// Cards not yet owned (one copy or none).
    public var unownedIds: [String] {
        pool.map(\.id).filter { (owned[$0] ?? 0) == 0 }
    }

    public var isComplete: Bool { unownedIds.isEmpty }

    /// Draw one pull from the seeded RNG. Pity forces a new card at 10 pulls.
    public mutating func pull(using rng: inout SeededRandom) -> String {
        pullsMade += 1
        pity += 1
        let forcedNew = pity >= Self.pityGuarantee && !isComplete
        let newID: String?
        if forcedNew {
            newID = unownedIds[Int(rng.unit() * Double(unownedIds.count))]
        } else if !isComplete, rng.unit() < newCardChance {
            newID = unownedIds[Int(rng.unit() * Double(unownedIds.count))]
        } else {
            newID = nil
        }
        let id = newID ?? pool[Int(rng.unit() * Double(pool.count))].id
        owned[id, default: 0] += 1
        if newID != nil { pity = 0 }
        return id
    }

    /// Test/debug seam: advance the pity counter to exercise the guarantee.
    public mutating func debugAdvancePity(to value: Int) {
        pity = value
    }

    /// Chance of a new card on a normal pull — low, so the pity carries the
    /// guarantee.
    private var newCardChance: Double { 0.15 }

    /// Tier for an owned card (U11 feeds this into weapon/draft decisions).
    public func tier(of id: String) -> Int {
        min(Self.maxTier, max(1, owned[id] ?? 1))
    }
}
