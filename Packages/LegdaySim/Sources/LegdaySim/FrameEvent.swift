/// A transient, render-only signal emitted by the sim during a tick. These are
/// one-way outputs (bolts, hit flashes, corpses) — they never feed back into
/// sim math, preserving determinism (KTD-3). Gameplay consequences of a kill
/// (fog pushback, mote drops, fog splash) are sim *state*, handled directly,
/// not carried here.
public enum FrameEvent: Equatable, Sendable {
    /// An auto-attack. `weapon` names the form to draw, nil when unarmed.
    case attack(from: Vec2, to: Vec2, weapon: String?)
    /// The hero was shoved (hit flash origin).
    case heroShoved(at: Vec2)
    /// A foe was felled (corpse spawn in U9; fog splash scheduled in U4).
    case foeDown(at: Vec2, elite: Bool)
    /// An essence mote was hoovered into the hero.
    case moteCollected(at: Vec2)
    /// An essence mote was lost to the fog.
    case moteLost(at: Vec2)
    /// The climb entered a new Ascent stage (the render shows a banner).
    case stageEntered(AscentStage)
    /// A cairn took its last hit and fell apart.
    case cairnBroken(at: Vec2)
}
