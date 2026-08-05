/// A completed draft (R9): up to 12 picked card ids, max 2 copies of any card,
/// and the crowned Opener, guaranteed first draw.
public struct Draft: Equatable, Sendable {
    public var picks: [String]
    public var opener: String?

    public static let maxCards = 12
    public static let maxCopies = 2
    public static let collectionUnlock = 13

    public init(picks: [String], opener: String?) {
        self.picks = picks
        self.opener = opener
    }

    /// Drafting unlocks once the collection holds 13+ cards (R9).
    public static func isUnlocked(collection: [String: Int]) -> Bool {
        collection.values.reduce(0, +) >= collectionUnlock
    }

    /// Structural guard: 12 picks max, 2 copies max, Opener among the picks.
    public var isValid: Bool {
        guard picks.count <= Self.maxCards else { return false }
        guard let opener else { return true } // opener-less whole-collection path
        guard picks.contains(opener) else { return false }
        var counts: [String: Int] = [:]
        for p in picks { counts[p, default: 0] += 1 }
        return counts.values.allSatisfy { $0 <= Self.maxCopies }
    }
}

/// Only these factions seed a threat card on stage entry (design/ascent-stages.md).
private let seedingFactions: Set<Faction> = [.plague, .grave, .church]

/// When Death takes the deck (R21).
public enum DeathDeck {
    /// Death takes an exhausted deck past THE SPIRE (unit 4).
    public static let gateFathoms = Ascent.spireFathoms
}

/// Deck management: the drafted deck is fuel; it reshuffles while the run is
/// young, and darkens into Death's deck past the gate (R11/R21).
extension RunSim {
    /// Fathoms at which an exhausted deck stops reshuffling.
    public var deathGateFathoms: Double { DeathDeck.gateFathoms }

    /// True once the deck will no longer reshuffle — the HUD marks it.
    public var pastDeathGate: Bool { state.fathoms >= deathGateFathoms }

    /// U6 default deck: two copies of every player card, plus Death's deck.
    mutating func buildDeck() {
        state.deck = shuffled(catalog.player + catalog.player)
        state.deckSource = state.deck
        state.deathDeck = shuffled(catalog.death)
        // Hostility is fixed at draft time: the deck's faction weighting decides
        // which rival threats interleave, and when (R10).
        state.scheduledThreats = Hostility.forecast(weights: deckFactionWeights())
    }

    /// Draft-built deck: the Opener first (guaranteed first draw), rest in
    /// pick order.
    mutating func buildDeck(draft: Draft) {
        var defs = draft.picks.compactMap { catalog.card(id: $0) }
        if let opener = draft.opener,
           let i = defs.firstIndex(where: { $0.id == opener }) {
            defs.swapAt(0, i)
        }
        state.deck = defs
        state.deckSource = defs
        state.deathDeck = shuffled(catalog.death)
        state.scheduledThreats = Hostility.forecast(weights: deckFactionWeights())
    }

    /// Sub-13 path (R9): the run deck is the whole collection, every owned
    /// copy, no draft and no Opener.
    mutating func buildDeck(collection: [String: Int]) {
        var defs: [CardDef] = []
        for (id, copies) in collection.sorted(by: { $0.key < $1.key }) {
            if let def = catalog.card(id: id) {
                defs += Array(repeating: def, count: copies)
            }
        }
        state.deck = defs
        state.deckSource = defs
        state.deathDeck = shuffled(catalog.death)
        state.scheduledThreats = Hostility.forecast(weights: deckFactionWeights())
    }

    /// Deal the next card: the drafted deck while it lasts, else Death's deck
    /// (reshuffled when spent, cycling until the Finale).
    mutating func drawCard() {
        // A scheduled rival threat interleaves at this ordinal without consuming
        // the drafted deck (R10) — it is an extra card, not a replacement.
        if let i = state.scheduledThreats.firstIndex(where: { $0.atDraw == state.drawn }),
           let threat = catalog.threats.first(where: { $0.faction == state.scheduledThreats[i].faction }) {
            state.scheduledThreats.remove(at: i)
            state.drawn += 1
            state.card = ActiveCard(def: threat, deathDealt: false)
            return
        }
        // A deck spent before the gate reshuffles and cycles; only past it does
        // Death take over (R21).
        if state.deck.isEmpty,
           !pastDeathGate,
           !state.deckSource.isEmpty {
            state.deck = shuffled(state.deckSource)
        }
        let def: CardDef
        let fromDeath: Bool
        if !state.deck.isEmpty {
            def = state.deck.removeFirst()
            fromDeath = false
        } else {
            if state.deathDeck.isEmpty { state.deathDeck = shuffled(catalog.death) }
            def = state.deathDeck.removeFirst()
            fromDeath = true
        }
        state.drawn += 1
        state.card = ActiveCard(def: def, deathDealt: fromDeath)
    }

    /// Shuffle a stage's threat card into the remaining deck once (unit 5).
    mutating func seedStageThreat(_ stage: AscentStage) {
        guard let faction = stage.faction, seedingFactions.contains(faction),
              let threat = catalog.threats.first(where: { $0.faction == faction }) else { return }
        guard !state.seededStages.contains(stage.id) else { return }
        state.seededStages.insert(stage.id)
        state.deck.append(threat)
        state.deck = shuffled(state.deck)
    }

    /// Deterministic Fisher-Yates using the injected RNG (graybox `shuffled`),
    /// advancing the persistent RNG stream.
    mutating func shuffled(_ input: [CardDef]) -> [CardDef] {
        var a = input
        var i = a.count - 1
        while i > 0 {
            let j = Int(state.rng.unit() * Double(i + 1))
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }
}
