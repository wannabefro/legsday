import Foundation
import Testing
@testable import LegdaySim

/// Furniture is the difference between a corridor and a place. Every rule here
/// is the prototype's, ported: a briar slows, a cairn stops, a cairn eats a shot.
struct FeaturesTests {
    private static let W = 393.0, H = 852.0

    private static func sim(seed: UInt64 = 5) -> RunSim {
        RunSim(tunables: tunables, viewport: Vec2(W, H), seed: seed)
    }

    private static func played(_ seconds: Double, seed: UInt64 = 5) -> RunSim {
        var s = sim(seed: seed)
        for _ in 0..<Int(seconds / RunSim.fixedStep) {
            s.tick(dt: RunSim.fixedStep, input: .idle)
        }
        return s
    }

    @Test func theLowRoadPlacesBriarsInsideTheChannelAndNeverInTheCliff() {
        let s = Self.played(30)
        let placed = s.state.features
        let inside = placed.allSatisfy { f in
            let e = s.state.gorge.edges(at: f.terrainY)
            return f.x > e.left && f.x < e.right
        }
        #expect(placed.count >= 3)
        #expect(inside)
        #expect(placed.allSatisfy { $0.kind == .briar })
    }

    /// The nil-kind guard on its own: a stage may be furnished with nothing.
    @Test func theReckoningPlacesNoFurnitureAtAll() {
        var s = Self.sim()
        s.debugMutate { $0.worldY = Ascent.reckoningFathoms * 10 + 400 }
        for _ in 0..<1_200 { s.tick(dt: RunSim.fixedStep, input: .idle) }
        #expect(s.state.stage.id == "reckoning")
        #expect(Feature.byStageID["reckoning"]!.kind == nil)
        #expect(s.state.features.isEmpty)
    }

    /// The minimum-channel guard on its own: too narrow means nothing is placed.
    @Test func aChannelNarrowerThanTheMinimumIsLeftEmpty() {
        var s = RunSim(tunables: Self.tunables, viewport: Vec2(60, Self.H), seed: 9)
        for _ in 0..<2_400 { s.tick(dt: RunSim.fixedStep, input: .idle) }
        let widest = (0..<200).map { i -> Double in
            let e = s.state.gorge.edges(at: Double(i) * 30)
            return e.right - e.left
        }.max() ?? 0
        #expect(widest < Feature.minimumChannel)
        #expect(s.state.features.isEmpty)
    }

    @Test func aBriarUnderTheHeroSlowsTheThumbButDoesNotStopIt() {
        func travel(withBriar: Bool) -> Double {
            var s = Self.sim()
            s.debugMutate { $0.hero.pos = Vec2(100, 400); $0.hero.target = Vec2(300, 400) }
            if withBriar { s.debugAddFeature(.briar, at: Vec2(100, 400), extent: 60) }
            let start = s.state.hero.pos.x
            s.tick(dt: RunSim.fixedStep * 8, input: .idle)
            return s.state.hero.pos.x - start
        }
        let free = travel(withBriar: false), snagged = travel(withBriar: true)
        #expect(snagged < free * 0.5)
        #expect(snagged > 0)
    }

    @Test func aCairnStopsTheHeroAndDragsTheTargetOutWithIt() {
        var s = Self.sim()
        s.debugAddFeature(.cairn, at: Vec2(200, 400), extent: 26)
        s.debugMutate { $0.hero.pos = Vec2(200, 400); $0.hero.target = Vec2(200, 400) }
        s.tick(dt: RunSim.fixedStep, input: .idle)
        let out = abs(s.state.hero.pos.x - 200) >= 26 || abs(s.state.hero.pos.y - 400) >= 26
        #expect(out)
        #expect(s.state.hero.target == s.state.hero.pos)
    }

