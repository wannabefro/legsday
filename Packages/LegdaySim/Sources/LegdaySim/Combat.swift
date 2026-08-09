import Foundation

/// Swarm spawning, foe steering, knockdown contact, and auto-attack — ported
/// from the graybox. No physics engine: circle-overlap math only. Damage to the
/// Pilgrim is displacement (a shove + i-frames), never HP.
extension RunSim {
    private static let heroContactRadius: Double = 13
    private static let foeScrollDrift: Double = 0.22   // foes ride the scroll down
    private static let foeRecoil: Double = 14          // foe knocked back on contact
    private static let attackRange: Double = 340
    static let eliteShoveFactor: Double = 1.7
    static let eliteFogPushFactor: Double = 3          // used by U4 fog pushback

    /// Spawns per second at the current time and stage (the spawn ramp).
    func spawnRate() -> Double {
        let ramp: Double = 0.7 + state.time * 0.05
        let stageSpawn = state.stage.spawn
        return tunables.spawn * stageSpawn * state.mods.spawnMul * ramp
    }

    /// Spawn foes on the ramping clock (graybox `spawnAcc`).
    mutating func spawnFoes(dt: Double) {
        let rate = spawnRate()
        state.spawnAcc += dt * rate
        while state.spawnAcc > 1 {
            state.spawnAcc -= 1
            spawnFoe()
        }
    }

    private mutating func spawnFoe() {
        let side = state.rng.unit()
        let x: Double, y: Double
        if side < 0.7 {
            x = state.rng.range(20, state.width - 20); y = -20        // top
        } else if side < 0.85 {
            x = -16; y = state.rng.range(0, state.height * 0.45)      // left
        } else {
            x = state.width + 16; y = state.rng.range(0, state.height * 0.45) // right
        }
        let elite = state.time > 30 && state.rng.unit() < 0.15
        let radius = elite ? 15 : 9 + state.rng.unit() * 3
        let hp = elite ? 3 : (state.time > 45 ? 2 : 1)
        let speed = state.rng.range(48, 92) + min(60, state.time * 0.8)
        // Detuned per foe, so no two bodies swing through a turn alike.
        let turnGain = (elite ? 7.0 : 13.0) + state.rng.unit() * 6
        state.foes.append(Foe(id: state.nextFoeId, pos: Vec2(x, y),
                              radius: radius, hp: hp, speed: speed, elite: elite,
                              turnGain: turnGain,
                              wobble: state.rng.range(0, 6.283)))
        state.nextFoeId += 1
        state.spawnedCount += 1
    }

    /// Steer every foe toward the Pilgrim; resolve knockdown contact using the
    /// pre-move separation (graybox order). One shove per step — i-frames set
    /// on the first contact block the rest.
    mutating func steerAndContact(dt: Double) {
        let sink = scrollEff() * Self.foeScrollDrift + state.height * Rig.foeDownBias
        let drag = pow(Rig.foeDrag, dt)
        for i in state.foes.indices {
            let toHero = state.hero.pos - state.foes[i].pos
            let dist = max(toHero.length, 1)
            let pull = state.foes[i].speed * Rig.foeAccel
            state.foes[i].vel.x += toHero.x / dist * pull * dt
            state.foes[i].vel.y += (toHero.y / dist * pull + sink) * dt
            state.foes[i].vel.x *= drag
            state.foes[i].vel.y *= drag
            if inBriar(state.foes[i].pos) {
                let snag = pow(Feature.foeBriarDrag, dt * 60)
                state.foes[i].vel.x *= snag
                state.foes[i].vel.y *= snag
            }
            state.foes[i].pos.x += state.foes[i].vel.x * dt
            state.foes[i].pos.y += state.foes[i].vel.y * dt
            RunSim.advanceFoeRig(&state.foes[i], dt: dt)

            let contact = dist < state.foes[i].radius + Self.heroContactRadius
            if contact, state.hero.invuln <= 0 {
                var s = Vec2(toHero.x / dist, toHero.y / dist)
                s.y += tunables.downBias
                let m = max(s.length, 1)
                let impulse = tunables.shove * (state.foes[i].elite ? Self.eliteShoveFactor : 1)
                    / state.mods.footing
                state.hero.vel.x += s.x / m * impulse
                state.hero.vel.y += s.y / m * impulse
                state.hero.invuln = tunables.iframes
                state.frameEvents.append(.heroShoved(at: state.hero.pos))
                state.foes[i].knockVel.x -= s.x / m * Self.foeRecoil * 6
                state.foes[i].knockVel.y -= s.y / m * Self.foeRecoil * 6
                state.foes[i].vel.x -= s.x / m * Self.foeRecoil * 4
                state.foes[i].vel.y -= s.y / m * Self.foeRecoil * 4
            }

            let foe = state.foes[i]
            var ignored = Vec2.zero
            state.foes[i].pos = pushOutOfCairns(
                state.gorge.clamp(foe.pos, radius: foe.radius, at: terrainY(of: foe.pos.y)),
                velocity: &ignored, radius: foe.radius)
        }
        cullFoes()
    }

