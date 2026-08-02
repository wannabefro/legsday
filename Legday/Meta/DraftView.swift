import SwiftUI
import LegdaySim

/// U17 draft screen (R9, R10): pick the Twelve, crown the Opener, read the
/// hostility forecast before the run.
struct DraftView: View {
    let cards: [CardDef]
    let collection: [String: Int]
    let catalog: CardCatalog
    let onConfirm: (Draft) -> Void

    @State private var picks: [String] = []
    @State private var opener: String?

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.07, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                forecastBar
                crownHint
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
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(theme.parchment)
        }
        .padding(.top, 8)
    }

    private var crownHint: some View {
        Text("long-press a picked card to crown its Opener")
            .font(.custom("Georgia", size: 11))
            .foregroundStyle(theme.muted)
    }

    /// Hostility forecast (R10): per-faction glyph intensity from the current
    /// picks' faction weighting. A pure function of the draft (U12).
    private var forecastBar: some View {
        let weights = factionWeights()
        let forecast = Hostility.forecast(weights: weights)
        let threatCounts = Dictionary(grouping: forecast, by: { $0.faction })
            .mapValues(\.count)
        return HStack(spacing: 12) {
            ForEach(Faction.allCases, id: \.self) { faction in
                VStack(spacing: 2) {
                    Text(glyph(faction))
                        .font(.system(size: 16))
                        .foregroundStyle(theme.color(faction))
                        .opacity(0.9)
                    Text("\(threatCounts[faction] ?? 0)")
                        .font(.custom("Georgia", size: 11))
                        .foregroundStyle(theme.parchment)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(cards, id: \.id) { card in
                cardCell(card)
            }
        }
        .padding(.bottom, 8)
    }

    private func cardCell(_ card: CardDef) -> some View {
        let owned = collection[card.id] ?? 0
        let picked = picks.filter { $0 == card.id }.count
        let isOpener = opener == card.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(card.title)
                    .font(.custom("Georgia-Bold", size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.parchment)
                Spacer()
                if isOpener {
                    Text("♛")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.gold)
                }
            }
            HStack {
                Text(spineName(card))
                    .font(.custom("Georgia", size: 9))
                    .foregroundStyle(theme.color(card.faction))
                Spacer()
                Text(copiesText(picked: picked, owned: owned))
                    .font(.custom("Georgia", size: 9))
                    .foregroundStyle(picked > 0 ? theme.gold : theme.muted)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(picked > 0 ? theme.selected : theme.panel,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isOpener ? theme.gold : .clear, lineWidth: 1.5)
        )
        .opacity(owned == 0 ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture { toggle(card.id, owned: owned, picked: picked) }
        .onLongPressGesture(minimumDuration: 0.5) {
            if picked > 0 { opener = (opener == card.id ? nil : card.id) }
        }
    }

    /// Tap cycles a card 0 → 1 → 2 (the copy cap) → 0; removal clears all.
    private func toggle(_ id: String, owned: Int, picked: Int) {
        let cap = min(Draft.maxCopies, owned)
        if picked >= cap {
            picks.removeAll { $0 == id }
            if opener == id { opener = nil }
        } else if picks.count < Draft.maxCards {
            picks.append(id)
        }
    }

    private func factionWeights() -> [Faction: Int] {
        var w: [Faction: Int] = [:]
        for id in picks {
            if let card = catalog.card(id: id), let f = card.faction {
                w[f, default: 0] += 1
            }
        }
        return w
    }

    private var footer: some View {
        Button {
            onConfirm(Draft(picks: picks, opener: opener))
        } label: {
            Text(picks.count == Draft.maxCards && opener != nil
                 ? "BEGIN THE CLIMB"
                 : "CROWN \(Draft.maxCards - picks.count) MORE, THEN YOUR OPENER")
                .font(.custom("Georgia-Bold", size: 15))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(picks.count != Draft.maxCards || opener == nil)
        .opacity(picks.count == Draft.maxCards && opener != nil ? 1 : 0.5)
        .padding(.bottom, 8)
    }

    private func copiesText(picked: Int, owned: Int) -> String {
        picked > 0 ? "\(picked)/\(min(Draft.maxCopies, owned))" : "owned \(owned)"
    }

    private func spineName(_ card: CardDef) -> String {
        card.faction?.rawValue ?? card.spine.rawValue
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

/// Draft palette — the graybox gothic look in SwiftUI (U22/U24 refines).
private struct DraftTheme {
    static let shared = DraftTheme()
    let gold = Color(red: 0.79, green: 0.60, blue: 0.18)
    let parchment = Color(red: 0.90, green: 0.85, blue: 0.74)
    let muted = Color(red: 0.55, green: 0.49, blue: 0.40)
    let ink = Color(red: 0.14, green: 0.11, blue: 0.07)
    let panel = Color(red: 0.16, green: 0.13, blue: 0.11)
    let selected = Color(red: 0.22, green: 0.17, blue: 0.12)

    func color(_ faction: Faction?) -> Color {
        switch faction {
        case .church: return gold
        case .plague: return Color(red: 0.56, green: 0.63, blue: 0.23)
        case .grave: return Color(red: 0.54, green: 0.44, blue: 0.70)
        case .wild: return Color(red: 0.75, green: 0.39, blue: 0.19)
        case .none: return muted
        }
    }
}
