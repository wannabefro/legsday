import Foundation

/// The sprite as a rig, ported from the prototype. One drawing turns,
/// banks, kicks back, and lags its own turn.
public enum Rig {
    /// Below this drive speed the body holds its heading instead of jittering.
    public static let stillSpeed: Double = 3
    public static let headingRate: Double = 14
    public static let leanRate: Double = 7
    public static let leanReturnRate: Double = 5
    public static let leanLimit: Double = 0.34
    public static let leanFromTurn: Double = 0.055
    public static let strideFromDistance: Double = 0.013

    /// Recoil spring: stiff and damped, so the kick is a snap not a drift.
    public static let recoilTension: Double = 150
    public static let recoilDamping: Double = 17
    public static let recoilImpulse: Double = 35
    public static let aimGlance: Double = 0.20
    public static let aimDecay: Double = 7

    /// Foe acceleration is speed × this; drag returns terminal to speed.
    public static let foeAccel: Double = 4
    public static let foeDrag: Double = 0.02
    public static let foeDownBias: Double = 0.12
    public static let foeTurnDamping: Double = 4.2
    public static let foeWobbleRate: Double = 3.1
    public static let knockTension: Double = 150
    public static let knockDamping: Double = 13

    /// Shortest signed angle from `from` to `to`, in −π…π.
    public static func shortestTurn(from: Double, to: Double) -> Double {
        ((to - from + .pi * 3).truncatingRemainder(dividingBy: .pi * 2)) - .pi
    }
}

extension RunSim {
    /// Turn the body toward travel, bank it, spring the recoil home.
    /// `drive` is the distance covered this step, knockback included.
    mutating func updateHeroRig(dt: Double, drive: Vec2) {
        let speed = drive.length / max(dt, 1e-4)
        var h = state.hero
        if speed > Rig.stillSpeed {
            let want = atan2(drive.x, -drive.y)
            let turn = Rig.shortestTurn(from: h.heading, to: want)
                * min(1, dt * Rig.headingRate)
            h.heading += turn
            let wantLean = min(max(turn / max(dt, 1e-3) * Rig.leanFromTurn,
                                   -Rig.leanLimit), Rig.leanLimit)
            h.lean += (wantLean - h.lean) * min(1, dt * Rig.leanRate)
        } else {
            h.lean += (0 - h.lean) * min(1, dt * Rig.leanReturnRate)
        }
        h.stride += speed * dt * Rig.strideFromDistance

        h.recoilVel.x += (-Rig.recoilTension * h.recoil.x
                          - Rig.recoilDamping * h.recoilVel.x) * dt
        h.recoilVel.y += (-Rig.recoilTension * h.recoil.y
                          - Rig.recoilDamping * h.recoilVel.y) * dt
        h.recoil.x += h.recoilVel.x * dt
        h.recoil.y += h.recoilVel.y * dt
        h.aim *= exp(-dt * Rig.aimDecay)
        state.hero = h
    }

    /// A shot throws the body back and turns the hood toward what it hit.
    mutating func fireReaction(toward target: Vec2) {
        let away = target - state.hero.pos
        let d = max(away.length, 1)
        let ux = away.x / d, uy = away.y / d
        state.hero.recoilVel.x -= ux * Rig.recoilImpulse
        state.hero.recoilVel.y -= uy * Rig.recoilImpulse
        let want = atan2(ux, -uy)
        state.hero.aim = Rig.shortestTurn(from: state.hero.heading, to: want) * Rig.aimGlance
    }

    /// Advance one foe's body: turn lag, idle sway, and the knock spring.
    static func advanceFoeRig(_ foe: inout Foe, dt: Double) {
        if foe.vel.length > 1 {
            let want = atan2(foe.vel.y, foe.vel.x)
            let turn = Rig.shortestTurn(from: foe.rotation, to: want)
            foe.rotationVel += (foe.turnGain * turn
                                - Rig.foeTurnDamping * foe.rotationVel) * dt
            foe.rotation += foe.rotationVel * dt
        }
        foe.wobble += dt * Rig.foeWobbleRate
        foe.knockVel.x += (-Rig.knockTension * foe.knock.x
                           - Rig.knockDamping * foe.knockVel.x) * dt
        foe.knockVel.y += (-Rig.knockTension * foe.knock.y
                           - Rig.knockDamping * foe.knockVel.y) * dt
        foe.knock.x += foe.knockVel.x * dt
        foe.knock.y += foe.knockVel.y * dt
    }
}
