/// The deterministic physical-feel integrators (R20): the lantern pendulum and
/// the cloak, advanced at the sim's scaled dt so they slow with the world during
/// a card. Corpse tumble is cosmetic and lives in the render layer (KTD-3).
extension RunSim {
    mutating func updateFeel(dt: Double) {
        let heroDriveX = (state.hero.pos.x - state.prevHeroPos.x) / dt
        state.lantern.update(dt: dt, pivotDriveX: heroDriveX)
        state.cloak.update(dt: dt, pin: state.hero.pos)
        state.prevHeroPos = state.hero.pos
    }
}
