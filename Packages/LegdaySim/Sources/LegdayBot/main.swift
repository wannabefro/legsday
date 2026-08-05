import Foundation
import LegdaySim

// A bot that plays RunSim headlessly. The sim imports no SpriteKit, so a run
// costs milliseconds and a hundred runs answer balance questions that a human
// playtest can only guess at.

// MARK: - Arguments

struct Options {
    var runs = 20
    var firstSeed: UInt64 = 1
    var collection: String = "cold"   // cold | full | empty
    var verbose = false
    var csv = false
    var trace = false
    var cap = 900.0
}

func parseOptions() -> Options {
    var o = Options()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let a = it.next() {
        switch a {
        case "--runs": o.runs = Int(it.next() ?? "") ?? o.runs
        case "--seed": o.firstSeed = UInt64(it.next() ?? "") ?? o.firstSeed
        case "--collection": o.collection = it.next() ?? o.collection
        case "--verbose": o.verbose = true
        case "--csv": o.csv = true
        case "--trace": o.trace = true
        case "--cap": o.cap = Double(it.next() ?? "") ?? o.cap
        case "--help":
            print("""
            legdaybot — play the sim headlessly

              --runs N          runs to play (default 20)
              --seed N          first seed; runs use seed, seed+1, … (default 1)
              --collection K    cold | full | empty (default cold)
              --verbose         print every card drawn and the side taken
              --csv             one row per run, for a spreadsheet
              --trace           per-frame hero/fog state, and the cost of each card

            KNOWN GAP: the movement policy does not hold altitude. Every run ends
            with the Pilgrim pinned at the viewport floor inside the fog at ~63s,
            for every seed and every collection. Card decisions, deck statistics
            and the report are sound; survival numbers are not the game's.
            """)
            exit(0)
        default: FileHandle.standardError.write(Data("unknown argument \(a)\n".utf8)); exit(2)
        }
    }
    return o
}

// MARK: - Content

/// The tunables the app ships, so the bot's numbers are the game's numbers.
func loadTunables() -> Tunables {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // LegdayBot
        .deletingLastPathComponent()   // Sources
        .deletingLastPathComponent()   // LegdaySim
        .deletingLastPathComponent()   // Packages
        .deletingLastPathComponent()   // repo root
    let url = root.appendingPathComponent("Legday/Resources/tunables.json")
    guard let data = try? Data(contentsOf: url),
          let t = try? Tunables.decoded(from: data) else {
        FileHandle.standardError.write(Data("cannot read \(url.path)\n".utf8))
        exit(1)
    }
    return t
}

/// Matches GameFlow.seedCollection — a fresh install's four relics.
let coldStart: [String: Int] = [
    "second_knuckle": 2, "oath_of_footing": 2, "lantern_oil": 2, "the_thurible": 1,
]

func collection(_ key: String, catalog: CardCatalog) -> [String: Int] {
    switch key {
    case "empty": return [:]
    case "full":
        let pool = catalog.player + catalog.weapons
        return Dictionary(uniqueKeysWithValues: pool.map { ($0.id, Collection.maxTier) })
    default: return coldStart
    }
}

// MARK: - Policy

/// Rough value of one side of a card, in arbitrary points. Positive is good for
/// the Pilgrim. This is the bot's whole opinion — keep it legible, because every
/// balance number the harness reports is downstream of it.
func score(_ effects: [Effect]) -> Double {
    effects.reduce(0) { total, e in total + score(e) }
}

func score(_ e: Effect) -> Double {
    switch e {
    case let .multiply(field, x): return multiplierValue(field, x)
    case let .add(field, x): return addValue(field, x)
    case let .addBolts(n): return Double(n) * 30
    case let .addCharge(c): return c * 1.5
    case let .scaleEssence(f): return (f - 1) * 40
    case .smiteAllFoes: return 25
    case let .timed(base, seconds):
        // A window is worth less than forever; 60s is treated as par.
        return score(base) * min(1, seconds / 60)
    }
}

