import Foundation

/// The world's biome, swapped by forks (U13). A state tag only — the render
/// layer maps it to a palette (U24); the sim carries no visual meaning.
public enum Biome: String, CaseIterable, Equatable, Sendable, Codable {
    case moor, crypt, mire, waste
}

/// A fork's content (R12): a safe road and a risk road, plus the risk-flavored
/// replacement the safe road becomes past minute 8. Choices are data, like every
/// other card side.
public struct ForkDef: Equatable, Sendable, Codable {
    public var biome: Biome
    public var safe: CardChoice
    public var risk: CardChoice
    public var lateRisk: CardChoice

    public init(biome: Biome, safe: CardChoice, risk: CardChoice, lateRisk: CardChoice) {
        self.biome = biome
        self.safe = safe
        self.risk = risk
        self.lateRisk = lateRisk
    }
}

/// Fork scheduling constants (R12).
public enum Forks {
    /// Cadence between mandatory forks, seconds.
    public static let cadence: Double = 90
    /// Past this run time the safe road is replaced by a second risk flavor.
    public static let lateThreshold: Double = 480 // minute 8
}

public extension CardLibrary {
    /// Seed forks — one per starting biome pair. Placeholder kits: the structure
    /// (safe vs risk, late-game risk swap) is the deliverable; values are data.
    static let forkSeed: [CardDef] = [
        CardDef(id: "the_crossroads", title: "THE CROSSROADS", spine: .inkspine, isDeath: false,
            left: CardChoice(label: "fork", subtitle: "the world forks", effects: []),
            right: CardChoice(label: "fork", subtitle: "the world forks", effects: []),
            fork: ForkDef(biome: .crypt,
                safe: CardChoice(label: "the low road", subtitle: "sparse foes, scroll +10%",
                                 effects: [.multiply(.scrollMul, 1.1), .multiply(.spawnMul, 0.7)]),
                risk: CardChoice(label: "the deep road", subtitle: "dense foes, essence ×1.3",
                                 effects: [.multiply(.spawnMul, 1.5), .multiply(.essMul, 1.3)]),
                lateRisk: CardChoice(label: "the drowned road", subtitle: "denser still, essence ×1.25",
                                     effects: [.multiply(.spawnMul, 1.4), .multiply(.essMul, 1.25)]))),
        CardDef(id: "the_threshold", title: "THE THRESHOLD", spine: .inkspine, isDeath: false,
            left: CardChoice(label: "fork", subtitle: "the world forks", effects: []),
            right: CardChoice(label: "fork", subtitle: "the world forks", effects: []),
            fork: ForkDef(biome: .mire,
                safe: CardChoice(label: "the walled way", subtitle: "sparse foes, scroll +10%",
                                 effects: [.multiply(.scrollMul, 1.1), .multiply(.spawnMul, 0.7)]),
                risk: CardChoice(label: "the open mire", subtitle: "dense foes, essence ×1.3",
                                 effects: [.multiply(.spawnMul, 1.5), .multiply(.essMul, 1.3)]),
                lateRisk: CardChoice(label: "the sunk mire", subtitle: "denser still, essence ×1.25",
                                     effects: [.multiply(.spawnMul, 1.4), .multiply(.essMul, 1.25)]))),
    ]
}

extension RunSim {
    /// Deal a mandatory fork when its cadence elapses and no card is up. Forks
    /// are world-owned: dealt at zero essence cost, never advancing card cost or
    /// the drawn/threat counters.
    mutating func maybeDealFork() {
        guard state.card == nil, !state.keepRunning,
              state.time >= state.nextForkTime, !catalog.forks.isEmpty else { return }
        let def = catalog.forks[state.forkCount % catalog.forks.count]
        state.forkCount += 1
        state.nextForkTime += Forks.cadence
        state.card = ActiveCard(def: def, deathDealt: false)
    }

    /// The fork's L/R at the current run time: safe vs risk before minute 8, two
    /// risk flavors after (no safe road late).
    func forkOffer(_ fork: ForkDef) -> CardOffer {
        let left = state.time > Forks.lateThreshold ? fork.lateRisk : fork.safe
        return CardOffer(left: left, right: fork.risk)
    }

    /// Side-effects of committing a fork beyond its choice effects: the biome
    /// swaps, and a risk-shaped side raises a shrine (the U14 Herald hook).
    mutating func applyForkSide(_ fork: ForkDef, dir: Int) {
        state.biome = fork.biome
        let riskShaped = dir > 0 || state.time > Forks.lateThreshold // right, or late (no safe)
        if riskShaped { state.shrinePending = true }
    }
}
