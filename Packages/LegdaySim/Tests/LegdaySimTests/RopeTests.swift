import Foundation
import Testing
@testable import LegdaySim

/// U16 — the Wild chain weapon: a verlet rope that whips with kiting, hitting
/// foes only above a whip-speed threshold (R21).
struct RopeTests {
    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)

    private static var chainDef: CardDef {
        CardLibrary.weaponSeed.first { $0.id == Chain.id }!
    }

    private func makeSim() -> RunSim {
        RunSim(tunables: Self.tunables, viewport: Vec2(393, 852), seed: 7,
               catalog: .seed)
    }

    /// Equip the chain via the real card flow: deal it, commit a form.
    private func equip(_ sim: inout RunSim, form: Int) {
        sim.debugMutate { $0.card = ActiveCard(def: Self.chainDef, deathDealt: false) }
        sim.commitCard(form == 0 ? -1 : 1)
    }

    // MARK: - Physics stability

    /// The rope stays intact (segments near rest, no NaN) under fast, erratic
    /// pin motion — the cloak's stability bar.
    @Test func ropeStableUnderWorstCaseDrag() {
        let step = RunSim.fixedStep
        var rope = ChainRope(pin: Vec2(200, 400), count: Chain.longLash.segments,
                             segment: Chain.longLash.segment)
        for i in 0..<600 {
            let t = Double(i)
            let pin = Vec2(200 + 160 * sin(t * 0.5), 400 + 120 * cos(t * 0.37))
            rope.update(dt: step, pin: pin, segment: Chain.longLash.segment,
                        headMass: Chain.longLash.headMass)
        }
        #expect(rope.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        #expect(rope.maxSegmentError < Chain.longLash.segment) // no explosion
        #expect(rope.headSpeed.isFinite)
    }

    // MARK: - Whip damage boundary

    /// Equipping the chain creates the rope hanging from the hero.
    @Test func acquisitionCreatesRope() {
        var sim = makeSim()
        equip(&sim, form: 0)
        #expect(sim.state.rope != nil)
        #expect(sim.state.rope!.points.count == Chain.longLash.segments)

        var heavy = makeSim()
        equip(&heavy, form: 1)
        #expect(heavy.state.rope!.points.count == Chain.heavyHead.segments)
    }

    /// At exactly the threshold, the head deals nothing; just above, it does.
    @Test func whipDealsNothingAtOrBelowThreshold() {
        func lostHp(speed: Double, seconds: Double) -> Int {
            var sim = makeSim()
            equip(&sim, form: 0)
            sim.debugAddFoe(at: Vec2(200, 460), hp: 200)
            let config = (form: Chain.longLash, segment: 9.0, headMass: 0.8, threshold: 400.0)
            for _ in 0..<Int(seconds / RunSim.fixedStep) {
                sim.whipDamage(dt: RunSim.fixedStep, head: Vec2(200, 460), speed: speed, config: config)
            }
            return 200 - sim.state.foes.first!.hp
        }
        #expect(lostHp(speed: 400, seconds: 2) == 0)   // threshold itself: nothing
        #expect(lostHp(speed: 401, seconds: 60) > 0)   // a whisk above, in time: chips
    }

    /// Above threshold, damage scales with speed — faster whip, more HP lost.
    @Test func whipDamageScalesWithSpeed() {
        func lostHp(speed: Double) -> Int {
            var sim = makeSim()
            equip(&sim, form: 0)
            sim.debugAddFoe(at: Vec2(200, 460), hp: 50)
            let config = (form: Chain.longLash, segment: 9.0, headMass: 0.8, threshold: 400.0)
            for _ in 0..<Int(1.0 / RunSim.fixedStep) {
                sim.whipDamage(dt: RunSim.fixedStep, head: Vec2(200, 460), speed: speed, config: config)
            }
            return 50 - sim.state.foes.first!.hp
        }
        let slow = lostHp(speed: 800)
        let fast = lostHp(speed: 1600)
        #expect(slow > 0)
        #expect(fast > slow)
        #expect(fast >= slow * 2) // ~doubled rate at double excess
    }

    /// A whip kill crosses 1 HP and pays fog and motes via the normal kill path.
    @Test func whipFellsFoeThroughKillPath() {
        var sim = makeSim()
        equip(&sim, form: 1) // heavy head: higher damage scale
        sim.debugAddFoe(at: Vec2(200, 460), hp: 1)
        let config = (form: Chain.heavyHead, segment: 11.0, headMass: 3.0, threshold: 360.0)
        var done = false
        for _ in 0..<Int(2.0 / RunSim.fixedStep) where !done {
            sim.whipDamage(dt: RunSim.fixedStep, head: Vec2(200, 460), speed: 1200, config: config)
            done = sim.state.foes.isEmpty
        }
        #expect(sim.state.foes.isEmpty)
        #expect(sim.state.kills == 1)
    }

    // MARK: - Determinism and form difference

    /// Determinism holds with the rope active: same seed + input → identical
    /// state hash (the rope is fingerprinted).
    @Test func determinismHoldsWithRopeActive() {
        var a = makeSim(), b = makeSim()
        equip(&a, form: 0); equip(&b, form: 0)
        for i in 0..<1800 {
            let loc = Vec2(196 + 130 * sin(Double(i) * 0.03), 420 + 80 * cos(Double(i) * 0.04))
            let input = Input(phase: i == 0 ? .began : .moved, location: loc)
            a.tick(dt: 1.0 / 60, input: input)
            b.tick(dt: 1.0 / 60, input: input)
        }
        #expect(a.state.fingerprint == b.state.fingerprint)
    }

    /// The two forms (long lash vs heavy head) produce measurably different
    /// head-speed profiles under an identical scripted drag.
    @Test func twoFormsProduceDifferentHeadSpeedProfiles() {
        func profile(form: Int) -> (max: Double, mean: Double) {
            var sim = makeSim()
            equip(&sim, form: form)
            var sum = 0.0, mx = 0.0, n = 0
            for i in 0..<1200 {
                let loc = Vec2(196 + 130 * sin(Double(i) * 0.03), 420 + 80 * cos(Double(i) * 0.04))
                let input = Input(phase: i == 0 ? .began : .moved, location: loc)
                sim.tick(dt: 1.0 / 60, input: input)
                let s = sim.state.rope!.headSpeed
                sum += s; mx = max(mx, s); n += 1
            }
            return (mx, sum / Double(n))
        }
        let lash = profile(form: 0)
        let head = profile(form: 1)
        #expect(lash.max != head.max)
        #expect(abs(lash.mean - head.mean) > 1) // not coincidentally equal
    }
}