func multiplierValue(_ field: ModField, _ x: Double) -> Double {
    let delta = x - 1
    switch field {
    case .attackCooldown: return -delta * 60   // lower is faster
    case .footing:        return delta * 40
    case .magnet:         return delta * 35
    case .gain:           return delta * 30
    case .essMul:         return delta * 45
    case .scrollMul:      return -delta * 55   // a faster road is pressure
    case .moteSink:       return -delta * 25
    case .spawnMul:       return -delta * 50
    case .fogAdd:         return -delta * 50
    case .ropeLen, .ropeMass, .ropeThreshold: return delta * 15
    }
}

func addValue(_ field: ModField, _ x: Double) -> Double {
    switch field {
    case .fogAdd: return -x * 1.2   // fog is the clock; every point hurts
    default: return x
    }
}

// MARK: - One run

struct RunReport {
    var seed: UInt64
    var fathoms: Double
    var cardsDrawn: Int
    var deathDealt: Int
    var distinctTitles: Int
    var kills: Int
    var shards: Int
    var seconds: Double
    var ending: String
    var deckDryAt: Double?     // sim time the drafted deck first ran out
    var hitCap: Bool           // stopped by the harness, not by the game
}

func play(seed: UInt64, tunables: Tunables, catalog: CardCatalog,
          collection: [String: Int], verbose: Bool, trace: Bool = false,
          cap: Double = 900) -> RunReport {
    let viewport = Vec2(393, 852)
    var sim = RunSim(tunables: tunables, viewport: viewport, seed: seed,
                     catalog: catalog, collection: collection)

    let step = 1.0 / 60.0
    let hardCap = cap
    var pointer = Vec2(viewport.x / 2, viewport.y * 0.7)
    var touchDown = false
    var titles = Set<String>()
    var drawn = 0, deathDealt = 0
    var deckDryAt: Double?
    // A card is new when the previous frame had none engaged. Keying on
    // state.drawn instead misses every fork, Fusion and the Finale — those set
    // state.card directly and never touch the ordinal, so the bot would never
    // anchor the grab and would hang on the card until the fog took it.
    var sawCard = false
    var needsGrab = true
    var yAtDeal: Double?
    var tAtDeal: Double = 0
    var framesInCard = 0
    var frame = 0
    var lastTrace = -999

    while !sim.state.dead, sim.state.time < hardCap {
        frame += 1
        if let card = sim.state.card, !card.committing {
            if !sawCard {
                sawCard = true
                needsGrab = true
                yAtDeal = sim.state.hero.pos.y
                tAtDeal = sim.state.time
                framesInCard = 0
                drawn += 1
                titles.insert(card.def.title)
                if card.deathDealt { deathDealt += 1 }
                if deckDryAt == nil, sim.state.deck.isEmpty { deckDryAt = sim.state.time }
                if verbose {
                    let mark = card.deathDealt ? "†" : " "
                    print(String(format: "  %6.1fs %@ %@", sim.state.time, mark, card.def.title))
                }
            }
            // The card takes the thumb: the first touch anchors the grab, so a
            // drag sent before it reads as zero offset and nothing ever moves.
            let input: Input
            if needsGrab {
                needsGrab = false
                touchDown = true
                input = Input(phase: .began, location: pointer)
            } else if abs(card.offset) < viewport.x * RunSim.commitThreshold {
                let offer = sim.currentOffer()
                let left = offer?.left ?? card.def.left
                let right = offer?.right ?? card.def.right
                let takeRight = score(right.effects) >= score(left.effects)
                let past = viewport.x * (RunSim.commitThreshold + 0.08)
                input = Input(phase: .moved,
                              location: Vec2(pointer.x + (takeRight ? past : -past), pointer.y))
            } else {
                touchDown = false
                input = Input(phase: .ended, location: pointer)
            }
            framesInCard += 1
            sim.tick(dt: step, input: input)
            continue
        }
        sawCard = false
        if let y0 = yAtDeal, sim.state.card == nil {
            if trace {
                print(String(format:
                    "  CARD cost: y %.0f -> %.0f (%+.0f px) over %d frames, sim time %+.2fs",
                    y0, sim.state.hero.pos.y, sim.state.hero.pos.y - y0,
                    framesInCard, sim.state.time - tAtDeal))
            }
            yAtDeal = nil
        }
        // Re-peg the anchor at centre, never at the last pointer. Anchoring at
        // the stale pointer makes the following drag measure error_new minus
        // error_old — a differential controller, which commands nothing while
        // the error is steady and so cannot answer the fog's constant pull.
        if !touchDown {
            touchDown = true
            pointer = Vec2(viewport.x / 2, viewport.y / 2)
            sim.tick(dt: step, input: Input(phase: .began, location: pointer))
            continue
        }

        if trace, frame - lastTrace >= 60 {
            lastTrace = frame
            let s = sim.state
            print(String(format:
                "  t=%5.1f pos.y=%4.0f target.y=%6.0f goal.y=%4.0f fog=%3.0f inFog=%@ vel.y=%6.1f",
                s.time, s.hero.pos.y, s.hero.target.y,
                steer(sim: sim, viewport: viewport).y, sim.fogLineY(),
                s.heroInFog ? "Y" : "n", s.hero.vel.y))
        }

        // No card: steer toward the best mote, and climb out of the fog first.
        let goal = steer(sim: sim, viewport: viewport)
        let target = sim.state.hero.target
        // Offset-follow (R1): the anchor pegs (pointer, target) on touch-down,
        // and the drag sets target = anchorTarget + (pointer − anchorPointer) ×
        // gain. Anchored at centre, a pointer at centre + error commands exactly
        // that error, with full travel available in both directions.
        let centre = Vec2(viewport.x / 2, viewport.y / 2)
        let reach = 120.0
        let error = goal - target
        pointer = Vec2(centre.x + min(max(error.x, -reach), reach),
                       centre.y + min(max(error.y, -reach), reach))
        touchDown = false   // lift after the drag, so the next frame re-pegs
        sim.tick(dt: step, input: Input(phase: .moved, location: pointer))
    }

    if trace {
        let f = sim.state
        print(String(format:
            "  END t=%.2f dead=%@ inFog=%@ fogT=%.2f hero=(%.0f,%.0f) line=%.0f press=%.0f duel=%@ finale=%@",
            f.time, f.dead ? "Y":"n", f.heroInFog ? "Y":"n", f.hero.fogTime,
            f.hero.pos.x, f.hero.pos.y, sim.fogLineY(), f.fogPressure,
            f.duel == nil ? "n":"Y", f.finaleDealt ? "Y":"n"))
    }
    let r = sim.result()
    return RunReport(seed: seed, fathoms: r.fathoms, cardsDrawn: drawn,
                     deathDealt: deathDealt, distinctTitles: titles.count,
                     kills: r.felled, shards: r.shards, seconds: sim.state.time,
                     ending: "\(r.ending)", deckDryAt: deckDryAt, hitCap: !sim.state.dead)
}

