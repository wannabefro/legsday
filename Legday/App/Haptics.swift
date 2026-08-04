import UIKit

/// One thumb, on glass. Every commitment the player makes gets a tap back.
@MainActor
enum Haptics {
    /// A card side taken, a relic pulled — the player's choice landing.
    static func commit() { impact(.medium) }
    /// A pick toggled, a copy added.
    static func select() { impact(.light) }
    /// A shove landing, the fog taking you.
    static func blow() { impact(.heavy) }
    /// A new relic, a duel won.
    static func triumph() { notify(.success) }
    /// A tap that could not do anything — an unrecovered relic, a locked action.
    static func refused() { notify(.warning) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
