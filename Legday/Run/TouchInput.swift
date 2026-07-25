import LegdaySim

/// Translates a single owning touch's lifecycle into the sim's per-frame
/// `Input`. The subtle parts — coalescing a same-frame began+move so the
/// `.began` still reaches the sim, and collapsing one-frame phases after each
/// tick — live here so they're testable without fabricating `UITouch`es.
/// Multi-touch *identity* (which `UITouch` owns the run) stays in `RunScene`.
struct TouchInputAccumulator {
    private(set) var current: Input = .idle
    private(set) var hasOwner = false

    /// First touch down claims the run; further downs are ignored.
    mutating func down(_ p: Vec2) {
        guard !hasOwner else { return }
        hasOwner = true
        current = Input(phase: .began, location: p)
    }

    mutating func move(_ p: Vec2) {
        guard hasOwner else { return }
        // Don't overwrite an unconsumed `.began` — keep it, just update location.
        let phase: Input.Phase = current.phase == .began ? .began : .moved
        current = Input(phase: phase, location: p)
    }

    /// Release — a card commits past threshold.
    mutating func up(_ p: Vec2) {
        guard hasOwner else { return }
        current = Input(phase: .ended, location: p)
        hasOwner = false
    }

    /// Abort — a card always springs back.
    mutating func cancel(_ p: Vec2) {
        guard hasOwner else { return }
        current = Input(phase: .cancelled, location: p)
        hasOwner = false
    }

    /// Collapse one-frame phases after `current` has been fed to a tick: a held
    /// touch persists as `.moved`, a lifted/cancelled one falls to `.idle`.
    mutating func advance() {
        switch current.phase {
        case .began: current = Input(phase: .moved, location: current.location)
        case .ended, .cancelled: current = .idle
        case .moved, .idle: break
        }
    }
}
