/// Deck management: the drafted deck is fuel; when it runs dry, Death deals from
/// its own cycling deck (R11). No reshuffle of the player deck within a run.
extension RunSim {
    /// Build the run decks (U6 default: two copies of every player card, plus
    /// Death's deck). U17's draft replaces the player-deck construction.
    mutating func buildDeck() {
        state.deck = shuffled(CardLibrary.playerSeed + CardLibrary.playerSeed)
        state.deathDeck = shuffled(CardLibrary.deathSeed)
    }

    /// Deal the next card: from the drafted deck while it lasts, otherwise from
    /// Death's deck (reshuffled when spent, cycling until the Finale).
    mutating func drawCard() {
        let def: CardDef
        let fromDeath: Bool
        if !state.deck.isEmpty {
            def = state.deck.removeFirst()
            fromDeath = false
        } else {
            if state.deathDeck.isEmpty { state.deathDeck = shuffled(CardLibrary.deathSeed) }
            def = state.deathDeck.removeFirst()
            fromDeath = true
        }
        state.drawn += 1
        state.card = ActiveCard(def: def, deathDealt: fromDeath)
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
