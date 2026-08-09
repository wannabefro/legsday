/// The deterministic feel integrators (R20). They advance at the sim's scaled
/// dt, so they slow with the world while a card is up.
extension RunSim {
    mutating func updateFeel(dt: Double) {
        let drive = (state.hero.pos - state.prevHeroPos) * (1 / dt)
        state.lantern.update(dt: dt, pivotDriveX: drive.x)
        let accel = (drive - state.prevDrive) * (1 / dt)
        let turnRate = Rig.shortestTurn(from: state.prevHeading,
                                        to: state.hero.heading) / dt
        state.cloak.update(dt: dt, heading: state.hero.heading, turnRate: turnRate,
                           accel: accel, velocity: drive, speed: drive.length)
        state.prevHeading = state.hero.heading
        state.prevDrive = drive
        state.prevHeroPos = state.hero.pos
    }
}
