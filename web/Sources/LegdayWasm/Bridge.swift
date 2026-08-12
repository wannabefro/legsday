import Foundation
import LegdaySim

/// The browser's view of one run. The sim decides; this file moves numbers.
/// Geometry fills a flat `Double` buffer each frame; card text fills a JSON
/// string. Pointers, not arrays — an Array's pointer does not outlive its call.
nonisolated(unsafe) private var sim: RunSim?
nonisolated(unsafe) private var frame = UnsafeMutablePointer<Double>(bitPattern: 1)!
nonisolated(unsafe) private var text = UnsafeMutablePointer<UInt8>(bitPattern: 1)!
nonisolated(unsafe) private var lastCardKey = ""

private func zeroed<T: Numeric>(_: T.Type, _ n: Int) -> UnsafeMutablePointer<T> {
    let p = UnsafeMutablePointer<T>.allocate(capacity: n)
    p.initialize(repeating: 0, count: n)
    return p
}

/// Allocate the shared buffers. Call once, after `_initialize`. A lazy global
/// returned address 0 through `@_cdecl`, so this is explicit.
@_cdecl("legday_boot")
public func legday_boot() {
    inbox = zeroed(Double.self, 32)
    frame = zeroed(Double.self, Layout.capacity)
    text = zeroed(UInt8.self, 4096)
}

private func address(_ p: UnsafeRawPointer) -> UInt32 {
    UInt32(UInt(bitPattern: p))
}

/// The 13 tunables, as raw doubles. `JSONDecoder` links Foundation's case
/// tables: 45 MB of a 52 MB binary. This wasm is single-threaded.
nonisolated(unsafe) private var inbox = UnsafeMutablePointer<Double>(bitPattern: 1)!

private enum Layout {
    /// Fixed header, then three variable arrays. JavaScript reads the counts
    /// from the header and walks the rest in order.
    static let header = 20
    static let maxFoes = 200
    static let maxMotes = 300
    static let maxBands = 80
    static let maxFeatures = 60
    static let capacity =
        header + maxFoes * 4 + maxMotes * 3 + maxBands * 5 + maxFeatures * 4
}

/// A fresh install's four relics, matching `GameFlow.seedCollection`.
private let coldStart = [
    "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2, "the_thurible": 1,
]

@_cdecl("legday_inbox")
public func legday_inbox() -> UInt32 { address(inbox) }

/// Start a run. The caller fills the inbox first, in `tunables.json` order.
@_cdecl("legday_start")
public func legday_start(_ seed: UInt64, _ width: Double, _ height: Double) {
    let t = Tunables(
        scroll: inbox[0], spawn: inbox[1], shove: inbox[2], iframes: inbox[3],
        fogGrace: inbox[4], fogGrip: inbox[5], fogCreep: inbox[6],
        fogCeiling: inbox[7], killPush: inbox[8], downBias: inbox[9],
        cardSlow: inbox[10], firstCardCost: inbox[11], cardCostIncrement: inbox[12])
    sim = RunSim(tunables: t, viewport: Vec2(width, height), seed: seed,
                 catalog: .seed, collection: coldStart)
    lastCardKey = ""
}

/// Advance one frame. `phase` is 0 idle, 1 began, 2 moved, 3 ended.
@_cdecl("legday_tick")
public func legday_tick(_ dt: Double, _ phase: Int32, _ x: Double, _ y: Double) {
    guard sim != nil else { return }
    let p: Input.Phase
    switch phase {
    case 1: p = .began
    case 2: p = .moved
    case 3: p = .ended
    default: p = .idle
    }
    sim!.tick(dt: dt, input: Input(phase: p, location: Vec2(x, y)))
    fill()
}

@_cdecl("legday_frame")
public func legday_frame() -> UInt32 { address(frame) }

@_cdecl("legday_text")
public func legday_text() -> UInt32 { address(text) }

