import Foundation

/// How a run ended (R17/R18): the obituary reads differently per ending but
/// carries the same payload shape (U20).
public enum RunEnding: String, Equatable, Sendable, Codable {
    /// Caught by the fog — the ordinary death, or keep-running caught.
    case caught
    /// Duel lost against the Reaper — same obituary form as caught (AE5).
    case duelLoss
    /// Duel won — glory, shards ×3.
    case duelWin
}

/// The run's result payload — one shape for every ending (R18). The obituary
/// (U20) and store persist `shards` and best `fathoms`.
public struct RunResult: Equatable, Sendable {
    public var ending: RunEnding
    /// Distance climbed, the score (graybox `fathoms`).
    public var fathoms: Double
    /// Foes felled this run.
    public var felled: Int
    /// Cards drawn this run.
    public var cardsDrawn: Int
    /// Shards earned — the meta currency (R19), one per 10 fathoms.
    public var shards: Int

    public init(ending: RunEnding, fathoms: Double, felled: Int,
                cardsDrawn: Int, shards: Int) {
        self.ending = ending
        self.fathoms = fathoms
        self.felled = felled
        self.cardsDrawn = cardsDrawn
        self.shards = shards
    }
}

/// Death's arrival (R17): the ink-spined Finale deals on entry to THE RECKONING;
/// keep-running ramps the scroll until the fog ends the run.
public enum Finale {
    /// The Finale card's stable id (built in code, not from cards.json).
    public static let cardId = "the_finale"
    /// Scroll multiplier growth per second once keep-running is chosen.
    public static let keepRunningRamp: Double = 0.006
}

public extension CardLibrary {
    /// The Finale card: ink-spined, player-answered, mandatory (R17). Built in
    /// code like the FUSION card.
    static let finaleCard = CardDef(id: Finale.cardId, title: "THE FINALE",
        spine: .inkspine, isDeath: true,
        left: CardChoice(label: "turn & fight", subtitle: "a duel in the fog", effects: []),
        right: CardChoice(label: "keep running", subtitle: "the road never ends", effects: []))
}

extension RunSim {
    /// Deal the Finale on entry to THE RECKONING, regardless of essence.
    /// One deal per run.
    mutating func maybeDealFinale() {
        guard state.card == nil, !state.finaleDealt else { return }
        guard state.fathoms >= Ascent.reckoningFathoms else { return }
        state.finaleDealt = true
        state.card = ActiveCard(def: CardLibrary.finaleCard, deathDealt: true)
    }

    /// The Finale is mandatory: either release commits a side (R17). Right
    /// commits keep-running; left requests the duel (U19).
    mutating func commitFinale(_ dir: Int) {
        if dir > 0 {
            state.keepRunning = true
        } else {
            state.duelRequested = true
        }
    }

    /// The run's result payload (R18) — one shape for every ending. Shards are
    /// one per 10 fathoms; a duel win triples them (U19), loss keeps base.
    public func result() -> RunResult {
        let ending: RunEnding = state.duelWon ? .duelWin : state.deadInDuel ? .duelLoss : .caught
        var shards = Int(state.fathoms / 10)
        if state.duelWon { shards *= 3 }
        return RunResult(ending: ending, fathoms: state.fathoms,
                         felled: state.kills, cardsDrawn: state.drawn, shards: shards)
    }
}