/// Where the Pilgrim wants to be. The loop is kill → motes → essence → cards,
/// and kills also push the fog back, so a bot that only dodges starves and
/// drowns. Priority: escape the grip, bank motes, then hunt.
func steer(sim: RunSim, viewport: Vec2) -> Vec2 {
    let hero = sim.state.hero.pos
    let fogY = sim.fogLineY()
    // Never send the Pilgrim into the bottom band at all. Everything below the
    // floor is refused, including the target that a chase would produce.
    let floorY = fogY - 170
    let goal = rawGoal(sim: sim, viewport: viewport, hero: hero, floorY: floorY)
    return Vec2(min(max(goal.x, 12), viewport.x - 12),
                min(max(goal.y, 60), floorY))
}

func rawGoal(sim: RunSim, viewport: Vec2, hero: Vec2, floorY: Double) -> Vec2 {
    // Motes sink into the fog and are lost, so they outrank a foe.
    if let mote = nearest(sim.state.motes.map(\.pos), to: hero, above: floorY) {
        return mote
    }
    // Stand off rather than on top: contact is what shoves the Pilgrim down.
    if let foe = nearest(sim.state.foes.map(\.pos), to: hero, above: floorY) {
        let away = hero - foe
        let d = max(away.length, 1)
        return Vec2(foe.x + away.x / d * 30, foe.y + away.y / d * 30)
    }
    return Vec2(viewport.x / 2, viewport.y * 0.45)
}

