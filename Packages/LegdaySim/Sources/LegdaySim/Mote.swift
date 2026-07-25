/// An essence mote: it rides the world down toward the fog and hoovers to the
/// hero inside magnet range. Harvesting is a dive — the height economy and the
/// collection decision are the same thing (R6).
public struct Mote: Equatable, Sendable, Identifiable {
    public let id: Int
    public var pos: Vec2
    public var radius: Double
    public var value: Double

    public init(id: Int, pos: Vec2, radius: Double, value: Double) {
        self.id = id
        self.pos = pos
        self.radius = radius
        self.value = value
    }
}
