import Foundation

/// Essence motes drop from kills and ride the world down. The fog takes
/// whatever it reaches first (R6).
extension RunSim {
    /// Reach, not pull. A mote never comes to the Pilgrim; she goes to it, and
    /// going to it costs the ground she must climb again.
    private static let baseReach: Double = 16
    private static let magnetReachGain: Double = 0.35
    /// Essence falls past the Pilgrim before she can take it, so a kill and a
    /// claim are two separate decisions.
    static let dropBelow: Double = 60
    static let narrowLanePay: Double = 2
    private static let sinkScrollFactor: Double = 0.95
    private static let sinkBase: Double = 2
    private static let fogClaimMargin: Double = 30    // lost when past fog line + this
    private static let moteLostSplash: Double = 40

    /// Drop a mote from a felled foe (graybox: elite always drops val 3; a
    /// normal foe drops val 1 with 85% chance).
    mutating func dropMote(_ foe: Foe) {
        let at = Vec2(foe.pos.x, max(foe.pos.y, state.hero.pos.y) + Self.dropBelow)
        if foe.elite {
            addMote(at: at, radius: 8, value: 3 * narrowLaneBonus())
        } else if state.rng.unit() < 0.85 {
            addMote(at: at, radius: 5, value: narrowLaneBonus())
        }
    }

    /// Advance motes: every one sinks toward the fog; then collect or lose.
    mutating func updateMotes(dt: Double) {
        guard !state.motes.isEmpty else { return }
        let sink = (scrollEff() * Self.sinkScrollFactor + Self.sinkBase) * state.mods.moteSink
        for i in state.motes.indices {
            state.motes[i].pos.y += sink * dt
        }

        let reach = Self.baseReach + state.mods.magnet * Self.magnetReachGain
        let claimLine = fogLineY() + Self.fogClaimMargin
        var kept: [Mote] = []
        kept.reserveCapacity(state.motes.count)
        for m in state.motes {
            if (state.hero.pos - m.pos).length < reach {
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
