import Foundation

/// Playtest-derived tunables, mirroring the graybox prototype's `S` struct
/// (values only — the graybox's per-field min/max/label were editor metadata)
/// plus the card-economy scalars that lived in the graybox's `reset()`.
///
/// Graybox values are CSS pixels of a browser viewport; the sim adopts them as
/// points in a reference coordinate space of the same scale, so they port
/// unchanged. These are starting values, explicitly not final balance (KTD-7).
public struct Tunables: Codable, Equatable, Sendable {
    /// Base upward scroll, px/s, before per-run modifiers (graybox `scroll`).
    public var scroll: Double
    /// Foe spawn-rate multiplier (graybox `spawn`).
    public var spawn: Double
    /// Contact shove impulse; elites ×1.7, scaled by footing (graybox `shove`).
    public var shove: Double
    /// Invulnerability window after a shove, seconds (graybox `iframes`).
    public var iframes: Double
    /// Grace period inside the fog before the grip bites, seconds — a dip is
    /// forgiven (graybox `fogGrace`).
    public var fogGrace: Double
    /// Time under grip until death, seconds (graybox `fogSec`, "fog kill s").
    public var fogGrip: Double
    /// Fog creep, px/s; ramps with run time (graybox `fogCreep`).
    public var fogCreep: Double
    /// Fog pushback per kill, px; elites ×3 (graybox `killPush`).
    public var killPush: Double
    /// Downward bias added to the shove direction (graybox `downBias`).
    public var downBias: Double
    /// World time-scale while a Fate Card is engaged (graybox `cardSlow`).
    public var cardSlow: Double
    /// Essence cost of the first Fate Card (graybox `essNeed` seed).
    public var firstCardCost: Double
    /// Amount each successive card's cost increases (graybox `essNeed += 1`).
    public var cardCostIncrement: Double

    public init(
        scroll: Double,
        spawn: Double,
        shove: Double,
        iframes: Double,
        fogGrace: Double,
        fogGrip: Double,
        fogCreep: Double,
        killPush: Double,
        downBias: Double,
        cardSlow: Double,
        firstCardCost: Double,
        cardCostIncrement: Double
    ) {
        self.scroll = scroll
        self.spawn = spawn
        self.shove = shove
        self.iframes = iframes
        self.fogGrace = fogGrace
        self.fogGrip = fogGrip
        self.fogCreep = fogCreep
        self.killPush = killPush
        self.downBias = downBias
        self.cardSlow = cardSlow
        self.firstCardCost = firstCardCost
        self.cardCostIncrement = cardCostIncrement
    }
}

public extension Tunables {
    /// Error surfaced when the bundled `tunables.json` cannot be located.
    enum LoadError: Error, Equatable {
        case resourceMissing
    }

    /// Decodes tunables from JSON. A missing key throws (`keyNotFound`) rather
    /// than silently defaulting — the U1 contract.
    static func decoded(from data: Data) throws -> Tunables {
        try JSONDecoder().decode(Tunables.self, from: data)
    }

    /// Loads `tunables.json` from the given bundle (the app bundle by default).
    static func bundled(in bundle: Bundle = .main) throws -> Tunables {
        guard let url = bundle.url(forResource: "tunables", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        return try decoded(from: Data(contentsOf: url))
    }
}
