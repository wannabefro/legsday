/// One frame of pointer input, translated from the render layer's touch stream.
/// The anchor/offset follow logic lives in the sim (deterministic, testable) —
/// the render layer only reports where the finger is and what it's doing.
public struct Input: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// No active touch — the drag target holds; the world keeps scrolling.
        case idle
        /// Touch down this frame: anchors the drag (fixed touch offset, R1).
        case began
        /// Touch moved (or held) this frame.
        case moved
        /// Touch lifted this frame.
        case ended
    }

    public var phase: Phase
    /// Pointer position in the sim's reference coordinate space.
    public var location: Vec2

    public init(phase: Phase = .idle, location: Vec2 = .zero) {
        self.phase = phase
        self.location = location
    }

    public static let idle = Input(phase: .idle, location: .zero)
}
