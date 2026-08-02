import SwiftUI
import SpriteKit
import LegdaySim

@main
struct LegdayApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// U1 root, now GameFlow-driven (KTD-6/U17): draft screen (when unlocked) or
/// the run. U22 extends this with title/meta navigation.
struct RootView: View {
    @State private var flow = GameFlow()

    var body: some View {
        Group {
            switch flow.stage {
            case .draft:
                DraftView(cards: flow.draftableCards,
                          collection: flow.collection,
                          catalog: flow.catalog,
                          onConfirm: { flow.confirm($0) })
            case .run(let draft):
                SpriteView(scene: flow.makeScene(for: draft, seed: 0x1E6DA9),
                           debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount])
                    .ignoresSafeArea()
            }
        }
    }
}
