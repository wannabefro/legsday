import SwiftUI
import LegdaySim

/// Draft screen (R9, R10): pick the Twelve, crown the Opener, read the hostility
/// forecast. One column, because a column that cannot hold 12pt type is not one.
struct DraftView: View {
    let cards: [CardDef]
    let collection: [String: Int]
    let catalog: CardCatalog
    let onConfirm: (Draft) -> Void
    let onReliquary: () -> Void

    @State private var picks: [String] = []
    @State private var opener: String?

    var body: some View {
        ZStack {
            theme.ground.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                forecastBar
                ScrollView { grid }
                footer
            }
            .padding(.horizontal, 16)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DRAFT THE TWELVE")
                .font(.custom("Georgia-Bold", size: 20))
                .foregroundStyle(theme.gold)
            Spacer()
            Text("\(picks.count)/\(Draft.maxCards)")
                .font(.custom("Georgia", size: 16))
                .monospacedDigit()
                .foregroundStyle(theme.parchment)
        }
        .padding(.top, 8)
    }

    /// Hostility forecast (R10): the rival factions the picks have provoked.
    /// Unlabelled glyphs read as decoration, so each one is named.
    private var forecastBar: some View {
        let forecast = Hostility.forecast(weights: factionWeights())
        let counts = Dictionary(grouping: forecast, by: { $0.faction }).mapValues(\.count)
        return VStack(spacing: 8) {
            Text("THREATS YOU HAVE INVITED")
                .font(.custom("Georgia", size: 12))
                .tracking(1.5)
                .foregroundStyle(theme.muted)
            HStack(spacing: 0) {
                ForEach(Faction.allCases, id: \.self) { faction in
                    VStack(spacing: 2) {
                        Text(glyph(faction))
                            .font(.system(size: 19))
                            .foregroundStyle(theme.color(faction))
                        Text("\(counts[faction] ?? 0)")
                            .font(.custom("Georgia-Bold", size: 16))
                            .monospacedDigit()
                            .foregroundStyle(theme.parchment)
                        Text(faction.rawValue.uppercased())
                            .font(.custom("Georgia", size: 12))
                            .tracking(0.8)
                            .foregroundStyle(theme.mutedLo)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }

    private var grid: some View {
        LazyVStack(spacing: 8) {
            ForEach(cards, id: \.id) { card in cardCell(card) }
        }
        .padding(.bottom, 8)
    }

    private func cardCell(_ card: CardDef) -> some View {
        let owned = collection[card.id] ?? 0
        let picked = picks.filter { $0 == card.id }.count
        let isOpener = opener == card.id
        let cap = min(Draft.maxCopies, owned)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(card.title)
                    .font(.custom("Georgia-Bold", size: 16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(theme.parchment)
                Spacer(minLength: 0)
                if isOpener {
                    Text("♛")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.gold)
                }
            }
            Text(ReliquaryView.effectSummary(card))
                .font(.custom("Georgia", size: 12))
                .lineLimit(2)
                .foregroundStyle(theme.muted)
            HStack(spacing: 8) {
                Text(factionName(card))
                    .font(.custom("Georgia", size: 12))
                    .tracking(1)
                    .foregroundStyle(theme.color(card.faction))
                Spacer(minLength: 0)
                if owned == 0 {
                    Text("RECOVER ◈\(Collection.pullCost)")
                        .font(.custom("Georgia", size: 12))
                        .tracking(1)
                        .foregroundStyle(theme.gold)
                } else {
                    copyPips(picked: picked, cap: cap)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(picked > 0 ? theme.raised : theme.panel,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isOpener ? theme.gold : .clear, lineWidth: 1.5)
        )
        .opacity(owned == 0 ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture { tap(card.id, owned: owned, picked: picked) }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard picked > 0 else { return }
            opener = (opener == card.id ? nil : card.id)
            Haptics.commit()
        }
    }

    /// Copies as pips, so a second tap has a visible result and the cap is a
    /// shape rather than a rule the player has to discover.
    private func copyPips(picked: Int, cap: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<max(cap, 1), id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < picked ? theme.gold : .clear)
                    .frame(width: 8, height: 8)
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .stroke(i < picked ? theme.gold : theme.mutedLo))
            }
        }
    }

    /// Tap cycles 0 → 1 → 2 → 0. An unowned relic points at the Reliquary
    /// rather than absorbing the tap and doing nothing.
    private func tap(_ id: String, owned: Int, picked: Int) {
        guard owned > 0 else {
            Haptics.refused()
            onReliquary()
            return
        }
        let cap = min(Draft.maxCopies, owned)
        if picked >= cap {
            picks.removeAll { $0 == id }
            if opener == id { opener = nil }
        } else if picks.count < Draft.maxCards {
            picks.append(id)
        } else {
            Haptics.refused()
            return
        }
        Haptics.select()
    }

    private func factionWeights() -> [Faction: Int] {
        var w: [Faction: Int] = [:]
        for id in picks {
            if let card = catalog.card(id: id), let f = card.faction { w[f, default: 0] += 1 }
        }
        return w
    }

    private var footer: some View {
        let exhausted = picks.count == maxPickable
        let ready = (picks.count == Draft.maxCards || exhausted) && opener != nil
        return Button {
            guard ready else { Haptics.refused(); return }
            Haptics.commit()
            onConfirm(Draft(picks: picks, opener: opener))
        } label: {
            Text(footerLabel(ready: ready))
                .font(.custom("Georgia-Bold", size: 16))
                .tracking(2)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 6)
                .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
        }
        .opacity(ready ? 1 : 0.45)
        .padding(.bottom, 8)
    }

    /// A disabled label names what unblocks it, not that it is disabled.
    private func footerLabel(ready: Bool) -> String {
        if ready { return "BEGIN THE CLIMB" }
        if picks.isEmpty { return "PICK YOUR CARDS" }
        if opener == nil { return "HOLD A CARD TO CROWN YOUR OPENER" }
        return "PICK \(Draft.maxCards - picks.count) MORE"
    }

    private var maxPickable: Int {
        cards.reduce(0) { $0 + min(Draft.maxCopies, collection[$1.id] ?? 0) }
    }

    private func factionName(_ card: CardDef) -> String {
        (card.faction?.rawValue ?? card.spine.rawValue).uppercased()
    }

    private func glyph(_ faction: Faction) -> String {
        switch faction {
        case .church: return "✠"
        case .plague: return "☣"
        case .grave: return "☥"
        case .wild: return "❦"
        }
    }

    private var theme: DraftTheme { DraftTheme.shared }
}

