import SpriteKit
import LegdaySim

/// What a stage is made of. `AscentStage` carries the rules; this carries the
/// look, and it stays in the app because the sim may not name a colour.
struct ZoneLook {
    enum Material: String {
        case rubble, briar, bone, masonry, fog
        case root, tile, ash

        /// The drawing this material is built from. Several materials share one.
        var sprite: String {
            switch self {
            case .rubble: return "ground-slab"
            case .briar: return "tree-canopy"
            case .bone: return "bone-pile"
            case .masonry, .tile: return "ashlar"
            case .fog: return "fog-tendril"
            case .root: return "floor-roots"
            case .ash: return "floor-ash"
            }
        }
    }

    let wall: Material
    let floor: Material
    let rock: Int
    /// Courses of wall drawn back from the lip, so a cliff has mass.
    let depth: Int

    static let byStageID: [String: ZoneLook] = [
        "low_road":  ZoneLook(wall: .rubble,  floor: .rubble, rock: 0x3A2A1C, depth: 2),
        "orchard":   ZoneLook(wall: .briar,   floor: .root,   rock: 0x2C3018, depth: 2),
        "ossuary":   ZoneLook(wall: .bone,    floor: .bone,   rock: 0x2E2838, depth: 2),
        "spire":     ZoneLook(wall: .masonry, floor: .tile,   rock: 0x3E301A, depth: 3),
        "reckoning": ZoneLook(wall: .fog,     floor: .ash,    rock: 0x1A1614, depth: 2),
    ]

    static func of(_ stage: AscentStage) -> ZoneLook {
        byStageID[stage.id] ?? byStageID["low_road"]!
    }
}
