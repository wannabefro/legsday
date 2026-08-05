import Foundation

/// One named stage of the climb (the Ascent). A stage is data, not a type
/// hierarchy: an id, a name, the fathom it starts at, a spine, a faction, and
/// three multipliers. The multipliers scale the base rates before `Mods`
/// (card effects) apply — a stage never replaces a card effect.
public struct AscentStage: Equatable, Sendable {
    public let id: String
    public let name: String
    public let fromFathoms: Double
    public let spine: CardSpine
    public let faction: Faction?
    public let spawn: Double
    public let fogCreep: Double
    public let scroll: Double

    public init(id: String, name: String, fromFathoms: Double, spine: CardSpine,
                faction: Faction?, spawn: Double, fogCreep: Double, scroll: Double) {
        self.id = id
        self.name = name
        self.fromFathoms = fromFathoms
        self.spine = spine
        self.faction = faction
        self.spawn = spawn
        self.fogCreep = fogCreep
        self.scroll = scroll
    }
}

/// The Ascent table and its fathom-based pacing constants.
public enum Ascent {
    /// Ordered, last stage has no end. Source of truth: design/ascent-stages.md.
    public static let stages: [AscentStage] = [
        AscentStage(id: "low_road", name: "THE LOW ROAD", fromFathoms: 0,
                    spine: .rust, faction: .wild, spawn: 1.00, fogCreep: 1.00, scroll: 1.00),
        AscentStage(id: "orchard", name: "THE ORCHARD", fromFathoms: 280,
                    spine: .plague, faction: .plague, spawn: 1.15, fogCreep: 1.05, scroll: 1.00),
        AscentStage(id: "ossuary", name: "THE OSSUARY", fromFathoms: 620,
                    spine: .grave, faction: .grave, spawn: 1.30, fogCreep: 1.10, scroll: 1.05),
        AscentStage(id: "spire", name: "THE SPIRE", fromFathoms: 960,
                    spine: .gold, faction: .church, spawn: 1.50, fogCreep: 1.20, scroll: 1.10),
        AscentStage(id: "reckoning", name: "THE RECKONING", fromFathoms: 1200,
                    spine: .inkspine, faction: nil, spawn: 1.70, fogCreep: 1.30, scroll: 1.15),
    ]

    /// Fork cadence, in fathoms (was 60s; ≈ 7.8 fathoms/s at base scroll).
    public static let forkCadenceFathoms: Double = 450
    /// Death takes the deck on entry to THE SPIRE (was 0.6 × finaleTime).
    public static let spireFathoms: Double = 960
    /// The Finale deals on entry to THE RECKONING (was finaleTime).
    public static let reckoningFathoms: Double = 1200

    /// The stage containing a given fathom count. Inclusive on the start.
    public static func stage(atFathoms: Double) -> AscentStage {
        stages.last(where: { atFathoms >= $0.fromFathoms }) ?? stages[0]
    }
}
