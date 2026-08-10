import Foundation
import Testing
@testable import LegdaySim

/// The screen holds a bounded crowd. Overflow waits rather than vanishing, so
/// the swarm's total pressure is unchanged and only its shape is.
struct ThreatCapTests {
    private static let W = 393.0, H = 852.0

    private static func played(_ seconds: Double, cap: Int,
                               seed: UInt64 = 5) -> (RunSim, Int, Int) {
        var s = RunSim(tunables: tunables, viewport: Vec2(W, H), seed: seed,
                       threatCap: cap)
        var peak = 0, longestQueue = 0
        for _ in 0..<Int(seconds / RunSim.fixedStep) {
            s.tick(dt: RunSim.fixedStep, input: .idle)
            peak = max(peak, s.state.foes.count)
            longestQueue = max(longestQueue, s.state.queuedFoes)
        }
        return (s, peak, longestQueue)
    }

    @Test func theScreenNeverHoldsMoreThanTheCap() {
        let (_, peak, queued) = Self.played(90, cap: 6)
        #expect(peak <= 6)
        #expect(queued > 0)
    }

    @Test func overflowWaitsInsteadOfVanishing() {
        let (s, peak, _) = Self.played(90, cap: 6)
        #expect(peak == 6)
        #expect(s.state.spawnedCount + s.state.queuedFoes > 20)
    }

    @Test func theQueueItselfIsBounded() {
        let (_, _, queued) = Self.played(200, cap: 2)
        #expect(queued <= RunSim.queueCap)
    }

    /// A cap this loose must never bind, or it is a balance change in disguise.
    @Test func theShippedCapDoesNotChangeAnUncappedRun() {
        let capped = Self.played(90, cap: RunSim.defaultThreatCap).0
        let free = Self.played(90, cap: 100_000).0
        #expect(capped.state.fathoms == free.state.fathoms)
        #expect(capped.state.kills == free.state.kills)
    }

    @Test func theSameSeedStillReplaysExactly() {
        let a = Self.played(60, cap: 6, seed: 31).0
        let b = Self.played(60, cap: 6, seed: 31).0
        #expect(a.state.fingerprint == b.state.fingerprint)
        #expect(Self.played(60, cap: 6, seed: 32).0.state.fingerprint != a.state.fingerprint)
    }

    private static let tunables = Tunables(
        scroll: 78, spawn: 0.3, shove: 120, iframes: 0.55, fogGrace: 0.8, fogGrip: 2.4,
        fogCreep: 1.5, killPush: 0.9, downBias: 0.35, cardSlow: 1,
        firstCardCost: 9_999, cardCostIncrement: 1)
}
