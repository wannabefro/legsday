/// The card-interrupt time contract (R8, KTD-2): while a card is up the world
/// eases toward `cardSlow` (fast in), then eases back to 1 over ~0.8s after the
/// commit. The scene never owns game time — this scales how much sim time the
/// fixed-step accumulator is fed, and the hero drifts at full scroll outside it
/// (reading costs ground).
public struct Timescale: Equatable, Sendable {
    public private(set) var current: Double = 1

    static let easeInRate: Double = 10    // fast drop when a card arrives
    static let easeOutRate: Double = 1.8  // ~0.8s ease-back after commit

    /// Move `current` toward `target`, eased on real time (fast to slow, slow
    /// to fast) — the graybox `ts` blend.
    public mutating func advance(toward target: Double, realDt: Double) {
        let rate = target < current ? Self.easeInRate : Self.easeOutRate
        current += (target - current) * min(1, realDt * rate)
    }
}
