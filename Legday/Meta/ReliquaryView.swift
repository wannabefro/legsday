import SwiftUI
import LegdaySim

/// U21 Reliquary: shards buy pulls (R19); pity guarantees a new card in 10.
struct ReliquaryView: View {
    let catalog: CardCatalog
    let owned: [String: Int]
    let shards: Int
    let onPull: () -> Void
    let onDone: () -> Void

    private var pool: [CardDef] { catalog.player + catalog.weapons }
    private var unownedCount: Int {
        pool.filter { (owned[$0.id] ?? 0) == 0 }.count
    }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.07, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 18) {
                header
                vault
                footer
            }
            .padding(.horizontal, 24)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("THE RELIQUARY")
                .font(.custom("Georgia-Bold", size: 22))
                .foregroundStyle(theme.gold)
            Text("\(pool.count - unownedCount)/\(pool.count) relics recovered")
                .font(.custom("Georgia", size: 13))
                .foregroundStyle(theme.muted)
        }
        .padding(.top, 24)
    }

    private var vault: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(pool, id: \.id) { card in
                    let copies = owned[card.id] ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.title)
                            .font(.custom("Georgia-Bold", size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(copies > 0 ? theme.parchment : theme.muted)
                        Text(copies > 0 ? "×\(copies)" : "unrecovered")
                            .font(.custom("Georgia", size: 9))
                            .foregroundStyle(copies > 0 ? theme.gold : theme.muted)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(theme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .opacity(copies > 0 ? 1 : 0.5)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                onPull()
            } label: {
                HStack {
                    Text("PULL A RELIC")
                    Spacer()
                    Text("◈ \(Collection.pullCost)")
                        .font(.custom("Georgia-Bold", size: 13))
                }
                .font(.custom("Georgia-Bold", size: 15))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
            }
            .disabled(shards < Collection.pullCost)
            .opacity(shards >= Collection.pullCost ? 1 : 0.5)

            Button("TO THE DRAFT") {
                onDone()
            }
            .font(.custom("Georgia", size: 13))
            .foregroundStyle(theme.muted)
        }
        .padding(.bottom, 8)
    }

    private var theme: DraftTheme { DraftTheme.shared }
}
