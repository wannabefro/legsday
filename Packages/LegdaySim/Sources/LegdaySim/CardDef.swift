/// The spine/faction band of a Fate Card. Colors are the render layer's job
/// (U7/U24); the sim carries only the tag.
public enum CardSpine: String, Equatable, Sendable, Codable {
    case rust, gold, grave, plague, inkspine
}

/// One side (L or R) of a Fate Card: what it does and how it reads.
public struct CardChoice: Equatable, Sendable, Codable {
    public var label: String      // e.g. "+1 bolt"
    public var subtitle: String   // e.g. "fog +26 for 30s"
    public var effects: [Effect]

    public init(label: String, subtitle: String, effects: [Effect]) {
        self.label = label
        self.subtitle = subtitle
        self.effects = effects
    }
}

/// A Fate Card definition — data, not a subclass, so content grows without new
/// types (KTD-7). U6 constructs the seed set in code; U10 moves it to JSON.
public struct CardDef: Equatable, Sendable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var spine: CardSpine
    public var isDeath: Bool
    public var left: CardChoice
    public var right: CardChoice

    public init(id: String, title: String, spine: CardSpine, isDeath: Bool,
                left: CardChoice, right: CardChoice) {
        self.id = id
        self.title = title
        self.spine = spine
        self.isDeath = isDeath
        self.left = left
        self.right = right
    }
}

/// A Fate Card currently in play. The card takes the thumb: it is dealt (rising
/// from a fog corner), engaged (tilting with the drag), then committed (sliding
/// off past the 30% threshold) or sprung back.
public struct ActiveCard: Equatable, Sendable {
    public var def: CardDef
    /// Horizontal drag/slide offset in reference points (graybox `off`).
    public var offset: Double
    /// Rise-in animation, 0…1 (graybox `anim`).
    public var rise: Double
    /// Rotational-spring tilt (radians) and its velocity — the card tilts with
    /// inertia toward the drag angle rather than rigidly following it (R20).
    public var tilt: Double
    public var tiltVel: Double
    /// True once committed and sliding away.
    public var committing: Bool
    /// Committed direction (−1 = left, +1 = right).
    public var dir: Int
    /// Dealt from Death's deck (R11).
    public let deathDealt: Bool

    public init(def: CardDef, deathDealt: Bool) {
        self.def = def
        self.offset = 0
        self.rise = 0
        self.tilt = 0
        self.tiltVel = 0
        self.committing = false
        self.dir = 0
        self.deathDealt = deathDealt
    }
}