/// Pack the frame. Order is the contract; `web/legday.js` walks it.
private func fill() {
    guard let sim else { return }
    let s = sim.state
    let h = s.height

    // The exact inverse of the sim's `terrainY(of:)`.
    func screenY(ofTerrain t: Double) -> Double { s.worldY + h - t }

    var i = Layout.header
    var foes = 0
    for f in s.foes where foes < Layout.maxFoes {
        frame[i] = f.pos.x; frame[i + 1] = f.pos.y
        frame[i + 2] = f.radius; frame[i + 3] = f.elite ? 1 : 0
        i += 4; foes += 1
    }
    var motes = 0
    for m in s.motes where motes < Layout.maxMotes {
        frame[i] = m.pos.x; frame[i + 1] = m.pos.y; frame[i + 2] = m.radius
        i += 3; motes += 1
    }
    // One sample per band of the visible climb, plus a band above and below.
    let band = 24.0
    let first = Int(((s.worldY - band) / band).rounded(.down))
    var bands = 0
    for step in 0...(Int(h / band) + 2) where bands < Layout.maxBands {
        let t = Double(first + step) * band
        guard t >= 0 else { continue }
        let e = s.gorge.edges(at: t)
        let spine = s.gorge.spine(at: t)
        frame[i] = screenY(ofTerrain: t)
        frame[i + 1] = e.left; frame[i + 2] = e.right
        frame[i + 3] = spine?.left ?? -1; frame[i + 4] = spine?.right ?? -1
        i += 5; bands += 1
    }
    var features = 0
    for f in s.features where features < Layout.maxFeatures {
        frame[i] = f.x; frame[i + 1] = screenY(ofTerrain: f.terrainY)
        frame[i + 2] = f.extent; frame[i + 3] = f.kind == .cairn ? 1 : 0
        i += 4; features += 1
    }

    frame[0] = s.time
    frame[1] = s.fathoms
    frame[2] = s.essence
    frame[3] = Double(s.kills)
    frame[4] = sim.fogLineY()
    frame[5] = s.hero.pos.x
    frame[6] = s.hero.pos.y
    frame[7] = s.heroInFog ? 1 : 0
    frame[8] = s.dead ? 1 : 0
    frame[9] = s.card == nil ? 0 : 1
    frame[10] = s.card?.offset ?? 0
    frame[11] = s.card?.rise ?? 0
    frame[12] = s.card?.tilt ?? 0
    frame[13] = s.hero.heading
    frame[14] = s.hero.invuln
    frame[15] = Double(foes)
    frame[16] = Double(motes)
    frame[17] = Double(bands)
    frame[18] = Double(features)
    frame[19] = s.charge / max(1, s.essNeed)

    fillText(sim)
}

/// Card and stage text, rebuilt only when the face changes.
private func fillText(_ sim: RunSim) {
    let s = sim.state
    let key = (s.card.map { "\($0.def.id)|\($0.committing)" } ?? "") + "|" + s.stage.id
    guard key != lastCardKey else { return }
    lastCardKey = key

    var fields: [String] = ["\"stage\":\(quote(s.stage.name))"]
    if let c = s.card {
        let offer = sim.currentOffer()
        let left = offer?.left ?? c.def.left
        let right = offer?.right ?? c.def.right
        fields.append("\"title\":\(quote(c.def.title))")
        fields.append("\"death\":\(c.deathDealt)")
        fields.append("\"leftLabel\":\(quote(left.label))")
        fields.append("\"leftSub\":\(quote(left.subtitle))")
        fields.append("\"rightLabel\":\(quote(right.label))")
        fields.append("\"rightSub\":\(quote(right.subtitle))")
    }
    write("{" + fields.joined(separator: ",") + "}")
}

private func quote(_ s: String) -> String {
    var out = "\""
    for c in s.unicodeScalars {
        switch c {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        default: out.unicodeScalars.append(c)
        }
    }
    return out + "\""
}

private func write(_ s: String) {
    let bytes = Array(s.utf8)
    let n = min(bytes.count, 4095)
    for k in 0..<n { text[k] = bytes[k] }
    text[n] = 0
}