    private mutating func cullFoes() {
        let w = state.width, h = state.height
        state.foes.removeAll { $0.pos.y >= h + 60 || $0.pos.x <= -60 || $0.pos.x >= w + 60 }
    }

    /// Auto-attack: fire up to `bolts` at the nearest in-range foes on cooldown.
    /// A kill counts, emits a corpse event, and (U4/U5) pushes the fog and drops
    /// a mote. During the duel every bolt lands on the Reaper instead (U19).
    mutating func autoAttack(dt: Double) {
        state.attackTimer -= dt
        guard state.attackTimer <= 0 else { return }
        guard !state.heroGripped else { return } // attacks muted in the grip (R4)

        if state.duel != nil {
            state.attackTimer = state.mods.attackCooldown
            if let d = state.duel {
                state.frameEvents.append(.attack(from: state.hero.pos, to: d.reaperPos))
            }
            hitReaper()
            return
        }

        let inRange = state.foes.enumerated()
            .map { (id: $0.element.id, d: (state.hero.pos - $0.element.pos).length) }
            .filter { $0.d < Self.attackRange }
            .sorted { $0.d < $1.d }

        let heraldInRange = state.herald.map { (state.hero.pos - $0.pos).length < Self.attackRange } ?? false
        guard !inRange.isEmpty || heraldInRange else { state.attackTimer = 0.12; return }
        state.attackTimer = state.mods.attackCooldown

        // A cairn takes the hit the foe behind it does not, and the volley is spent.
        if let nearest = inRange.first,
           let foe = state.foes.first(where: { $0.id == nearest.id }),
           let blocker = cairnBlocking(from: state.hero.pos, to: foe.pos) {
            let stone = state.features[blocker]
            state.frameEvents.append(
                .attack(from: state.hero.pos, to: Vec2(stone.x, screenY(of: stone))))
            strikeCairn(at: blocker)
            return
        }

        // The Herald is durable: it soaks one bolt per cadence while in range (R16).
        if heraldInRange, var h = state.herald {
            state.frameEvents.append(.attack(from: state.hero.pos, to: h.pos))
            h.hp -= 1
            if h.hp <= 0 { fellHerald(h) } else { state.herald = h }
        }

        if let first = inRange.first,
           let i = state.foes.firstIndex(where: { $0.id == first.id }) {
            fireReaction(toward: state.foes[i].pos)
        }
        for target in inRange.prefix(state.mods.bolts) {
            guard let i = state.foes.firstIndex(where: { $0.id == target.id }) else { continue }
            state.frameEvents.append(.attack(from: state.hero.pos, to: state.foes[i].pos))
            let away = state.foes[i].pos - state.hero.pos
            let d = max(away.length, 1)
            state.foes[i].knockVel.x += away.x / d * 90
            state.foes[i].knockVel.y += away.y / d * 90
            state.foes[i].hp -= 1
            if state.foes[i].hp <= 0 {
                let felled = state.foes[i]
                state.kills += 1
                state.frameEvents.append(.foeDown(at: felled.pos, elite: felled.elite))
                onFoeFelled(felled)
                state.foes.remove(at: i)
            }
        }
    }

    /// Kill consequences owned by later units: U4 fog pushback + splash, U5
    /// mote drop.
    mutating func onFoeFelled(_ foe: Foe) {
        applyFogKill(foe)
        dropMote(foe)
    }

    /// Test/debug seam: mutate the otherwise-encapsulated state.
    mutating func debugMutate(_ body: (inout RunState) -> Void) { body(&state) }

    /// Test/debug seam: inject a feature at a screen position; returns its id.
    @discardableResult
    mutating func debugAddFeature(_ kind: Feature.Kind, at pos: Vec2,
                                  extent: Double = 30) -> Int {
        let id = state.nextFeatureId
        state.features.append(Feature(id: id, kind: kind,
                                      terrainY: terrainY(of: pos.y), x: pos.x,
                                      extent: extent,
                                      hp: kind == .cairn ? Feature.cairnHP : 0,
                                      rotation: 0))
        state.nextFeatureId += 1
        return id
    }

    /// Test/debug seam: inject a foe at a position; returns its id.
    @discardableResult
    mutating func debugAddFoe(at pos: Vec2, elite: Bool = false, hp: Int = 1, speed: Double = 60) -> Int {
        let id = state.nextFoeId
        state.foes.append(Foe(id: id, pos: pos,
                              radius: elite ? 15 : 10, hp: hp, speed: speed, elite: elite))
        state.nextFoeId += 1
        state.spawnedCount += 1
        return id
    }
}
