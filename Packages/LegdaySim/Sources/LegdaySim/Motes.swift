import Foundation

/// Essence motes drop from kills and ride the world down. The fog takes
/// whatever it reaches first (R6).
extension RunSim {
    private static let magnetSpan: Double = 2.4      // magnet reach = mods.magnet · 2.4
    private static let hooverBasePull: Double = 140
    private static let hooverGain: Double = 6
    private static let collectRadius: Double = 16
    static let narrowLanePay: Double = 2
    private static let sinkScrollFactor: Double = 0.95
    private static let sinkBase: Double = 2
    private static let fogClaimMargin: Double = 30    // lost when past fog line + this
    private static let moteLostSplash: Double = 40

    /// Drop a mote from a felled foe (graybox: elite always drops val 3; a
    /// normal foe drops val 1 with 85% chance).
    mutating func dropMote(_ foe: Foe) {
        if foe.elite {
            addMote(at: foe.pos, radius: 8, value: 3 * narrowLaneBonus())
        } else if state.rng.unit() < 0.85 {
            addMote(at: foe.pos, radius: 5, value: narrowLaneBonus())
        }
    }

    /// Advance motes: hoover within magnet range, else sink; then collect or
    /// lose to the fog.
    mutating func updateMotes(dt: Double) {
        guard !state.motes.isEmpty else { return }
        let magnetRange = state.mods.magnet * Self.magnetSpan
        let sink = (scrollEff() * Self.sinkScrollFactor + Self.sinkBase) * state.mods.moteSink

        for i in state.motes.indices {
            let toHero = state.hero.pos - state.motes[i].pos
            let d = max(toHero.length, 1)
            if d < magnetRange {
                let pull = Self.hooverBasePull + (magnetRange - d) * Self.hooverGain
                state.motes[i].pos.x += toHero.x / d * pull * dt
                state.motes[i].pos.y += toHero.y / d * pull * dt
            } else {
                state.motes[i].pos.y += sink * dt
            }
        }

        let claimLine = fogLineY() + Self.fogClaimMargin
        var kept: [Mote] = []
        kept.reserveCapacity(state.motes.count)
        for m in state.motes {
            if (state.hero.pos - m.pos).length < Self.collectRadius {
                let gain = state.mods.essMul * m.value
                state.essence += gain
                state.charge += gain
                state.frameEvents.append(.moteCollected(at: m.pos))
            } else if m.pos.y >= claimLine {
                let f = min(max(m.pos.x / state.width, 0), 1)
                state.fogSurface.inject(atFraction: f, magnitude: Self.moteLostSplash)
                state.frameEvents.append(.moteLost(at: m.pos))
            } else {
                kept.append(m)
            }
        }
        state.motes = kept
    }

    /// Greed against distance, drawn in terrain: the tight lane pays double.
    func narrowLaneBonus() -> Double {
        let lane = state.gorge.lane(ofX: state.hero.pos.x,
                                    at: terrainY(of: state.hero.pos.y))
        return lane == .narrow ? Self.narrowLanePay : 1
    }

    private mutating func addMote(at pos: Vec2, radius: Double, value: Double) {
        state.motes.append(Mote(id: state.nextMoteId, pos: pos, radius: radius, value: value))
        state.nextMoteId += 1
    }

    /// Test/debug seam: inject a mote; returns its id.
    @discardableResult
    mutating func debugAddMote(at pos: Vec2, value: Double = 1) -> Int {
        let id = state.nextMoteId
        addMote(at: pos, radius: 5, value: value)
        return id
    }
}
