import Foundation
import Testing
import LegdaySim
@testable import Legday

/// The HUD mod strip exists so a card's effect is visible after it commits.
/// It must show only what changed, or it becomes noise the player stops reading.
struct HudModsTests {
    @MainActor
    @Test func untouchedRunShowsNothing() {
        #expect(HudNode.modsSummary(Mods()) == "")
    }

    @MainActor
    @Test func onlyChangedFieldsAppear() {
        var m = Mods()
        m.footing *= 1.35
        #expect(HudNode.modsSummary(m) == "footing +35%")
    }

    /// A faster attack is a lower cooldown, so the sign must be inverted or the
    /// strip reads a buff as a nerf.
    @MainActor
    @Test func fasterAttackReadsAsPositive() {
        var m = Mods()
        m.attackCooldown *= 0.8
        #expect(HudNode.modsSummary(m) == "atk +25%")
    }

    /// Magnet is the one field whose baseline is not 1.
    @MainActor
    @Test func magnetReportsRelativeToItsOwnBaseline() {
        var m = Mods()
        m.magnet *= 1.6
        #expect(HudNode.modsSummary(m) == "magnet +60%")
    }

    @MainActor
    @Test func fogIsAbsoluteAndSigned() {
        var m = Mods()
        m.fogAdd += 26
        #expect(HudNode.modsSummary(m) == "fog +26")
    }
}
