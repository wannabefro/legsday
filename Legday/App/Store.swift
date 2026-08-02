import Foundation
import LegdaySim

/// KTD-8 persistence: the meta state as Codable JSON in Application Support,
/// written atomically. Corrupt files fall back empty without crashing.
public struct Store {
    public var collection: [String: Int]
    public var shards: Int
    /// Best distance climbed (fathoms) — only overwritten on improvement (R17).
    public var bestFathoms: Double

    public struct Meta: Codable, Equatable {
        public var collection: [String: Int]
        public var shards: Int
        public var bestFathoms: Double

        public init(collection: [String: Int], shards: Int, bestFathoms: Double) {
            self.collection = collection
            self.shards = shards
            self.bestFathoms = bestFathoms
        }
    }

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? Store.defaultURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let meta = try? JSONDecoder().decode(Meta.self, from: data) {
            self.collection = meta.collection
            self.shards = meta.shards
            self.bestFathoms = meta.bestFathoms
        } else {
            self.collection = [:]
            self.shards = 0
            self.bestFathoms = 0
        }
    }

    /// Record a finished run: bank shards, improve best distance, then persist.
    public mutating func record(_ result: RunResult) {
        shards += result.shards
        bestFathoms = max(bestFathoms, result.fathoms)
        save()
    }

    /// Add pulls to the collection (U21 mutates this before saving).
    public mutating func addToCollection(_ id: String, count: Int = 1) {
        collection[id, default: 0] += count
        save()
    }

    public mutating func spendShards(_ amount: Int) -> Bool {
        guard shards >= amount else { return false }
        shards -= amount
        save()
        return true
    }

    /// Atomic write: encode to a temp file, then rename over the target.
    public func save() {
        let meta = Meta(collection: collection, shards: shards, bestFathoms: bestFathoms)
        guard let data = try? JSONEncoder().encode(meta) else { return }
        let temp = fileURL.appendingPathExtension("tmp")
        try? data.write(to: temp, options: .atomic)
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.moveItem(at: temp, to: fileURL)
    }

    static func defaultURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("legday-meta.json")
    }
}
