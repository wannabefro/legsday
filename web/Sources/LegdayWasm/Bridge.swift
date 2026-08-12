import Foundation
import LegdaySim

/// The browser's view of one run. Geometry fills a `Double` buffer each
/// frame; card text fills a JSON string.
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
    text = zeroed(UInt8.self, 8192)
}

private func address(_ p: UnsafeRawPointer) -> UInt32 {
    UInt32(UInt(bitPattern: p))
}

/// The 13 tunables, as raw doubles. `JSONDecoder` links Foundation's case
/// tables: 45 MB of a 52 MB binary. This wasm is single-threaded.
nonisolated(unsafe) private var inbox = UnsafeMutablePointer<Double>(bitPattern: 1)!

/// The buffer's shape. `web/legday.js` walks it in this order, and the
/// header carries every count.
private enum Layout {
    static let header = 64
    static let maxFoes = 200
    static let maxMotes = 300
    static let maxBands = 80
    static let maxFeatures = 60
    static let maxFogHeights = 64
    static let maxRope = 40
    static let maxEvents = 48
    static let capacity = header + maxFoes * 6 + maxMotes * 4 + maxBands * 5
        + maxFeatures * 8 + CloakRig.wedgeCount * 2 + maxFogHeights
        + maxRope * 2 + maxEvents * 6
}

/// A fresh install's four relics, matching `GameFlow.seedCollection`.
private let coldStart = [
    "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2, "the_thurible": 1,
]

/// The render layer draws a weapon's form by name; the wire carries an index.
private let weaponForms = ["the_thurible", "the_passing_bell", "the_censer_rot"]

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
        let p = f.pos + f.knock
        frame[i] = p.x; frame[i + 1] = p.y
        frame[i + 2] = f.radius; frame[i + 3] = f.elite ? 1 : 0
        frame[i + 4] = f.rotation; frame[i + 5] = f.wobble
        i += 6; foes += 1
    }
    var motes = 0
    for m in s.motes where motes < Layout.maxMotes {
        frame[i] = m.pos.x; frame[i + 1] = m.pos.y
        frame[i + 2] = m.radius; frame[i + 3] = Double(m.id)
        i += 4; motes += 1
    }
    // One sample per band of the visible climb, plus a band above and below.
    let band = Gorge.bandHeight
    let first = Int(((s.worldY - band) / band).rounded(.down))
    var bands = 0
    for step in 0...(Int(h / band) + 3) where bands < Layout.maxBands {
        let t = Double(first + step) * band + band / 2
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
        frame[i + 4] = Double(f.hp); frame[i + 5] = f.rotation
        frame[i + 6] = s.time - f.struckAt; frame[i + 7] = Double(f.id)
        i += 8; features += 1
    }
    for w in s.cloak.wedges {
        frame[i] = w.angle; frame[i + 1] = w.stretch
        i += 2
    }
    let heights = s.fogSurface.heights
    let fogCount = min(heights.count, Layout.maxFogHeights)
    for k in 0..<fogCount { frame[i + k] = heights[k] }
    i += fogCount

    var ropePoints = 0
    if let rope = s.rope {
        for p in rope.points where ropePoints < Layout.maxRope {
            frame[i] = p.x; frame[i + 1] = p.y
            i += 2; ropePoints += 1
        }
    }
    var events = 0
    for e in s.frameEvents where events < Layout.maxEvents {
        pack(e, at: &i)
        events += 1
    }

    frame[0] = s.time
    frame[1] = s.fathoms
    frame[2] = s.essence
    frame[3] = Double(s.kills)
    frame[4] = sim.fogLineY()
    let hero = s.hero.pos + s.hero.recoil
    frame[5] = hero.x
    frame[6] = hero.y
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
    frame[20] = s.hero.lean
    frame[21] = s.hero.aim
    frame[22] = s.hero.stride
    frame[23] = s.lantern.angle
    frame[24] = Double(Ascent.stages.firstIndex { $0.id == s.stage.id } ?? 0)
    frame[25] = Double(fogCount)
    frame[26] = Double(events)
    frame[27] = Double(ropePoints)
    frame[28] = (s.card?.committing ?? false) ? 1 : 0
    frame[29] = (s.card?.deathDealt ?? false) ? 1 : 0
    frame[30] = s.card?.holdTime ?? 0
    frame[31] = signatureState(sim)
    frame[32] = Double(spineIndex(s.card?.def.spine))
    frame[33] = Double(s.deckSource.count)
    frame[34] = Double(s.deck.count)
    frame[35] = Double(sim.catalog.death.count)
    frame[36] = sim.pastDeathGate ? 1 : 0
    frame[37] = s.worldY
    frame[38] = s.charge
    frame[39] = s.essNeed
    frame[40] = s.rope?.head.x ?? 0
    frame[41] = s.rope?.head.y ?? 0
    frame[42] = s.rope?.headSpeed ?? 0
    frame[43] = band
    frame[44] = Double(s.mods.bolts)
    frame[45] = s.mods.attackCooldown
    frame[46] = s.mods.footing
    frame[47] = s.mods.magnet
    frame[48] = s.mods.gain
    frame[49] = s.mods.scrollMul
    frame[50] = s.mods.essMul
    frame[51] = s.mods.moteSink
    frame[52] = s.mods.spawnMul
    frame[53] = s.mods.fogAdd
    frame[54] = s.heroGripped ? 1 : 0
    frame[55] = s.duel == nil ? 0 : 1

    fillText(sim)
}