func nearest(_ points: [Vec2], to hero: Vec2, above limitY: Double) -> Vec2? {
    var best: Vec2?
    var bestD = Double.greatestFiniteMagnitude
    for p in points where p.y < limitY {
        let d = (p - hero).length
        if d < bestD { bestD = d; best = p }
    }
    return best
}

// MARK: - Report

let options = parseOptions()
let tunables = loadTunables()
let catalog = CardCatalog.seed
let owned = collection(options.collection, catalog: catalog)

var reports: [RunReport] = []
for i in 0..<options.runs {
    let seed = options.firstSeed &+ UInt64(i)
    if options.verbose { print("seed \(seed)") }
    reports.append(play(seed: seed, tunables: tunables, catalog: catalog,
                        collection: owned, verbose: options.verbose, trace: options.trace,
                        cap: options.cap))
}

func median(_ xs: [Double]) -> Double {
    guard !xs.isEmpty else { return 0 }
    let s = xs.sorted()
    return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}

if options.csv {
    print("seed,fathoms,seconds,cards,deathDealt,distinct,felled,shards,ending,deckDryAt")
    for r in reports {
        print("\(r.seed),\(Int(r.fathoms)),\(String(format: "%.1f", r.seconds)),\(r.cardsDrawn),"
            + "\(r.deathDealt),\(r.distinctTitles),\(r.kills),\(r.shards),\(r.ending),"
            + (r.deckDryAt.map { String(format: "%.1f", $0) } ?? ""))
    }
    exit(0)
}

let fathoms = reports.map(\.fathoms)
let seconds = reports.map(\.seconds)
let cards = reports.map { Double($0.cardsDrawn) }
let distinct = reports.map { Double($0.distinctTitles) }
let totalDraws = reports.reduce(0) { $0 + $1.cardsDrawn }
let totalDeath = reports.reduce(0) { $0 + $1.deathDealt }
let dry = reports.compactMap(\.deckDryAt)
let capped = reports.filter(\.hitCap).count
let reachableFaces = catalog.player.count + catalog.death.count + catalog.threats.count
    + catalog.forks.count + catalog.weapons.count + catalog.rivalOffers.count
var endings: [String: Int] = [:]
for r in reports { endings[r.ending, default: 0] += 1 }

print("""

\(options.runs) runs · collection \(options.collection) · seeds \(options.firstSeed)…\(options.firstSeed &+ UInt64(options.runs - 1))

  fathoms        median \(Int(median(fathoms)))   min \(Int(fathoms.min() ?? 0))   max \(Int(fathoms.max() ?? 0))
  run length     median \(String(format: "%.0f", median(seconds)))s
  cards drawn    median \(Int(median(cards)))
  distinct faces median \(Int(median(distinct)))  of \(reachableFaces) reachable
  Death's share  \(totalDraws > 0 ? Int(Double(totalDeath) / Double(totalDraws) * 100) : 0)% of \(totalDraws) draws
  deck ran dry   \(dry.count)/\(options.runs) runs\(dry.isEmpty ? "" : ", median \(String(format: "%.0f", median(dry)))s")
  hit the cap    \(capped)/\(options.runs) runs survived to \(Int(options.cap))s — the harness stopped them
  endings        \(endings.map { "\($0.key) ×\($0.value)" }.sorted().joined(separator: "  "))
""")
