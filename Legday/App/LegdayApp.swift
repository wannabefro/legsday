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

/// Root navigation (KTD-6/U17/U22): stages cross-fade rather than cut, and a
/// run can pause.
struct RootView: View {
    @State private var flow = GameFlow()

    var body: some View {
        ZStack {
            DraftTheme.shared.ground.ignoresSafeArea()
            stageView
                .transition(.opacity)
                .id(stageKey)
        }
        .animation(.easeInOut(duration: 0.22), value: stageKey)
    }

    @ViewBuilder private var stageView: some View {
        switch flow.stage {
        case .title:
            TitleView(shards: flow.store.shards,
                      bestFathoms: flow.store.bestFathoms,
                      onBegin: { Haptics.select(); flow.begin() },
                      onReliquary: { Haptics.select(); flow.openReliquary() },
                      onUnlockAll: { flow.debugUnlockAll() },
                      onReset: { flow.debugResetProgress() })
        case .draft:
            DraftView(cards: flow.draftableCards,
                      collection: flow.store.collection,
                      catalog: flow.catalog,
                      onConfirm: { flow.confirm($0) },
                      onReliquary: { flow.openReliquary() })
        case .run(let draft):
            RunContainer(flow: flow, draft: draft)
        case .results(let result):
            ResultsView(result: result,
                        bestFathoms: flow.store.bestFathoms,
                        onNextRun: { flow.toReliquary() },
                        onTitle: { flow.toTitle() })
        case .reliquary:
            ReliquaryView(catalog: flow.catalog,
                          owned: flow.store.collection,
                          shards: flow.store.shards,
                          lastPull: flow.lastPull,
                          revealShown: flow.revealShown,
                          pullsToGuarantee: flow.pullsToGuarantee,
                          onPull: { flow.pull() },
                          onDone: { flow.nextDraft() },
                          onTitle: { flow.toTitle() })
        }
    }

    /// Identity for the cross-fade. The run keeps one key for its whole life so
    /// a pause never rebuilds the scene.
    private var stageKey: String {
        switch flow.stage {
        case .title: return "title"
        case .draft: return "draft"
        case .run: return "run-\(flow.runSeed)"
        case .results: return "results"
        case .reliquary: return "reliquary"
        }
    }
}

/// The run, its pause control, and the paused overlay.
struct RunContainer: View {
    let flow: GameFlow
    let draft: Draft
    /// Built once. A scene created inside `body` is rebuilt on every re-render.
    @State private var scene: RunScene

    init(flow: GameFlow, draft: Draft) {
        self.flow = flow
        self.draft = draft
        _scene = State(initialValue: flow.makeScene(for: draft, seed: flow.runSeed))
    }

    /// `-showfps` puts the frame rate and the node count on screen.
    private static let debugOptions: SpriteView.DebugOptions =
        ProcessInfo.processInfo.arguments.contains("-showfps")
            ? [.showsFPS, .showsNodeCount, .showsDrawCount] : []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene, debugOptions: Self.debugOptions)
                .ignoresSafeArea()
            pauseButton
            if flow.paused { pausedOverlay }
        }
        .onChange(of: flow.paused) { _, paused in scene.isPaused = paused }
    }

    private var pauseButton: some View {
        Button {
            Haptics.select()
            flow.paused = true
        } label: {
            Text("❙❙")
                .font(.system(size: 15))
                .foregroundStyle(theme.mutedHi)
                .frame(width: 44, height: 44)
                .background(theme.ground.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.edge))
        }
        .padding(.trailing, 16)
        .opacity(flow.paused ? 0 : 1)
    }

    private var pausedOverlay: some View {
        ZStack {
            theme.ground.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(.custom("Georgia-Bold", size: 28))
                    .tracking(4)
                    .foregroundStyle(theme.gold)
                Text("the fog waits")
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.muted)
                    .padding(.bottom, 10)
                Button {
                    Haptics.select()
                    flow.paused = false
                } label: {
                    Text("RESUME THE CLIMB")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(2)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
                }
                Button("ABANDON — NO SHARDS BANKED") {
                    Haptics.blow()
                    flow.abandonRun()
                }
                .font(.custom("Georgia", size: 12))
                .tracking(1)
                .foregroundStyle(theme.muted)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private var theme: DraftTheme { DraftTheme.shared }
}
