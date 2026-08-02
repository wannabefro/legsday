import Foundation

/// A fusion recipe (R15): two source weapons that, once each is upgraded ≥2,
/// let Death deal a FUSION card. `evolution` is the weapon they become. The
/// evolution is a `WeaponDef` (not a card) so the recipe stays a value type
/// with no cycle through `CardDef`.
public struct FusionRecipe: Equatable, Sendable, Codable {
    public var a: String
    public var b: String
    public var evolution: WeaponDef
    /// A rival-pair recipe (the strongest) — reachable only via the U14 offer path.
    public var rivalPair: Bool

    public init(a: String, b: String, evolution: WeaponDef, rivalPair: Bool) {
        self.a = a
        self.b = b
        self.evolution = evolution
        self.rivalPair = rivalPair
    }

    /// Stable key for suppression bookkeeping.
    public var key: String { "\(a)+\(b)" }
}

/// Fusion tuning (R15). The recipe table is placeholder-by-design: one neutral
/// pair and one rival pair; the full table is deferred.
public enum Fusions {
    /// Growth levels each source must reach before a recipe can fire.
    public static let upgradeGate = 2
    /// Small essence boon for declining a fusion.
    public static let declineBoon: Double = 6
}

public extension CardLibrary {
    /// The placeholder recipe table: Church+Grave (neutral) and Church+Plague
    /// (rival-pair, reachable only via the Herald offer).
    static let fusionSeed: [FusionRecipe] = [
        FusionRecipe(a: "the_thurible", b: "the_passing_bell",
            evolution: evolution(id: "the_requiem", damage: 2, reach: 1.3),
            rivalPair: false),
        FusionRecipe(a: "the_thurible", b: "the_censer_rot",
            evolution: evolution(id: "the_plague_saint", damage: 3, reach: 1.4),
            rivalPair: true),
    ]

    private static func evolution(id: String, damage: Int, reach: Double) -> WeaponDef {
        WeaponDef(id: id,
            formA: CardChoice(label: "the evolution", subtitle: "born of fusion",
                              effects: [.addBolts(damage), .multiply(.magnet, reach)]),
            formB: CardChoice(label: "the evolution", subtitle: "born of fusion",
                              effects: [.addBolts(damage), .multiply(.magnet, reach)]),
            growthAxes: [
                CardChoice(label: "power", subtitle: "+1 bolt", effects: [.addBolts(1)]),
                CardChoice(label: "reach", subtitle: "magnet ×1.15", effects: [.multiply(.magnet, 1.15)]),
            ],
            signature: CardChoice(label: "cataclysm", subtitle: "hold — smite every foe",
                                  effects: [.smiteAllFoes]))
    }
}

extension RunSim {
    /// Total growth an owned weapon has accrued; −1 if unowned (so recipe gates
    /// never count an absent weapon).
    func weaponUpgradeLevel(_ id: String) -> Int {
        guard let w = state.weapons[id], w.owned else { return -1 }
        return w.levels.reduce(0, +)
    }

    /// Queue a FUSION when a recipe's sources are both upgraded past the gate and
    /// it hasn't been declined this run. One at a time.
    mutating func checkFusionRecipes() {
        guard state.card == nil, state.pendingFusion == nil else { return }
        for r in catalog.fusions where !state.suppressedFusions.contains(r.key) {
            if weaponUpgradeLevel(r.a) >= Fusions.upgradeGate,
               weaponUpgradeLevel(r.b) >= Fusions.upgradeGate {
                state.pendingFusion = r
                return
            }
        }
    }

    /// Death deals the queued fusion ahead of the normal queue (ink-spined).
    mutating func maybeDealFusion() {
        guard state.card == nil, let r = state.pendingFusion else { return }
        state.pendingFusion = nil
        state.card = ActiveCard(def: fusionCard(r), deathDealt: true)
    }

    /// The FUSION card: fuse (left) or decline (right); it carries the recipe.
    func fusionCard(_ r: FusionRecipe) -> CardDef {
        CardDef(id: "fusion_\(r.key)", title: "FUSION", spine: .inkspine, isDeath: true,
            left: CardChoice(label: "fuse", subtitle: "lose both, gain the evolution", effects: []),
            right: CardChoice(label: "decline", subtitle: "+\(Int(Fusions.declineBoon)) essence", effects: []),
            fusion: r)
    }

    /// Fuse: remove both sources, grant the evolution at their combined level, and
    /// convert remaining deck copies of the sources into evolution upgrade draws.
    mutating func fuseFusion(_ r: FusionRecipe) {
        let combined = max(0, weaponUpgradeLevel(r.a)) + max(0, weaponUpgradeLevel(r.b))
        state.weapons[r.a] = nil
        state.weapons[r.b] = nil
        if r.a == Chain.id || r.b == Chain.id { state.rope = nil }
        state.weapons[r.evolution.id] = WeaponState(owned: true, form: 0, levels: [combined, 0])
        for e in r.evolution.formA.effects { apply(e) } // the evolution's base power

        let evoCard = evolutionCard(r)
        for i in state.deck.indices where state.deck[i].id == r.a || state.deck[i].id == r.b {
            state.deck[i] = evoCard // future draws upgrade the evolution
        }
    }

    /// Decline: a small essence boon; the recipe never re-fires this run.
    mutating func declineFusion(_ r: FusionRecipe) {
        state.essence += Fusions.declineBoon
        if !state.suppressedFusions.contains(r.key) { state.suppressedFusions.append(r.key) }
    }

    /// A weapon card for an evolution — dealt when a converted deck copy comes up.
    func evolutionCard(_ r: FusionRecipe) -> CardDef {
        CardDef(id: r.evolution.id, title: r.evolution.id.replacingOccurrences(of: "_", with: " ").uppercased(),
            spine: .inkspine, isDeath: false,
            left: CardChoice(label: "the evolution", subtitle: "", effects: []),
            right: CardChoice(label: "the evolution", subtitle: "", effects: []),
            weapon: r.evolution)
    }
}
