/// A pursuing foe. Damage is displacement, never HP loss on the hero — foes
/// have HP, the Pilgrim does not (the fog is the only killer).
public struct Foe: Equatable, Sendable, Identifiable {
    /// Stable identity for render pooling and deterministic iteration.
    public let id: Int
    public var pos: Vec2
    public var radius: Double
    public var hp: Int
    public var speed: Double
    public var elite: Bool
    /// Fractional whip damage accumulated from the chain weapon's head (U16);
    /// each whole unit strips one HP.
    public var whipAcc: Double
    /// It accelerates and carries momentum, so it overshoots and swings back.
    public var vel: Vec2
    /// The body lags the direction of travel on a spring, so a turn swings it.
    public var rotation: Double
    public var rotationVel: Double
    /// Turn stiffness, detuned per foe so no two swing alike.
    public var turnGain: Double
    /// Idle sway phase.
    public var wobble: Double
    /// Hit displacement, drawn only. It springs home.
    public var knock: Vec2
    public var knockVel: Vec2

    public init(id: Int, pos: Vec2, radius: Double, hp: Int, speed: Double,
                elite: Bool, turnGain: Double = 13, wobble: Double = 0) {
        self.id = id
        self.pos = pos
        self.radius = radius
        self.hp = hp
        self.speed = speed
        self.elite = elite
        self.whipAcc = 0
        self.vel = .zero
        self.rotation = .pi / 2
        self.rotationVel = 0
        self.turnGain = turnGain
        self.wobble = wobble
        self.knock = .zero
        self.knockVel = .zero
    }
}