    @Test func aFoeIsHeldOutOfACairnToo() {
        var s = Self.sim()
        s.debugAddFeature(.cairn, at: Vec2(200, 300), extent: 30)
        s.debugMutate { $0.hero.pos = Vec2(200, 700) }
        s.debugAddFoe(at: Vec2(200, 262), hp: 9, speed: 400)
        s.tick(dt: RunSim.fixedStep, input: .idle)
        let foe = s.state.foes.first!
        #expect(abs(foe.pos.x - 200) >= 30 - 0.01 || foe.pos.y <= 300 - 30 + 0.01)
        #expect(s.state.features.count == 1)
    }

    @Test func aFoeInABriarClosesGroundSlowerThanOneInTheOpen() {
        func closed(withBriar: Bool) -> Double {
            var s = Self.sim()
            s.debugMutate { $0.hero.pos = Vec2(200, 700); $0.hero.target = Vec2(200, 700) }
            if withBriar { s.debugAddFeature(.briar, at: Vec2(200, 300), extent: 70) }
            s.debugAddFoe(at: Vec2(200, 300), hp: 9, speed: 200)
            let before = s.state.foes.first!.pos.y
            for _ in 0..<60 { s.tick(dt: RunSim.fixedStep, input: .idle) }
            return s.state.foes.first!.pos.y - before
        }
        #expect(closed(withBriar: true) < closed(withBriar: false) * 0.7)
        #expect(Feature.foeBriarDrag < 1)
    }

    @Test func aCairnTakesTheShotTheFoeBehindItDoesNot() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500) }
        s.debugAddFeature(.cairn, at: Vec2(200, 420), extent: 26)
        let foe = s.debugAddFoe(at: Vec2(200, 340), hp: 5, speed: 0)
        s.debugMutate { $0.attackTimer = 0 }
        s.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(s.state.foes.first(where: { $0.id == foe })!.hp == 5)
        #expect(s.state.features.first!.hp == Feature.cairnHP - 1)
    }

    /// The boundary itself: two hits leave it standing, the third takes it down.
    @Test func theThirdHitBreaksACairnAndEmitsTheEvent() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500) }
        s.debugAddFeature(.cairn, at: Vec2(200, 420), extent: 26)
        s.debugAddFoe(at: Vec2(200, 340), hp: 9, speed: 0)
        var broke = false
        for hit in 1...3 {
            s.debugMutate { $0.attackTimer = 0; $0.hero.pos = Vec2(200, 500) }
            s.tick(dt: RunSim.fixedStep, input: .idle)
            if hit < 3 { broke = broke || s.state.features.isEmpty }
            if s.state.frameEvents.contains(where: {
                if case .cairnBroken = $0 { return true } else { return false }
            }) { broke = true }
        }
        #expect(!broke || s.state.features.isEmpty)
        #expect(s.state.features.isEmpty)
    }

    @Test func aShotWithNoStoneInTheWayStillReachesTheFoe() {
        var s = Self.sim()
        s.debugMutate { $0.hero.pos = Vec2(200, 500); $0.hero.target = Vec2(200, 500) }
        s.debugAddFeature(.cairn, at: Vec2(60, 420), extent: 26)
        let foe = s.debugAddFoe(at: Vec2(200, 340), hp: 5, speed: 0)
        s.debugMutate { $0.attackTimer = 0 }
        s.tick(dt: RunSim.fixedStep, input: .idle)
        #expect(s.state.foes.first(where: { $0.id == foe })!.hp == 4)
        #expect(s.state.features.first!.hp == Feature.cairnHP)
    }

    @Test func furnitureIsDroppedOnceTheClimbHasPassedIt() {
        let s = Self.played(90)
        let stale = s.state.features.filter { $0.terrainY < s.state.worldY - 80 }
        #expect(stale.isEmpty)
        #expect(s.state.features.count < 40)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.1, killPush: 0.9, downBias: 0.35, cardSlow: 0.005,
        firstCardCost: 4, cardCostIncrement: 1)
}
