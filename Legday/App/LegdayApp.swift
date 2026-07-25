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

/// U1 root: hosts the (currently empty) run scene. U6/U22 replace this with the
/// `GameFlow`-driven meta ↔ run navigation (KTD-6).
struct RootView: View {
    var body: some View {
        SpriteView(scene: Self.scene,
                   debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount])
            .ignoresSafeArea()
    }

    // Created once and retained (never rebuilt inside `body`) per KTD-4/U7.
    private static let scene: RunScene = {
        let scene = RunScene()
        scene.scaleMode = .resizeFill
        return scene
    }()
}
