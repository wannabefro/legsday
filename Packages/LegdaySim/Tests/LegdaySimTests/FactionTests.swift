import Foundation
import Testing
@testable import LegdaySim

/// U12 — accepting a faction empowers it (affinity → weapon damage) and sharpens
/// its rival: the draft's faction weighting interleaves rival threat cards into
/// the live stream (R10, R14). Covers the first half of AE4.
struct FactionTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    private func makeSim(catalog: CardCatalog = .seed) -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1, catalog: catalog)
    }

    // MARK: - Forecast (pure)

    /// The forecast targets the *rival*: church weight sharpens Plague, grave
    /// weight sharpens Wild.
    @Test func forecastTargetsRival() {
        #expect(Hostility.forecast(weights: [.church: 6]).allSatisfy { $0.faction == .plague })
        #expect(Hostility.forecast(weights: [.grave: 6]).allSatisfy { $0.faction == .wild })
    }

    /// More weighting → more threats, and earlier (both monotonic).
    @Test func forecastMonotonicInWeighting() {
        let light = Hostility.forecast(weights: [.church: 4])
        let heavy = Hostility.forecast(weights: [.church: 9])
        #expect(heavy.count >= light.count)
        #expect(heavy.count > 0 && light.count > 0)
        #expect(heavy.first!.atDraw <= light.first!.atDraw) // earliest insertion is sooner
    }

    /// Zero (or absent) weighting inserts nothing.
    @Test func zeroWeightingInsertsNone() {
        #expect(Hostility.forecast(weights: [:]).isEmpty)
        #expect(Hostility.forecast(weights: [.church: 0]).isEmpty)
    }

    /// The forecast is a pure function of the weights (same draft → same result).
    @Test func forecastIsPure() {
        let w: [Faction: Int] = [.church: 5, .grave: 2]
        #expect(Hostility.forecast(weights: w) == Hostility.forecast(weights: w))
    }

    // MARK: - Live interleave

    /// A Church-heavy deck deals Plague threat cards during the run — only
    /// Plague, first at the forecast's earliest draw.
    @Test func churchHeavyDeckInterleavesPlagueThreats() {
        let church = CardDef(id: "c", title: "CHURCH RITE", spine: .gold, isDeath: false,
            left: CardChoice(label: "a", subtitle: "", effects: []),
            right: CardChoice(label: "b", subtitle: "", effects: []), faction: .church)
        let cat = CardCatalog(player: Array(repeating: church, count: 6),
                              threats: CardLibrary.threatSeed, death: CardLibrary.deathSeed)
        var sim = makeSim(catalog: cat) // deck = church ×12 → weights[church] = 12

        var threatFactions: [Faction] = []
        var earliest = -1
        for _ in 0..<16 {
            sim.debugMutate { $0.card = nil }
            sim.drawCard()
            if let c = sim.state.card, c.def.isThreat, let f = c.def.faction {
                threatFactions.append(f)
                if earliest < 0 { earliest = sim.state.drawn - 1 }
            }
        }
        #expect(!threatFactions.isEmpty)
        #expect(threatFactions.allSatisfy { $0 == .plague }) // rival only, no others
        #expect(earliest == max(Hostility.minEarliest, Hostility.baseEarliest - 12))
    }

    /// A threat interleaves without consuming the drafted deck (extra card).
    @Test func threatDoesNotConsumeDeck() {
        let church = CardDef(id: "c", title: "CHURCH RITE", spine: .gold, isDeath: false,
            left: CardChoice(label: "a", subtitle: "", effects: []),
            right: CardChoice(label: "b", subtitle: "", effects: []), faction: .church)
        let cat = CardCatalog(player: Array(repeating: church, count: 6),
                              threats: CardLibrary.threatSeed, death: CardLibrary.deathSeed)
        var sim = makeSim(catalog: cat)
        // Fast-forward to the first scheduled threat (draw 2).
        sim.debugMutate { $0.card = nil }; sim.drawCard() // 0
        sim.debugMutate { $0.card = nil }; sim.drawCard() // 1
        let deckBefore = sim.state.deck.count
        sim.debugMutate { $0.card = nil }; sim.drawCard() // 2 → threat
        #expect(sim.state.card!.def.isThreat)
        #expect(sim.state.deck.count == deckBefore) // deck untouched
    }

    // MARK: - Affinity

    /// Accepting a faction card builds affinity; committing a threat does not.
    @Test func acceptingFactionCardBuildsAffinity() {
        var sim = makeSim()
        let thurible = CardLibrary.weaponSeed.first { $0.id == "the_thurible" }!
        sim.debugMutate { $0.card = ActiveCard(def: thurible, deathDealt: false) }
        sim.commitCard(-1)
        #expect(sim.state.affinity[.church] == 1)

        let rot = CardLibrary.threatSeed.first { $0.id == "the_rot" }!
        sim.debugMutate { $0.card = ActiveCard(def: rot, deathDealt: false) }
        sim.commitCard(1)
        #expect(sim.state.affinity[.plague] == nil) // threats don't build affinity
    }

    /// Affinity scales that faction's weapon damage and no other's.
    @Test func affinityScalesOwnFactionWeaponOnly() {
        let thurible = CardLibrary.weaponSeed.first { $0.id == "the_thurible" }! // church
        let bell = CardLibrary.weaponSeed.first { $0.id == "the_passing_bell" }! // grave

        var churchSim = makeSim()
        churchSim.debugMutate { $0.affinity[.church] = 2 } // ×(1 + 2·0.5) = ×2
        let cBefore = churchSim.state.mods.bolts
        churchSim.debugMutate { $0.card = ActiveCard(def: thurible, deathDealt: false) }
        churchSim.commitCard(-1) // form A: addBolts(1) → ×2 = +2
        let churchGain = churchSim.state.mods.bolts - cBefore

        var graveSim = makeSim()
        graveSim.debugMutate { $0.affinity[.church] = 2 } // church affinity, grave weapon
        let gBefore = graveSim.state.mods.bolts
        graveSim.debugMutate { $0.card = ActiveCard(def: bell, deathDealt: false) }
        graveSim.commitCard(-1) // form A: addBolts(1), grave affinity 0 → ×1 = +1
        let graveGain = graveSim.state.mods.bolts - gBefore

        #expect(churchGain == 2)
        #expect(graveGain == 1)
        #expect(churchGain > graveGain) // church affinity empowered only the church weapon
    }
}
