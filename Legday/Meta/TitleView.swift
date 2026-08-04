import SwiftUI
import LegdaySim

/// U22 title screen: the meta loop's entry point (R19). Placeholder styling.
struct TitleView: View {
    let shards: Int
    let onBegin: () -> Void
    var onUnlockAll: () -> Void = {}
    var onReset: () -> Void = {}
    var onReliquary: () -> Void = {}

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.07, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 12) {
                Spacer()
                Text("LEGDAY")
                    .font(.custom("Georgia-Bold", size: 44))
                    .tracking(8)
                    .foregroundStyle(theme.gold)
                Text("the climb is the only health")
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(theme.muted)
                Spacer()
                if shards > 0 {
                    Text("◈ \(shards)")
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(theme.gold)
                }
                Button {
                    onBegin()
                } label: {
                    Text("BEGIN")
                        .font(.custom("Georgia-Bold", size: 16))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.bottom, 24)
#if DEBUG
                debugRow.padding(.bottom, 16)
#endif
            }
            .padding(.horizontal, 32)
        }
    }

    private var theme: DraftTheme { DraftTheme.shared }

#if DEBUG
    private var debugRow: some View {
        HStack(spacing: 8) {
            debugButton("UNLOCK ALL", action: onUnlockAll)
            debugButton("RELIQUARY", action: onReliquary)
            debugButton("RESET", action: onReset)
        }
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Georgia", size: 11))
                .tracking(1)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.muted.opacity(0.4)))
        }
    }
#endif
}
