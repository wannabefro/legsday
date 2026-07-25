import Foundation

/// The seed Fate Card set, ported card-for-card from the graybox (5 player
/// cards, 3 Death cards). U10 moves these definitions to bundled JSON; the
/// vocabulary (title, spine, L/R label+subtitle+effects) is fixed here.
public enum CardLibrary {
    public static let playerSeed: [CardDef] = [
        CardDef(id: "second_knuckle", title: "THE SECOND KNUCKLE", spine: .rust, isDeath: false,
            left: CardChoice(label: "+1 bolt", subtitle: "fog +26 for 30s",
                             effects: [.addBolts(1), .timed(.add(.fogAdd, 26), seconds: 30)]),
            right: CardChoice(label: "attack 20% faster", subtitle: "no price",
                              effects: [.multiply(.attackCooldown, 0.8)])),
        CardDef(id: "oath_of_footing", title: "OATH OF FOOTING", spine: .gold, isDeath: false,
            left: CardChoice(label: "footing +35%", subtitle: "shoves resisted",
                             effects: [.multiply(.footing, 1.35)]),
            right: CardChoice(label: "motes worth ×2", subtitle: "motes sink 30% faster",
                              effects: [.multiply(.essMul, 2), .multiply(.moteSink, 1.3)])),
        CardDef(id: "lantern_oil", title: "LANTERN OIL", spine: .grave, isDeath: false,
            left: CardChoice(label: "magnet ×1.6", subtitle: "gather from afar",
                             effects: [.multiply(.magnet, 1.6)]),
            right: CardChoice(label: "+4 essence now", subtitle: "next card sooner",
                              effects: [.addCharge(4)])),
        CardDef(id: "pilgrims_pace", title: "PILGRIM'S PACE", spine: .plague, isDeath: false,
            left: CardChoice(label: "stride +15%", subtitle: "no price",
                             effects: [.multiply(.gain, 1.15)]),
            right: CardChoice(label: "essence ×2", subtitle: "scroll +8% forever",
                              effects: [.multiply(.essMul, 2), .multiply(.scrollMul, 1.08)])),
        CardDef(id: "the_tithe", title: "THE TITHE", spine: .gold, isDeath: false,
            left: CardChoice(label: "smite every foe", subtitle: "fog +30 forever",
                             effects: [.smiteAllFoes, .add(.fogAdd, 30)]),
            right: CardChoice(label: "decline", subtitle: "nothing happens",
                              effects: [])),
    ]

    public static let deathSeed: [CardDef] = [
        CardDef(id: "his_attention", title: "HIS ATTENTION", spine: .inkspine, isDeath: true,
            left: CardChoice(label: "the swarm thickens", subtitle: "spawns ×1.5 for 30s",
                             effects: [.timed(.multiply(.spawnMul, 1.5), seconds: 30)]),
            right: CardChoice(label: "the fog climbs", subtitle: "fog +44 for 30s",
                              effects: [.timed(.add(.fogAdd, 44), seconds: 30)])),
        CardDef(id: "the_toll", title: "THE TOLL", spine: .inkspine, isDeath: true,
            left: CardChoice(label: "pay half your essence", subtitle: "he keeps ledgers",
                             effects: [.scaleEssence(0.5)]),
            right: CardChoice(label: "the fog climbs", subtitle: "+34 forever",
                              effects: [.add(.fogAdd, 34)])),
        CardDef(id: "no_rest", title: "NO REST", spine: .inkspine, isDeath: true,
            left: CardChoice(label: "the road quickens", subtitle: "scroll +12% forever",
                             effects: [.multiply(.scrollMul, 1.12)]),
            right: CardChoice(label: "your arm tires", subtitle: "attack 25% slower for 30s",
                              effects: [.timed(.multiply(.attackCooldown, 1.25), seconds: 30)])),
    ]
}

extension RunSim {
    private static let riseRate: Double = 5      // rise-in per second
    private static let slideSpeed: Double = 2000 // commit slide-off, px/s

