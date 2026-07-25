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
    /// Weapon cards carry a form/growth/signature spec (U11); the L/R shown for
    /// such a card is resolved from weapon state at deal time, so `left`/`right`
    /// here are only the neutral fallback labels. `nil` for ordinary cards.
    public var weapon: WeaponDef?
    /// Gameplay faction for affinity/hostility (U12) — distinct from `spine`,
    /// which is a render band. `nil` = factionless (the graybox seed cards).
    public var faction: Faction?
    /// A rival threat card interleaved into the stream by hostility (U12).
    /// Committing one does not build affinity for its faction.
    public var isThreat: Bool
    /// A world-owned mandatory fork (U13): risk vs safe, resolved by run time.
    /// Present → the card is a fork (zero-cost, no spring-back).
    public var fork: ForkDef?

    public init(id: String, title: String, spine: CardSpine, isDeath: Bool,
                left: CardChoice, right: CardChoice, weapon: WeaponDef? = nil,
                faction: Faction? = nil, isThreat: Bool = false, fork: ForkDef? = nil) {
        self.id = id
        self.title = title
        self.spine = spine
        self.isDeath = isDeath
        self.left = left
        self.right = right
        self.weapon = weapon
        self.faction = faction
        self.isThreat = isThreat
        self.fork = fork
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
    /// Real-time seconds the thumb has rested on the card without dragging — the
    /// press-and-hold gesture for a tier-3 weapon's signature (U11/R2).
    public var holdTime: Double
    /// The signature is armed (held past the threshold); release commits it.
    public var signatureArmed: Bool

    public init(def: CardDef, deathDealt: Bool) {
        self.def = def
        self.offset = 0
        self.rise = 0
        self.tilt = 0
        self.tiltVel = 0
        self.committing = false
        self.dir = 0
        self.deathDealt = deathDealt
        self.holdTime = 0
        self.signatureArmed = false
    }
}