/// Six slots per event: the kind, then up to five payload numbers.
private func pack(_ e: FrameEvent, at i: inout Int) {
    func put(_ kind: Double, _ a: Double = 0, _ b: Double = 0,
             _ c: Double = 0, _ d: Double = 0, _ f: Double = 0) {
        frame[i] = kind; frame[i + 1] = a; frame[i + 2] = b
        frame[i + 3] = c; frame[i + 4] = d; frame[i + 5] = f
        i += 6
    }
    switch e {
    case let .attack(from, to, weapon):
        let form = weapon.flatMap { weaponForms.firstIndex(of: $0) } ?? -1
        put(0, from.x, from.y, to.x, to.y, Double(form))
    case let .heroShoved(at): put(1, at.x, at.y)
    case let .foeDown(at, elite): put(2, at.x, at.y, elite ? 1 : 0)
    case let .moteCollected(at): put(3, at.x, at.y)
    case let .moteLost(at): put(4, at.x, at.y)
    case .stageEntered: put(5)
    case let .cairnBroken(at): put(6, at.x, at.y)
    }
}

/// −1 when the offer carries no signature, else 1 while it is armed.
private func signatureState(_ sim: RunSim) -> Double {
    guard sim.currentOffer()?.signature != nil else { return -1 }
    return (sim.state.card?.signatureArmed ?? false) ? 1 : 0
}

private func spineIndex(_ spine: CardSpine?) -> Int {
    switch spine {
    case .rust: return 0
    case .gold: return 1
    case .grave: return 2
    case .plague: return 3
    case .inkspine: return 4
    case nil: return 0
    }
}

/// Card and stage text, rebuilt only when the face changes.
private func fillText(_ sim: RunSim) {
    let s = sim.state
    let key = (s.card.map { "\($0.def.id)|\($0.committing)" } ?? "") + "|" + s.stage.id
    guard key != lastCardKey else { return }
    lastCardKey = key

    var fields = ["\"stage\":\(quote(s.stage.name))",
                  "\"stageId\":\(quote(s.stage.id))"]
    if let c = s.card {
        let offer = sim.currentOffer()
        let left = offer?.left ?? c.def.left
        let right = offer?.right ?? c.def.right
        fields.append("\"title\":\(quote(c.def.title))")
        fields.append("\"leftLabel\":\(quote(left.label))")
        fields.append("\"leftSub\":\(quote(left.subtitle))")
        fields.append("\"rightLabel\":\(quote(right.label))")
        fields.append("\"rightSub\":\(quote(right.subtitle))")
        if let sig = offer?.signature { fields.append("\"signature\":\(quote(sig.label))") }
    }
    write("{" + fields.joined(separator: ",") + "}")
}

/// Escapes above ASCII too, so the page needs no charset declaration.
private func quote(_ s: String) -> String {
    let digits = Array("0123456789abcdef")
    var out = "\""
    for c in s.unicodeScalars {
        if c == "\"" || c == "\\" {
            out += "\\"
            out.unicodeScalars.append(c)
        } else if c.value >= 0x20, c.value <= 0x7E {
            out.unicodeScalars.append(c)
        } else if c.value <= 0xFFFF {
            out += "\\u"
            for shift in stride(from: 12, through: 0, by: -4) {
                out.append(digits[Int((c.value >> UInt32(shift)) & 0xF)])
            }
        }
    }
    return out + "\""
}

private func write(_ s: String) {
    let bytes = Array(s.utf8)
    let n = min(bytes.count, 8191)
    for k in 0..<n { text[k] = bytes[k] }
    text[n] = 0
}
