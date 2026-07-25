import Foundation

/// A rival champion (R16): a durable elite that anchors the fog while it lives
/// and, when felled, pays fog, motes, and the run's only rival-card offer.
public struct Herald: Equatable, Sendable {
    public var faction: Faction
    public var pos: Vec2
    public var hp: Int
    public var maxHp: Int
    /// Countdown to the next slam (the placeholder kit — charge + slam).
    public var slamTimer: Double
    /// Spawned by a risk-route shrine (U13) rather than a hostility threshold.
    public var guardian: Bool

    public init(faction: Faction, pos: Vec2, hp: Int, slamTimer: Double, guardian: Bool) {
        self.faction = faction
        self.pos = pos
        self.hp = hp
        self.maxHp = hp
        self.slamTimer = slamTimer
        self.guardian = guardian
    }
}

/// Herald tuning (R16). Thresholds and the kit are placeholder-by-design
/// (Outstanding Questions): the engine rules — anchor while alive, pay on fell,
/// no respawn — are the deliverable.
public enum Heralds {
    public static let hp = 8                 // attack cadences to fell
    public static let hostilityThreshold = 3 // rival affinity that summons a champion
    public static let slamInterval: Double = 2.5
    public static let slamImpulse: Double = 100
    public static let fogBurst: Double = 60  // pushback on fell
    public static let moteBurst = 6
    public static let creepMult: Double = 1.6 // fog creep while a Herald lives
    public static let killPushFactor: Double = 0.5 // kill-push halved while it lives
    public static let spawnY: Double = 40
}

public extension CardLibrary {
    /// One rival offer per faction — the boon a felled Herald yields, and the
    /// only in-run source of rival-faction cards (the path to U15's rival-pair
    /// fusions). Placeholder boons; U15 refines the weapon-bearing ones.
    static let rivalOfferSeed: [CardDef] = [
        offer(id: "church_offer", title: "A CHURCH RELIC", spine: .gold, faction: .church,
              label: "take the ward", subtitle: "footing +25%", effects: [.multiply(.footing, 1.25)]),
        plagueWeapon, // the Plague weapon — the only in-run path to a Church+Plague pair
        offer(id: "grave_offer", title: "A GRAVE RELIC", spine: .grave, faction: .grave,
              label: "take the lantern", subtitle: "magnet ×1.5", effects: [.multiply(.magnet, 1.5)]),
        offer(id: "wild_offer", title: "A WILD RELIC", spine: .rust, faction: .wild,
              label: "take the thorn", subtitle: "stride +18%", effects: [.multiply(.gain, 1.18)]),
    ]

    private static func offer(id: String, title: String, spine: CardSpine, faction: Faction,
                              label: String, subtitle: String, effects: [Effect]) -> CardDef {
        CardDef(id: id, title: title, spine: spine, isDeath: false,
                left: CardChoice(label: label, subtitle: subtitle, effects: effects),
                right: CardChoice(label: "leave it", subtitle: "nothing happens", effects: []),
                faction: faction)
    }
}

extension RunSim {
    /// The rival most provoked by current affinities — the champion a shrine
    /// summons. Defaults to Plague when no faction is favored.
    func mostProvokedRival() -> Faction {
        let top = Faction.allCases.max { (state.affinity[$0] ?? 0) < (state.affinity[$1] ?? 0) }
        if let f = top, (state.affinity[f] ?? 0) > 0 { return f.rival }
        return .plague
    }

    /// Summon a champion if none lives (R16 — one at a time, no respawn).
    mutating func spawnHerald(faction: Faction, guardian: Bool) {
        guard state.herald == nil else { return }
        state.herald = Herald(faction: faction, pos: Vec2(state.width / 2, Heralds.spawnY),
                              hp: Heralds.hp, slamTimer: Heralds.slamInterval, guardian: guardian)
    }

    /// A hostility threshold crossing summons the favored faction's rival. Called
    /// on each accepted offer; the exact-equality test fires once per faction
    /// (affinity climbs by 1), and the alive-guard blocks overlap.
    mutating func checkHostilityHeralds() {
        guard state.herald == nil else { return }
        for f in Faction.allCases where (state.affinity[f] ?? 0) == Heralds.hostilityThreshold {
            spawnHerald(faction: f.rival, guardian: false)
            return
        }
    }

    /// A risk-route shrine (U13) summons a guardian champion.
    mutating func maybeSpawnShrineHerald() {
        guard state.shrinePending, state.herald == nil else { return }
        spawnHerald(faction: mostProvokedRival(), guardian: true)
        state.shrinePending = false
    }

    /// Advance the Herald's kit: a periodic slam shoves the Pilgrim (displacement,
    /// never HP — R3).
    mutating func updateHerald(dt: Double) {
        guard var h = state.herald else { return }
        h.slamTimer -= dt
        if h.slamTimer <= 0 {
            h.slamTimer = Heralds.slamInterval
            if state.hero.invuln <= 0 {
                state.hero.vel.y += Heralds.slamImpulse / state.mods.footing
                state.hero.invuln = tunables.iframes
                state.frameEvents.append(.heroShoved(at: state.hero.pos))
            }
        }
        state.herald = h
    }

    /// Fell consequences: fog pushback burst, mote burst, and exactly one queued
    /// rival-faction offer — the only in-run rival-card source (R16).
    mutating func fellHerald(_ h: Herald) {
        state.herald = nil
        state.kills += 1
        state.frameEvents.append(.foeDown(at: h.pos, elite: true))
        state.fogPressure = max(0, state.fogPressure - Heralds.fogBurst)
        for i in 0..<Heralds.moteBurst {
            let a = Double(i) / Double(Heralds.moteBurst) * (.pi * 2)
            dropMote(Foe(id: 0, pos: Vec2(h.pos.x + cos(a) * 20, h.pos.y + sin(a) * 20),
                         radius: 9, hp: 0, speed: 0, elite: true))
        }
        if let offer = catalog.rivalOffers.first(where: { $0.faction == h.faction }) {
            state.pendingOffers.append(offer)
        }
    }

    /// Deal a queued rival offer when the stage is clear (free, ahead of the
    /// normal cadence).
    mutating func maybeDealOffer() {
        guard state.card == nil, !state.pendingOffers.isEmpty else { return }
        state.card = ActiveCard(def: state.pendingOffers.removeFirst(), deathDealt: false)
    }
}
