import SwiftUI
import LegdaySim

/// The Reliquary: shards buy pulls (R19); pity guarantees a new relic in 10.
/// One column, so a tile can hold the relic, what it does and what a copy buys.
struct ReliquaryView: View {
    let catalog: CardCatalog
    let owned: [String: Int]
    let shards: Int
    let lastPull: String?
    let revealShown: Bool
    let pullsToGuarantee: Int
    let onPull: () -> String
    let onDone: () -> Void
    let onTitle: () -> Void

    private var pool: [CardDef] { catalog.player + catalog.weapons }
    private var recovered: Int { pool.filter { (owned[$0.id] ?? 0) > 0 }.count }
    private var totalCopies: Int { owned.values.reduce(0, +) }
    private var draftUnlocked: Bool { Draft.isUnlocked(collection: owned) }
    private var canPull: Bool { shards >= Collection.pullCost }

    var body: some View {
        ZStack {
            theme.ground.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                ScrollView { vault }
                footer
            }
            .padding(.horizontal, 16)
            if revealShown, let id = lastPull {
                revealBanner(id).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: revealShown)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("THE RELIQUARY")
                    .font(.custom("Georgia-Bold", size: 20))
                    .foregroundStyle(theme.gold)
                Spacer()
                Text("◈ \(shards)")
                    .font(.custom("Georgia-Bold", size: 16))
                    .monospacedDigit()
                    .foregroundStyle(canPull ? theme.gold : theme.muted)
            }
            Text("\(recovered)/\(pool.count) relics recovered")
                .font(.custom("Georgia", size: 12))
                .foregroundStyle(theme.muted)
            if !draftUnlocked {
                Text("\(totalCopies)/\(Draft.collectionUnlock) cards — the draft opens at \(Draft.collectionUnlock)")
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.gold)
                ProgressBar(fraction: Double(totalCopies) / Double(Draft.collectionUnlock))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, 8)
    }

    private var vault: some View {
        LazyVStack(spacing: 8) {
            ForEach(pool, id: \.id) { card in tile(card) }
        }
        .padding(.bottom, 8)
    }

    private func tile(_ card: CardDef) -> some View {
        let copies = owned[card.id] ?? 0
        return HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.color(card.faction))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(.custom("Georgia-Bold", size: 16))
                    .foregroundStyle(theme.parchment)
                Text(ReliquaryView.effectSummary(card))
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(theme.muted)
                Text(ReliquaryView.copyNote(card: card, copies: copies))
                    .font(.custom("Georgia", size: 12))
                    .foregroundStyle(copies > 0 ? theme.gold : theme.mutedLo)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 6))
        .opacity(copies > 0 ? 1 : 0.5)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                guard canPull else { Haptics.refused(); return }
                Haptics.commit()
                _ = onPull()
            } label: {
                HStack {
                    Text("PULL A RELIC").tracking(2)
                    Spacer()
                    Text("◈ \(Collection.pullCost)").monospacedDigit()
                }
                .font(.custom("Georgia-Bold", size: 16))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .padding(.vertical, 6)
                .background(theme.gold, in: RoundedRectangle(cornerRadius: 8))
            }
            .opacity(canPull ? 1 : 0.45)

            Text(pullsToGuarantee <= 1
                 ? "the next pull is a new relic, guaranteed"
                 : "a new relic guaranteed within \(pullsToGuarantee) pulls")
                .font(.custom("Georgia", size: 12))
                .foregroundStyle(pullsToGuarantee <= 1 ? theme.gold : theme.muted)

            HStack(spacing: 16) {
                Button(draftUnlocked ? "TO THE DRAFT" : "BEGIN THE CLIMB") {
                    Haptics.select(); onDone()
                }
                Button("BACK TO THE TITLE") { Haptics.select(); onTitle() }
            }
            .font(.custom("Georgia", size: 12))
            .tracking(1)
            .foregroundStyle(theme.muted)
            .frame(minHeight: 44)
        }
        .padding(.bottom, 8)
    }

    /// Reveal what a pull yielded: a new relic, or a copy of an owned one.
    private func revealBanner(_ id: String) -> some View {
        let isNew = (owned[id] ?? 0) == 1
        let card = catalog.card(id: id)
        return VStack(spacing: 4) {
            Text(isNew ? "NEW RELIC" : "ANOTHER COPY")
                .font(.custom("Georgia-Bold", size: 12))
                .tracking(2)
                .foregroundStyle(theme.ink)
            Text(card?.title ?? id)
                .font(.custom("Georgia-Bold", size: 20))
                .foregroundStyle(theme.ink)
            Text(card.map(ReliquaryView.effectSummary) ?? "")
                .font(.custom("Georgia", size: 12))
                .foregroundStyle(theme.ink.opacity(0.75))
            Text(ReliquaryView.copyNote(card: card, copies: owned[id] ?? 0))
                .font(.custom("Georgia", size: 12))
                .foregroundStyle(theme.ink.opacity(0.75))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isNew ? theme.gold : theme.raised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(isNew ? theme.gold : theme.edge, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 110)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .zIndex(1)
    }

    /// The relic's two sides, so the vault reads as choices and not as names.
    static func effectSummary(_ card: CardDef) -> String {
        if card.weapon != nil { return "a weapon — its form is chosen in the run" }
        return "\(card.left.label) / \(card.right.label)"
    }

    /// A copy stacks in the deck; only a weapon's third copy unlocks anything.
    static func copyNote(card: CardDef?, copies: Int) -> String {
        guard copies > 0 else { return "unrecovered" }
        guard let card, card.weapon != nil else { return "×\(copies) in your deck" }
        if copies >= Collection.maxTier { return "×\(copies) — signature unlocked" }
        return "×\(copies) — signature at \(Collection.maxTier)"
    }

    private var theme: DraftTheme { DraftTheme.shared }
}

struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DraftTheme.shared.gold.opacity(0.16))
                Capsule().fill(DraftTheme.shared.gold)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 4)
    }
}
