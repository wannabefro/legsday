import Foundation
import Testing
@testable import LegdaySim

/// U11 — weapon cards follow form → growth, collection dupes tier the card, and
/// tier 3 unlocks a press-and-hold signature (R13, R2).
struct WeaponTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    private static var thurible: CardDef {
        CardLibrary.weaponSeed.first { $0.id == "the_thurible" }!
    }

    private func makeSim(collection: [String: Int] = [:]) -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 1,
               catalog: .seed, collection: collection)
    }

    private func deal(_ sim: inout RunSim, _ def: CardDef) {
        sim.debugMutate { $0.card = ActiveCard(def: def, deathDealt: false) }
    }

    // MARK: - Form → growth routing

    /// First draw offers the two forms; L acquires form A (never a bare skip).
    @Test func firstDrawPicksForm() {
        var sim = makeSim()
        deal(&sim, Self.thurible)
        let offer = sim.currentOffer()!
        #expect(offer.left == Self.thurible.weapon!.formA)
        #expect(offer.right == Self.thurible.weapon!.formB)
        #expect(offer.signature == nil) // no signature during acquisition

        sim.commitCard(-1) // left → form A
        let st = sim.state.weapons["the_thurible"]!
        #expect(st.owned)
        #expect(st.form == 0)
        #expect(st.levels == [0, 0])
    }

    /// Once owned, repeat draws offer the two growth axes (distinct), and L/R
    /// grow different axes — never a re-acquire.
    @Test func repeatDrawGrowsDistinctAxes() {
        var sim = makeSim()
        sim.debugMutate {
            $0.weapons["the_thurible"] = WeaponState(owned: true, form: 0, levels: [0, 0])
        }
        deal(&sim, Self.thurible)
        let offer = sim.currentOffer()!
        #expect(offer.left == Self.thurible.weapon!.growthAxes[0])
        #expect(offer.right == Self.thurible.weapon!.growthAxes[1])
        #expect(offer.left != offer.right)

        sim.commitCard(-1) // left → axis 0
        #expect(sim.state.weapons["the_thurible"]!.levels == [1, 0])

        deal(&sim, Self.thurible)
        sim.commitCard(1) // right → axis 1
        #expect(sim.state.weapons["the_thurible"]!.levels == [1, 1])
    }

    // MARK: - Tier

    /// Collection dupe count sets the tier: 1→1, 2→2, 3 and beyond→3.
    @Test func tierDerivesFromDupeCount() {
        #expect(makeSim().tier(for: "the_thurible") == 1)               // absent → 1
        #expect(makeSim(collection: ["the_thurible": 1]).tier(for: "the_thurible") == 1)
        #expect(makeSim(collection: ["the_thurible": 2]).tier(for: "the_thurible") == 2)
        #expect(makeSim(collection: ["the_thurible": 3]).tier(for: "the_thurible") == 3)
        #expect(makeSim(collection: ["the_thurible": 9]).tier(for: "the_thurible") == 3)
    }

    /// Only a tier-3 card surfaces the signature; tier 2 never does.
    @Test func signatureVisibleOnlyAtTierThree() {
        func offerSignature(tier dupes: Int) -> CardChoice? {
            var sim = makeSim(collection: ["the_thurible": dupes])
            sim.debugMutate {
                $0.weapons["the_thurible"] = WeaponState(owned: true, form: 0, levels: [0, 0])
            }
            deal(&sim, Self.thurible)
            return sim.currentOffer()!.signature
        }
        #expect(offerSignature(tier: 2) == nil)
        #expect(offerSignature(tier: 3) == Self.thurible.weapon!.signature)
    }

    // MARK: - Press-and-hold signature

    /// A tier-3 hold past the arm threshold, released, commits the signature.
    @Test func longHoldCommitsSignature() {
        var sim = makeSim(collection: ["the_thurible": 3])
        sim.debugMutate {
            $0.weapons["the_thurible"] = WeaponState(owned: true, form: 0, levels: [0, 0])
        }
        deal(&sim, Self.thurible)
        let boltsBefore = sim.state.mods.bolts

        sim.tick(dt: 0.016, input: Input(phase: .began, location: Vec2(196, 500)))
        for _ in 0..<12 { // hold in place, well past 0.4s of clamped real time
            sim.tick(dt: 0.05, input: Input(phase: .idle, location: Vec2(196, 500)))
        }
        #expect(sim.state.card!.signatureArmed)
        sim.tick(dt: 0.016, input: Input(phase: .ended, location: Vec2(196, 500)))

        #expect(sim.state.mods.bolts == boltsBefore + 2) // censer flare
        #expect(sim.state.card!.committing)               // signature slid the card off
        #expect(sim.state.weapons["the_thurible"]!.levels == [0, 0]) // growth untouched
    }

    /// A short hold released at neutral does not arm — it falls back to L/R
    /// (here: springs back, no commit).
    @Test func shortHoldFallsBackToChoice() {
        var sim = makeSim(collection: ["the_thurible": 3])
        sim.debugMutate {
            $0.weapons["the_thurible"] = WeaponState(owned: true, form: 0, levels: [0, 0])
        }
        deal(&sim, Self.thurible)
        let boltsBefore = sim.state.mods.bolts

        sim.tick(dt: 0.016, input: Input(phase: .began, location: Vec2(196, 500)))
        sim.tick(dt: 0.05, input: Input(phase: .idle, location: Vec2(196, 500))) // ~0.07s < 0.4
        #expect(!sim.state.card!.signatureArmed)
        sim.tick(dt: 0.016, input: Input(phase: .ended, location: Vec2(196, 500)))

        #expect(sim.state.mods.bolts == boltsBefore) // nothing applied
        #expect(!sim.state.card!.committing)          // sprung back, still in play
    }
}