/// The settled palette. The code previously held two sets of values for the
/// same roles — the card owns parchment, the scene owns ground, and the three
/// accidental greys became one scale.
struct DraftTheme {
    static let shared = DraftTheme()
    let ground = Color(red: 0.06, green: 0.05, blue: 0.04)
    let panel = Color(red: 0.11, green: 0.09, blue: 0.08)
    let raised = Color(red: 0.16, green: 0.13, blue: 0.10)
    let edge = Color(red: 0.23, green: 0.18, blue: 0.13)
    let parchment = Color(red: 0.91, green: 0.86, blue: 0.74)
    let ink = Color(red: 0.14, green: 0.11, blue: 0.07)
    let mutedHi = Color(red: 0.69, green: 0.63, blue: 0.49)
    let muted = Color(red: 0.55, green: 0.48, blue: 0.34)
    let mutedLo = Color(red: 0.42, green: 0.35, blue: 0.24)
    let gold = Color(red: 0.79, green: 0.60, blue: 0.18)
    let rust = Color(red: 0.75, green: 0.39, blue: 0.19)
    let grave = Color(red: 0.54, green: 0.44, blue: 0.70)
    let plague = Color(red: 0.56, green: 0.63, blue: 0.23)
    var selected: Color { raised }

    func color(_ faction: Faction?) -> Color {
        switch faction {
        case .church: return gold
        case .plague: return plague
        case .grave: return grave
        case .wild: return rust
        case .none: return mutedLo
        }
    }
}