    /// Essence charges the next Fate Card; when full, the card is dealt and the
    /// cost escalates (graybox `essNeed += 1`). Only one card is up at a time.
    mutating func maybeDrawCard() {
        guard state.card == nil, state.charge >= state.essNeed else { return }
        state.charge = 0
        state.essNeed += tunables.cardCostIncrement
        drawCard()
    }

    /// Drag the current card horizontally (input-driven; U8 wires touches).
    mutating func dragCard(offset: Double) {
        guard var c = state.card, !c.committing else { return }
        c.offset = offset
        state.card = c
    }

    /// Release: commit past the 30%-width threshold, else spring back to neutral.
    mutating func releaseCard() {
        guard let c = state.card, !c.committing else { return }
        if abs(c.offset) > state.width * 0.3 {
            commitCard(c.offset > 0 ? 1 : -1)
        } else {
            var reset = c
            reset.offset = 0
            state.card = reset
        }
    }

    /// Commit the chosen side: apply its effects once, then begin the slide-off.
    mutating func commitCard(_ dir: Int) {
        guard var c = state.card, !c.committing else { return }
        let choice = dir > 0 ? c.def.right : c.def.left
        for e in choice.effects { apply(e) }
        c.committing = true
        c.dir = dir
        state.card = c
    }

    /// Advance the card's rise-in / slide-off on real time (it animates while
    /// the world is frozen). Removes the card when the slide completes.
    mutating func updateCardAnimation(realDt: Double) {
        guard var c = state.card else { return }
        if c.committing {
            c.offset += Double(c.dir) * Self.slideSpeed * realDt
            if abs(c.offset) > state.width { state.card = nil; return }
        } else if c.rise < 1 {
            c.rise = min(1, c.rise + realDt * Self.riseRate)
        }
        state.card = c
    }

    /// The timescale target: slow while a card is up and not yet committing.
    func cardTimescaleTarget() -> Double {
        if let c = state.card, !c.committing { return tunables.cardSlow }
        return 1
    }

    // MARK: - Effect interpreter

    /// Expire timed effects whose window has elapsed (on sim time).
    mutating func processTimedEffects() {
        guard !state.timedEffects.isEmpty else { return }
        var remaining: [TimedEffect] = []
        remaining.reserveCapacity(state.timedEffects.count)
        for te in state.timedEffects {
            if state.time > te.until {
                apply(te.undo)
            } else {
                remaining.append(te)
            }
        }
        state.timedEffects = remaining
    }

    mutating func apply(_ e: Effect) {
        switch e {
        case let .multiply(field, x): mutateMod(field) { $0 * x }
        case let .add(field, x): mutateMod(field) { $0 + x }
        case let .addBolts(n): state.mods.bolts += n
        case let .addCharge(c): state.charge += c
        case let .scaleEssence(f): state.essence = (state.essence * f).rounded(.down)
        case .smiteAllFoes: state.foes.removeAll()
        case let .timed(base, seconds):
            apply(base)
            state.timedEffects.append(TimedEffect(undo: Self.inverse(base), until: state.time + seconds))
        }
    }

    private static func inverse(_ e: Effect) -> Effect {
        switch e {
        case let .multiply(field, x): return .multiply(field, 1 / x)
        case let .add(field, x): return .add(field, -x)
        default: return .add(.fogAdd, 0) // only multiply/add are ever wrapped in `timed`
        }
    }

    private mutating func mutateMod(_ field: ModField, _ op: (Double) -> Double) {
        switch field {
        case .attackCooldown: state.mods.attackCooldown = op(state.mods.attackCooldown)
        case .footing: state.mods.footing = op(state.mods.footing)
        case .magnet: state.mods.magnet = op(state.mods.magnet)
        case .gain: state.mods.gain = op(state.mods.gain)
        case .scrollMul: state.mods.scrollMul = op(state.mods.scrollMul)
        case .essMul: state.mods.essMul = op(state.mods.essMul)
        case .moteSink: state.mods.moteSink = op(state.mods.moteSink)
        case .spawnMul: state.mods.spawnMul = op(state.mods.spawnMul)
        case .fogAdd: state.mods.fogAdd = op(state.mods.fogAdd)
        }
    }
}
