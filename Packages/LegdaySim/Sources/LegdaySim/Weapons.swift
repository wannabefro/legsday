import Foundation

/// A weapon's form/growth/signature spec (R13). A weapon card is a `CardDef`
/// carrying one of these. Choices reuse `CardChoice` (label + subtitle +
/// effects), so a weapon's power is data like everything else (KTD-7):
///   - `formA`/`formB`  — the two distinct behaviors chosen on the first draw.
///   - `growthAxes`      — the two axes offered on every repeat draw.
///   - `signature`       — the tier-3 press-and-hold option (nil below tier 3).
public struct WeaponDef: Equatable, Sendable, Codable {
    public var id: String
    public var formA: CardChoice
    public var formB: CardChoice
    public var growthAxes: [CardChoice]
    public var signature: CardChoice?

    public init(id: String, formA: CardChoice, formB: CardChoice,
                growthAxes: [CardChoice], signature: CardChoice? = nil) {
        self.id = id
        self.formA = formA
        self.formB = formB
        self.growthAxes = growthAxes
        self.signature = signature
    }
}

/// Per-weapon run state: unowned → form chosen → levels accrue per growth axis.
public struct WeaponState: Equatable, Sendable {
    public var owned: Bool
    /// 0 = form A (left), 1 = form B (right); nil while unowned.
    public var form: Int?
    /// Accrued level per growth axis (parallel to `WeaponDef.growthAxes`).
    public var levels: [Int]

    public init(owned: Bool = false, form: Int? = nil, levels: [Int] = []) {
        self.owned = owned
        self.form = form
        self.levels = levels
    }
}

/// What a card currently offers — resolved each deal. Ordinary cards mirror
/// their static L/R; a weapon card resolves forms (unowned) or growth axes
/// (owned), plus a signature when the card is tier 3.
public struct CardOffer: Equatable, Sendable {
    public var left: CardChoice
    public var right: CardChoice
    public var signature: CardChoice?

    public init(left: CardChoice, right: CardChoice, signature: CardChoice? = nil) {
        self.left = left
        self.right = right
        self.signature = signature
    }
}

public extension CardLibrary {
    /// Two non-chain weapon families that exercise the whole system (U11). Kits
    /// are placeholder-by-design — the structure (form → growth → signature) is
    /// the deliverable; the effect values live here as editable data.
    static let weaponSeed: [CardDef] = [
        // Church relic: a swung censer. Wide arc vs. focused ember.
        CardDef(id: "the_thurible", title: "THE THURIBLE", spine: .gold, isDeath: false,
            left: CardChoice(label: "the censer", subtitle: "a Church relic", effects: []),
            right: CardChoice(label: "the censer", subtitle: "a Church relic", effects: []),
            weapon: WeaponDef(id: "the_thurible",
                formA: CardChoice(label: "sweeping arc", subtitle: "+1 bolt, wider reach",
                                  effects: [.addBolts(1), .multiply(.magnet, 1.15)]),
                formB: CardChoice(label: "focused ember", subtitle: "attack 15% faster",
                                  effects: [.multiply(.attackCooldown, 0.85)]),
                growthAxes: [
                    CardChoice(label: "reach", subtitle: "magnet ×1.2",
                               effects: [.multiply(.magnet, 1.2)]),
                    CardChoice(label: "ferocity", subtitle: "attack 10% faster",
                               effects: [.multiply(.attackCooldown, 0.9)]),
                ],
                signature: CardChoice(label: "censer flare", subtitle: "hold — +2 bolts",
                                      effects: [.addBolts(2)])),
            faction: .church),
        // Grave relic: a tolling bell. Wide toll vs. deep, footed toll.
        CardDef(id: "the_passing_bell", title: "THE PASSING BELL", spine: .grave, isDeath: false,
            left: CardChoice(label: "the bell", subtitle: "a Grave relic", effects: []),
            right: CardChoice(label: "the bell", subtitle: "a Grave relic", effects: []),
            weapon: WeaponDef(id: "the_passing_bell",
                formA: CardChoice(label: "wide toll", subtitle: "+1 bolt",
                                  effects: [.addBolts(1)]),
                formB: CardChoice(label: "deep toll", subtitle: "footing +20%",
                                  effects: [.multiply(.footing, 1.2)]),
                growthAxes: [
                    CardChoice(label: "resonance", subtitle: "essence ×1.15",
                               effects: [.multiply(.essMul, 1.15)]),
                    CardChoice(label: "weight", subtitle: "footing +10%",
                               effects: [.multiply(.footing, 1.1)]),
                ],
                signature: CardChoice(label: "death knell", subtitle: "hold — smite every foe",
                                      effects: [.smiteAllFoes])),
            faction: .grave),
    ]
}

