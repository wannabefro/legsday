import SwiftUI
import LegdaySim

/// U20 obituary card: one shape for every ending (R18) — distance, felled,
/// cards drawn, shards, best distance.
struct ResultsView: View {
    let result: RunResult
    let bestFathoms: Double
    let onNextRun: () -> Void
    let onTitle: () -> Void

    var body: some View {
        ZStack {
            theme.ground.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                Text(endingTitle)
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundStyle(endingGold)
                    .multilineTextAlignment(.center)
                Text(endingSubtitle)
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.muted)
                obituaryCard
                bestLine
                Spacer()
                // The label names where it goes; it opened the Reliquary while
                // calling itself a new run.
                Button {
                    Haptics.select()
                    onNextRun()
                } label: {
                    Text("SPEND YOUR SHARDS")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(2)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
                }
                Button("BACK TO THE TITLE") { Haptics.select(); onTitle() }
                    .font(.custom("Georgia", size: 12))
                    .tracking(1)
                    .foregroundStyle(theme.muted)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .onAppear {
            if result.ending == .duelWin { Haptics.triumph() } else { Haptics.blow() }
        }
    }

    private var obituaryCard: some View {
        VStack(spacing: 10) {
            row("distance", "\(Int(result.fathoms)) fathoms")
            row("felled", "\(result.felled)")
            row("cards drawn", "\(result.cardsDrawn)")
            row("shards", "◈ \(result.shards)", gold: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.gold.opacity(0.4), lineWidth: 1)
        )
    }

    private func row(_ label: String, _ value: String, gold: Bool = false) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.custom("Georgia", size: 12))
                .tracking(1.2)
                .foregroundStyle(theme.muted)
            Spacer()
            Text(value)
                .font(.custom("Georgia-Bold", size: 16))
                .monospacedDigit()
                .foregroundStyle(gold ? theme.gold : theme.parchment)
        }
    }

    private var bestLine: some View {
        Text(bestFathoms > 0
             ? "best climb: \(Int(bestFathoms)) fathoms"
             : "first climb")
            .font(.custom("Georgia", size: 12))
            .foregroundStyle(theme.muted)
    }

    private var endingTitle: String {
        switch result.ending {
        case .duelWin: return "GLORY"
        case .duelLoss: return "HE TOOK YOU"
        case .caught: return "THE FOG HAS YOU"
        }
    }

    private var endingSubtitle: String {
        switch result.ending {
        case .duelWin: return "the Reaper falls — shards ×3"
        case .duelLoss: return "the duel was lost"
        case .caught: return "the road ends where it began"
        }
    }

    private var endingGold: Color {
        result.ending == .duelWin ? theme.gold : theme.parchment
    }

    private var theme: DraftTheme { DraftTheme.shared }
}
