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

    public init(id: Int, pos: Vec2, radius: Double, hp: Int, speed: Double, elite: Bool) {
        self.id = id
        self.pos = pos
        self.radius = radius
        self.hp = hp
        self.speed = speed
        self.elite = elite
        self.whipAcc = 0
    }
}
