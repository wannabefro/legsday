import Foundation
import Testing
import LegdaySim
@testable import Legday

/// U20 — the persisted meta Store (KTD-8): round-trip, best-distance-on-
/// improvement, corrupt-file fallback, and shard banking from the run result.
struct StoreTests {
    private func tempStore() throws -> (Store, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (Store(fileURL: dir.appendingPathComponent("meta.json")),
                dir.appendingPathComponent("meta.json"))
    }

    /// Collection, shards, and best distance round-trip across save/load.
    @Test func storeRoundTrips() throws {
        var (store, url) = try tempStore()
        store.collection = ["the_thurible": 2]
        store.shards = 42
        store.bestFathoms = 313.5
        store.save()

        let reloaded = Store(fileURL: url)
        #expect(reloaded.collection == ["the_thurible": 2])
        #expect(reloaded.shards == 42)
        #expect(reloaded.bestFathoms == 313.5)
    }

    /// Best distance only overwrites on improvement; worse runs keep it.
    @Test func bestDistanceOnlyOverwritesOnImprovement() throws {
        var store = Store(fileURL: try tempStore().1)
        store.record(RunResult(ending: .caught, fathoms: 400, felled: 20,
                               cardsDrawn: 8, shards: 40))
        #expect(store.bestFathoms == 400)
        store.record(RunResult(ending: .caught, fathoms: 150, felled: 5,
                               cardsDrawn: 3, shards: 15))
        #expect(store.bestFathoms == 400) // no regression
        store.record(RunResult(ending: .caught, fathoms: 900, felled: 50,
                               cardsDrawn: 12, shards: 90))
        #expect(store.bestFathoms == 900)
    }

    /// A corrupt file falls back to the empty state without crashing.
    @Test func corruptFileFallsBackToEmpty() throws {
        let url = try tempStore().1
        try Data("not json".utf8).write(to: url)
        let store = Store(fileURL: url)
        #expect(store.collection.isEmpty)
        #expect(store.shards == 0)
        #expect(store.bestFathoms == 0)
    }

    /// Recording a run banks its shards and the obituary numbers equal the
    /// payload (R18).
    @Test func recordingBanksShardsAndMatchesPayload() throws {
        var store = Store(fileURL: try tempStore().1)
        let result = RunResult(ending: .duelWin, fathoms: 500, felled: 30,
                               cardsDrawn: 10, shards: 150)
        store.record(result)
        #expect(store.shards == 150)
        #expect(store.bestFathoms == 500)
        #expect(store.collection.isEmpty) // shards not yet spent
    }
}
