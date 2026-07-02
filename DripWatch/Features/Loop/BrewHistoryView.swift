import SwiftUI
import SwiftData

/// The full experimentation trail: every past brew with its complete recipe *and* tasting
/// notes, newest first. Between consecutive brews we show the computed param delta — the
/// notebook's arrow made legible — as an annotation above the always-shown absolute recipe.
struct BrewHistoryView: View {
    let brews: [Brew]   // newest first
    var onEdit: (Brew) -> Void = { _ in }
    var onDelete: (Brew) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(brews.enumerated()), id: \.element.id) { index, brew in
                // The previous brew chronologically is the next one in this newest-first list.
                let previous = index + 1 < brews.count ? brews[index + 1] : nil
                BrewRow(brew: brew, previous: previous, onEdit: { onEdit(brew) }, onDelete: { onDelete(brew) })
                    .contextMenu {
                        Button { onEdit(brew) } label: { Label("Edit brew", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(brew) } label: {
                            Label("Delete brew", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

/// One brew in the log.
struct BrewRow: View {
    let brew: Brew
    var previous: Brew?
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    private var diff: [String] {
        guard let previous else { return [] }
        return BrewDiff.changes(from: previous.recipe, to: brew.recipe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(brew.brewedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let rating = brew.taste.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<rating, id: \.self) { _ in
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.crema)
                        }
                    }
                    .accessibilityLabel("\(rating) star rating")
                }
                Menu {
                    Button { onEdit() } label: { Label("Edit brew", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete brew", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").imageScale(.medium).foregroundStyle(.secondary).hitTarget(36)
                }
                .accessibilityLabel("Brew options")
            }

            // Change annotation vs. the previous brew (never replaces the absolute recipe below).
            if !diff.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(diff, id: \.self) { Chip(text: $0, symbol: "arrow.right", tint: Theme.accent) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Changes from previous brew: \(diff.joined(separator: ", "))")
            }

            // The full absolute recipe.
            RecipeReadout(recipe: brew.recipe)

            // Tasting notes.
            if !brew.taste.isEmpty {
                tasteSummary
            }

            // The plan that came out of this brew.
            if let next = brew.nextRecipeDraft {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.caption).foregroundStyle(Theme.accent)
                    Text("Next: \(next.summaryLine)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .dripCard()
    }

    @ViewBuilder private var tasteSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !brew.taste.positives.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(brew.taste.positives, id: \.self) { Chip(text: $0, symbol: "plus", tint: Theme.sage) }
                }
            }
            if !brew.taste.negatives.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(brew.taste.negatives, id: \.self) { Chip(text: $0, symbol: "minus", tint: Theme.clay) }
                }
            }
            if !brew.taste.balance.isEmpty {
                TasteBalanceView(balance: brew.taste.balance)
            }
            if let note = brew.taste.note, !note.isEmpty {
                Text("“\(note)”").font(.footnote.italic()).foregroundStyle(.secondary)
            }
        }
    }
}

/// A read-only "shape of the brew": each timed pour drawn as a segment on a 0→total bar, so the
/// rhythm (pours vs. the drawdown gaps between them) is legible at a glance.
struct PourTimeline: View {
    let pours: [Pour]   // only pours with both start and end
    let totalSec: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.crema.opacity(0.6)).frame(height: 6)
                    if totalSec > 0 {
                        ForEach(pours) { p in
                            if let s = p.startSec, let e = p.endSec {
                                Capsule().fill(Theme.accent)
                                    .frame(width: max(3, CGFloat(e - s) / CGFloat(totalSec) * w), height: 6)
                                    .offset(x: CGFloat(s) / CGFloat(totalSec) * w)
                            }
                        }
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 6)
            HStack {
                Text("0:00").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(timeText(totalSec)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pour timeline: " + pours.compactMap { p in
            guard let s = p.startSec, let e = p.endSec else { return nil }
            return "pour \(p.order), \(timeText(s)) to \(timeText(e))"
        }.joined(separator: ", "))
    }
}

/// A compact, complete readout of a recipe's absolute values.
struct RecipeReadout: View {
    let recipe: Recipe

    var body: some View {
        WrapLayout(spacing: 8, lineSpacing: 8) {
            if let g = recipe.grind { pill("dial.medium", g.display) }
            if let t = recipe.waterTempC { pill("thermometer.medium", "\(t)°C") }
            if let d = recipe.doseGrams { pill("scalemass", "\(gramText(d))g") }
            if let y = recipe.yieldGrams { pill("cup.and.saucer", "→ \(gramText(y))g") }
            if let sr = recipe.shotRatio { pill("divide", "1:\(ratioText((sr * 10).rounded() / 10))") }
            if let r = recipe.ratio { pill("divide", "1:\(ratioText(r))") }
            if let w = recipe.effectiveWaterGrams, recipe.doseGrams != nil { pill("drop.fill", "\(gramText(w))g") }
            if let p = recipe.pourCount { pill("drop", "\(p) pour\(p == 1 ? "" : "s")") }
            if let st = recipe.shotTimeSec { pill("timer", "\(st)s shot") }
            if let pi = recipe.preInfusionSec { pill("drop.circle", "PI \(pi)s") }
            if let sw = recipe.surfWaitSec { pill("clock", "surf \(sw)s") }
            if let sm = recipe.steamModeSec { pill("flame", "steam \(sm)s") }
            if let b = recipe.bloomTimeSec { pill("timer", "bloom \(timeText(b))") }
            if let tdd = recipe.totalDrawdownSec { pill("hourglass", "TDD \(timeText(tdd))") }
        }
        .overlay(alignment: .topLeading) {
            if recipe.isEmpty {
                Text("No parameters recorded").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)

        if recipe.hasPourBreakdown {
            let sorted = recipe.pours.sorted { $0.order < $1.order }
            let steps = sorted
                .compactMap { p in p.toGrams.map { "\(gramText($0))g" } }
                .joined(separator: " → ")
            if !steps.isEmpty {
                Text(steps).font(.param(.caption)).foregroundStyle(.secondary)
            }
            // The "shape of the brew": each pour as a segment on a 0→total timeline.
            let timed = sorted.filter { $0.startSec != nil && $0.endSec != nil }
            if !timed.isEmpty {
                let total = max(recipe.totalDrawdownSec ?? 0, timed.compactMap(\.endSec).max() ?? 0)
                PourTimeline(pours: timed, totalSec: total).padding(.top, 2)
            }
        }
        if let notes = recipe.notes, !notes.isEmpty {
            Text("“\(notes)”").font(.caption.italic()).foregroundStyle(.secondary)
        }
    }

    private func pill(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).imageScale(.small).foregroundStyle(.secondary)
            Text(text).font(.param(.subheadline, weight: .medium))
        }
        .foregroundStyle(Color(.label))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.crema.opacity(0.5), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.crema, lineWidth: 0.5))
    }
}
