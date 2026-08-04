import Foundation
import Testing
import LegdaySim
@testable import Legday

/// A rogue-lite whose runs share a seed is one level played repeatedly, and a
/// session that can only end in death is a trap. Both were true.
struct RunLifecycleTests {
    @MainActor
    private func makeFlow() -> GameFlow {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("run-\(UUID().uuidString).json")
        var store = Store(fileURL: url)
        store.collection = GameFlow.seedCollection
        store.save()
        return GameFlow(store: store, catalog: .seed)
    }

    @MainActor
    @Test func everyRunGetsItsOwnSeed() {
        let flow = makeFlow()
        var seeds: Set<UInt64> = []
        for _ in 0..<5 {
            flow.begin()
            seeds.insert(flow.runSeed)
            flow.toTitle()
        }
        #expect(seeds.count == 5)
    }

    /// The seed must survive re-reads within one run, or the scene rebuilds.
    @MainActor
    @Test func theSeedHoldsForTheLifeOfARun() {
        let flow = makeFlow()
        flow.begin()
        let seed = flow.runSeed
        #expect(flow.runSeed == seed)
        #expect(flow.runSeed == seed)
    }

    @MainActor
    @Test func abandoningARunReturnsToTheTitleAndBanksNothing() {
        let flow = makeFlow()
        let shards = flow.store.shards
        flow.begin()
        flow.paused = true
        flow.abandonRun()
        #expect(flow.stage == .title)
        #expect(flow.paused == false)
        #expect(flow.store.shards == shards)
    }

    /// Pause must not survive into the next run, or it opens already paused.
    @MainActor
    @Test func pauseClearsWhenANewRunStarts() {
        let flow = makeFlow()
        flow.begin()
        flow.paused = true
        flow.toTitle()
        flow.begin()
        #expect(flow.paused == false)
    }

    /// The Reliquary was reachable only by dying.
    @MainActor
    @Test func theReliquaryOpensFromTheTitle() {
        let flow = makeFlow()
        flow.openReliquary()
        #expect(flow.stage == .reliquary)
    }
}
