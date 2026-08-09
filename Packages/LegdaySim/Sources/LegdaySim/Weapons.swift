import Foundation

/// A weapon's form/growth/signature spec (R13). A weapon card carries one of
/// these; its power is data like everything else (KTD-7).
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
    /// Accrued level per growth axis (parallel to `growthAxes`).
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
        // Wild relic: a verlet chain that whips with kiting (R21).
        CardDef(id: Chain.id, title: "THE WILD CHAIN", spine: .rust, isDeath: false,
            left: CardChoice(label: "the chain", subtitle: "a Wild relic", effects: []),
            right: CardChoice(label: "the chain", subtitle: "a Wild relic", effects: []),
            weapon: WeaponDef(id: Chain.id,
                formA: CardChoice(label: "long lash", subtitle: "far reach, fast whip",
                                  effects: []),
                formB: CardChoice(label: "heavy head", subtitle: "short, blunt, crushing",
                                  effects: []),
                growthAxes: [
                    CardChoice(label: "reach", subtitle: "rope +20%",
                               effects: [.multiply(.ropeLen, 1.2)]),
                    CardChoice(label: "heft", subtitle: "head +30%",
                               effects: [.multiply(.ropeMass, 1.3)]),
                ],
                signature: CardChoice(label: "whip-crack", subtitle: "hold — threshold ×0.8",
                                      effects: [.multiply(.ropeThreshold, 0.8)])),
            faction: .wild),
    ]

    /// The Plague weapon lives *only* in the rival-offer pool (U14) — never the
    /// draftable `weapons` pool — so a Church+Plague pair is reachable only by
    /// felling a Plague Herald (the U15 rival-pair fusion path).
    static let plagueWeapon = CardDef(id: "the_censer_rot", title: "THE CENSER-ROT",
        spine: .plague, isDeath: false,
        left: CardChoice(label: "the rot", subtitle: "a Plague relic", effects: []),
        right: CardChoice(label: "the rot", subtitle: "a Plague relic", effects: []),
        weapon: WeaponDef(id: "the_censer_rot",
            formA: CardChoice(label: "spreading rot", subtitle: "+1 bolt",
                              effects: [.addBolts(1)]),
            formB: CardChoice(label: "clinging rot", subtitle: "essence ×1.2",
                              effects: [.multiply(.essMul, 1.2)]),
            growthAxes: [
                CardChoice(label: "reach", subtitle: "magnet ×1.2", effects: [.multiply(.magnet, 1.2)]),
                CardChoice(label: "virulence", subtitle: "attack 10% faster",
                           effects: [.multiply(.attackCooldown, 0.9)]),
            ],
            signature: CardChoice(label: "pestilence", subtitle: "hold — +2 bolts",
                                  effects: [.addBolts(2)])),
        faction: .plague)
}

extension RunSim {
    /// Card tier from how many copies the player owns in the collection (U21
    /// fills this; U11 injects it): 1 copy → tier 1, 2 → tier 2, 3+ → tier 3.
    /// Tier 3 is what unlocks the signature.
    public func tier(for cardId: String) -> Int {
        min(3, max(1, collection[cardId] ?? 1))
    }

    /// The resolved offer: static L/R, or forms/growth axes for weapon cards.
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

    /// Commit a weapon card: acquire the form or level a growth axis. Damage
    /// scales with faction affinity (R14).
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
        if w.id == Chain.id, st.owned {
            let base = (st.form == 1 ? Chain.heavyHead : Chain.longLash)
            state.rope = ChainRope(pin: state.hero.pos, count: base.segments, segment: base.segment)
        }
    }

    /// Commit the tier-3 press-and-hold signature: apply its effect, slide away.
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

extension RunSim {
    /// The chain weapon's active rope config, from the chosen form scaled by
    /// growth mods. Nil until the weapon is owned.
    var chainConfig: (form: Chain.Form, segment: Double, headMass: Double, threshold: Double)? {
        guard let w = state.weapons[Chain.id], w.owned else { return nil }
        let base = (w.form == 1 ? Chain.heavyHead : Chain.longLash)
        return (base, base.segment * state.mods.ropeLen,
                base.headMass * state.mods.ropeMass,
                base.threshold * state.mods.ropeThreshold)
    }

    /// Advance the verlet rope pinned to the hero (U16), then resolve the head's
    /// whip damage against overlapping foes.
    mutating func updateRope(dt: Double) {
        guard let config = chainConfig, var rope = state.rope else { return }
        rope.update(dt: dt, pin: state.hero.pos, segment: config.segment, headMass: config.headMass)
        state.rope = rope
        whipDamage(dt: dt, head: rope.head, speed: rope.headSpeed, config: config)
    }

    /// The head hits above a whip-speed threshold; fractional damage per foe.
    mutating func whipDamage(dt: Double, head: Vec2, speed: Double, config: (form: Chain.Form, segment: Double, headMass: Double, threshold: Double)) {
        guard speed > config.threshold else { return }
        let mult = affinityWeaponMultiplier(for: .wild)
        let rate = (speed - config.threshold) * config.form.damageScale * mult
        var fell: [Foe] = []
        for i in state.foes.indices {
            let foe = state.foes[i]
            guard (head - foe.pos).length < Chain.headRadius + foe.radius else { continue }
            state.foes[i].whipAcc += rate * dt
            let dmg = Int(state.foes[i].whipAcc)
            guard dmg > 0 else { continue }
            state.foes[i].whipAcc -= Double(dmg)
            state.foes[i].hp -= dmg
            if state.foes[i].hp <= 0 { fell.append(state.foes[i]) }
        }
        for f in fell {
            state.foes.removeAll { $0.id == f.id }
            state.kills += 1
            state.frameEvents.append(.foeDown(at: f.pos, elite: f.elite))
            onFoeFelled(f)
        }
    }
}


extension RunSim {
    /// The weapon whose form the render draws. Ties go to the lowest id.
    public var activeWeaponID: String? {
        state.weapons
            .filter { $0.value.owned && $0.value.form != nil }
            .max { a, b in
                let ga = a.value.levels.reduce(0, +), gb = b.value.levels.reduce(0, +)
                return ga != gb ? ga < gb : a.key > b.key
            }?.key
    }
}