extension RunSim {
    /// Card tier from how many copies the player owns in the collection (U21
    /// fills this; U11 injects it): 1 copy → tier 1, 2 → tier 2, 3+ → tier 3.
    /// Tier 3 is what unlocks the signature.
    public func tier(for cardId: String) -> Int {
        min(3, max(1, collection[cardId] ?? 1))
    }

    /// What the current card offers, resolved from weapon state. Ordinary cards
    /// pass through their static L/R; weapon cards resolve forms (unowned) or
    /// growth axes (owned), and surface the signature only at tier 3.
    public func currentOffer() -> CardOffer? {
        guard let c = state.card else { return nil }
        if let fork = c.def.fork { return forkOffer(fork) } // resolved by run time (U13)
        guard let w = c.def.weapon else {
            return CardOffer(left: c.def.left, right: c.def.right)
        }
        let st = state.weapons[w.id] ?? WeaponState()
        if !st.owned {
            return CardOffer(left: w.formA, right: w.formB)
        }
        let left = w.growthAxes.first ?? c.def.left
        let right = w.growthAxes.count > 1 ? w.growthAxes[1] : left
        let sig = tier(for: c.def.id) >= 3 ? w.signature : nil
        return CardOffer(left: left, right: right, signature: sig)
    }

    /// Commit a weapon card's L/R: acquire the form on the first draw, else level
    /// the chosen growth axis. Effects apply once; damage scales with the
    /// weapon faction's affinity (R14, U12).
    mutating func commitWeaponChoice(_ w: WeaponDef, dir: Int, faction: Faction?) {
        let mult = faction.map { affinityWeaponMultiplier(for: $0) } ?? 1
        var st = state.weapons[w.id] ?? WeaponState()
        if !st.owned {
            let side = dir > 0 ? 1 : 0
            st.owned = true
            st.form = side
            st.levels = Array(repeating: 0, count: w.growthAxes.count)
            for e in (side == 1 ? w.formB : w.formA).effects { applyWeaponEffect(e, damageMult: mult) }
        } else {
            let axis = dir > 0 ? min(1, w.growthAxes.count - 1) : 0
            if axis < st.levels.count { st.levels[axis] += 1 }
            for e in w.growthAxes[axis].effects { applyWeaponEffect(e, damageMult: mult) }
        }
        state.weapons[w.id] = st
    }

    /// Commit the tier-3 signature (the press-and-hold option): apply its effect
    /// and slide the card away. Does not advance form or growth.
    mutating func commitSignature() {
        guard var c = state.card, !c.committing,
              let sig = c.def.weapon?.signature else { return }
        let mult = c.def.faction.map { affinityWeaponMultiplier(for: $0) } ?? 1
        for e in sig.effects { applyWeaponEffect(e, damageMult: mult) }
        c.committing = true
        c.dir = 0
        state.card = c
    }

    /// Apply a weapon effect, scaling only its *damage* (bolts) by the affinity
    /// multiplier; reach/footing/etc. apply unscaled.
    mutating func applyWeaponEffect(_ e: Effect, damageMult: Double) {
        if case let .addBolts(n) = e, damageMult != 1 {
            state.mods.bolts += Int((Double(n) * damageMult).rounded())
        } else {
            apply(e)
        }
    }
}
