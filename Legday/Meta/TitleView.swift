import SwiftUI
import LegdaySim

/// The entry point, and now a place the run returns to (R19). It carries the two
/// numbers that outlive a run, so the Reliquary is reachable without dying first.
struct TitleView: View {
    let shards: Int
    let bestFathoms: Double
    let onBegin: () -> Void
    let onReliquary: () -> Void
    var onUnlockAll: () -> Void = {}
    var onReset: () -> Void = {}

    var body: some View {
        ZStack {
            theme.ground.ignoresSafeArea()
            fogWash
            VStack(spacing: 0) {
                Spacer()
                Text("LEGDAY")
                    .font(.custom("Georgia-Bold", size: 44))
                    .tracking(8)
                    .foregroundStyle(theme.gold)
                Text("the climb is the only health")
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.muted)
                    .padding(.top, 10)
                Spacer()
                stats
                Button(action: onBegin) {
                    Text("BEGIN THE CLIMB")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(2)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                        .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 18)
                if shards > 0 || bestFathoms > 0 {
                    Button("THE RELIQUARY", action: onReliquary)
                        .font(.custom("Georgia", size: 12))
                        .tracking(1)
                        .foregroundStyle(theme.muted)
                        .frame(minHeight: 44)
                }
#if DEBUG
                debugRow
#endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var fogWash: some View {
        LinearGradient(colors: [theme.grave.opacity(0.20), .clear],
                       startPoint: .bottom, endPoint: .top)
            .frame(height: 220)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
    }

    @ViewBuilder private var stats: some View {
        VStack(spacing: 5) {
            if bestFathoms > 0 {
                Text("best climb — \(Int(bestFathoms)) fathoms")
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.muted)
            }
            if shards > 0 {
                Text("◈ \(shards)")
                    .font(.custom("Georgia-Bold", size: 16))
                    .foregroundStyle(theme.gold)
            }
        }
    }

    private var theme: DraftTheme { DraftTheme.shared }

#if DEBUG
    private var debugRow: some View {
        HStack(spacing: 8) {
            debugButton("UNLOCK ALL", action: onUnlockAll)
            debugButton("RESET", action: onReset)
        }
        .padding(.top, 4)
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Georgia", size: 12))
                .tracking(1)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.edge))
        }
    }
#endif
}
