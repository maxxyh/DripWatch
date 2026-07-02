import SwiftUI

/// THE one reusable recipe editor. Used identically for logging a brew and for drafting the
/// next one. "Structured but mostly optional, progressive": the simple line is what you reach
/// for every day; the per-pour breakdown and notes stay folded away until you want them.
///
/// Numbers are typed directly (tap the value and enter it) — no +/- steppers to jab at.
struct RecipeEditor: View {
    @Binding var recipe: Recipe
    var method: BrewMethod = .pourover
    @State private var showBreakdown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GrindPicker(grind: $recipe.grind)

            Divider().overlay(Theme.crema.opacity(0.3))

            if method == .espresso {
                espressoFields
            } else {
                pouroverFields
            }
        }
    }

    // MARK: Pourover

    @ViewBuilder private var pouroverFields: some View {
        NumberField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 60...100, systemImage: "thermometer.medium")
        DecimalField(label: "Dose", unit: "g", value: $recipe.doseGrams, systemImage: "scalemass")
        RatioField(ratio: $recipe.ratio)
        NumberField(label: "Pours", unit: "", value: $recipe.pourCount, range: 1...12, systemImage: "drop")
        TimeInputField(label: "Bloom", seconds: $recipe.bloomTimeSec, systemImage: "timer")
        TimeInputField(label: "Drawdown (TDD)", seconds: $recipe.totalDrawdownSec, systemImage: "hourglass")

        // Progressive: everything below is optional detail.
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                PourBreakdown(recipe: $recipe)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pour notes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("aggressive, high, centre pour…",
                              text: Binding(get: { recipe.notes ?? "" }, set: { recipe.notes = $0.nilIfBlank }),
                              axis: .vertical)
                        .lineLimit(1...3)
                        .font(.subheadline)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Pour-by-pour breakdown", systemImage: "list.number")
                .font(.subheadline.weight(.medium))
        }
        .tint(Theme.accent)
    }

    // MARK: Espresso

    @ViewBuilder private var espressoFields: some View {
        // Shot metrics.
        DecimalField(label: "Dose", unit: "g", value: $recipe.doseGrams, systemImage: "scalemass")
        DecimalField(label: "Yield", unit: "g", value: $recipe.yieldGrams, systemImage: "cup.and.saucer")
        if let ratio = recipe.shotRatio {
            HStack {
                Label("Ratio", systemImage: "divide").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("1 : \(ratioText((ratio * 10).rounded() / 10))")
                    .font(.param(.body, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Brew ratio 1 to \(ratioText((ratio * 10).rounded() / 10))")
        }
        TimeInputField(label: "Shot time", seconds: $recipe.shotTimeSec, systemImage: "timer")

        // Manual technique — how temperature and pre-infusion are controlled without a PID.
        Text("Manual technique").overline().padding(.top, 4)
        NumberField(label: "Pre-infusion", unit: "s", value: $recipe.preInfusionSec, range: 0...30, systemImage: "drop.circle")
        NumberField(label: "Surf wait", unit: "s", value: $recipe.surfWaitSec, range: 0...90, systemImage: "clock")
        NumberField(label: "Steam mode", unit: "s", value: $recipe.steamModeSec, range: 0...60, systemImage: "flame")

        // Advanced / future: a real °C reading (once a PID is fitted) plus free-text notes.
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                NumberField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 80...110, systemImage: "thermometer.medium")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("channeling, gusher, updose…",
                              text: Binding(get: { recipe.notes ?? "" }, set: { recipe.notes = $0.nilIfBlank }),
                              axis: .vertical)
                        .lineLimit(1...3)
                        .font(.subheadline)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Measured temp & notes", systemImage: "thermometer.medium")
                .font(.subheadline.weight(.medium))
        }
        .tint(Theme.accent)
    }
}

// MARK: - Field rows

/// A typeable integer field with a label and unit. Tap the value and enter it directly; empty
/// renders as a "—" placeholder. Out-of-range entries are clamped when you finish editing.
private struct NumberField: View {
    let label: String
    let unit: String
    @Binding var value: Int?
    var range: ClosedRange<Int>? = nil
    var systemImage: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            TextField("—", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .font(.param(.body, weight: .semibold))
                .frame(maxWidth: 70)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { clamp() }
                }
            if !unit.isEmpty {
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "not set")
    }

    private func clamp() {
        guard let range, let v = value else { return }
        value = min(max(v, range.lowerBound), range.upperBound)
    }
}

/// A decimal field (dose) with a numeric keyboard.
private struct DecimalField: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    var systemImage: String

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.param(.body, weight: .semibold))
                .frame(maxWidth: 90)
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

/// Ratio entered as the denominator: "1 : [15]".
private struct RatioField: View {
    @Binding var ratio: Double?
    var body: some View {
        HStack {
            Label("Ratio", systemImage: "divide").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text("1 :").font(.body.weight(.semibold))
            TextField("—", value: $ratio, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.param(.body, weight: .semibold))
                .frame(maxWidth: 60)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ratio")
        .accessibilityValue(ratio.map { "1 to \(ratioText($0))" } ?? "not set")
    }
}

/// A typeable time field. Enter `m:ss` (e.g. `2:30`) or plain seconds (`30`); the value is
/// stored as seconds. No steppers — type it once and move on.
private struct TimeInputField: View {
    let label: String
    @Binding var seconds: Int?
    var systemImage: String

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            TextField("—", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .font(.param(.body, weight: .semibold))
                .frame(maxWidth: 80)
                .onChange(of: text) { _, newValue in seconds = parseTime(newValue) }
                .onChange(of: focused) { _, isFocused in
                    // Re-format to canonical m:ss when the user finishes editing.
                    if !isFocused { text = seconds.map { timeText($0) } ?? "" }
                }
                .onChange(of: seconds) { _, newValue in
                    // Keep in sync when seeded/changed externally (but not while typing).
                    if !focused { text = newValue.map { timeText($0) } ?? "" }
                }
        }
        .onAppear { text = seconds.map { timeText($0) } ?? "" }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(seconds.map { timeText($0) } ?? "not set")
    }
}

/// Parses "m:ss" or a plain seconds string into total seconds. Empty → nil.
private func parseTime(_ raw: String) -> Int? {
    let t = raw.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return nil }
    if t.contains(":") {
        let parts = t.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let m = Int(parts[0]) ?? 0
        let s = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return max(0, m * 60 + s)
    }
    return Int(t).map { max(0, $0) }
}

/// Editable per-pour list, driven by the pour *count* so you don't add rows one-by-one: set
/// "Pours" to 4 and four rows appear, pre-filled with suggested cumulative weights. Each row
/// carries a pour window (start–end), a cumulative target, and a style/note. Times cascade:
/// typing a start fills its end, typing an end fills the next pour's start (only ever filling
/// blanks, never overwriting what you typed).
private struct PourBreakdown: View {
    @Binding var recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recipe.pours.isEmpty {
                Text("Set a pour count above to lay out the pours, or add one below.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("#").frame(width: 24)
                    Text("start – end")
                    Spacer()
                    Text("to")
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            ForEach($recipe.pours) { $pour in
                PourRow(pour: $pour) { remove(pour) }
            }
            Button {
                Haptics.tap()
                recipe.pours.append(Pour(order: recipe.pours.count + 1))
                recipe.pourCount = recipe.pours.count
            } label: {
                Label("Add pour", systemImage: "plus.circle")
            }
            .font(.subheadline).buttonStyle(.plain).foregroundStyle(Theme.accent)
        }
        .onAppear { syncToCount() }
        .onChange(of: recipe.pourCount) { _, _ in syncToCount() }
        .onChange(of: recipe.pours) { _, _ in normalizeTimes() }
    }

    /// Make the number of rows match `pourCount`, pre-fill suggested weights when the rows are
    /// still blank, and seed the first pour's start at 0:00.
    private func syncToCount() {
        guard let target = recipe.pourCount, target >= 0 else { return }
        if recipe.pours.count < target {
            for i in recipe.pours.count..<target { recipe.pours.append(Pour(order: i + 1)) }
        } else if recipe.pours.count > target {
            recipe.pours = Array(recipe.pours.prefix(target))
        }
        reorder()
        prefillWeights()
        if !recipe.pours.isEmpty, recipe.pours[0].startSec == nil { recipe.pours[0].startSec = 0 }
        normalizeTimes()
    }

    /// Suggest cumulative water targets, but only when nothing's been entered yet.
    private func prefillWeights() {
        guard recipe.pours.allSatisfy({ $0.toGrams == nil }) else { return }
        let targets = recipe.suggestedCumulativeTargets(count: recipe.pours.count)
        guard targets.count == recipe.pours.count else { return }
        for i in recipe.pours.indices { recipe.pours[i].toGrams = targets[i] }
    }

    /// "Fill one, populate the next", filling blanks only: a start suggests its end (+10s); an
    /// end suggests the next pour's start (after the bloom rest for pour 1, a short rest after).
    private func normalizeTimes() {
        var p = recipe.pours
        var changed = false
        for i in p.indices where p[i].startSec != nil && p[i].endSec == nil {
            p[i].endSec = p[i].startSec! + 10; changed = true
        }
        for i in p.indices.dropLast() where p[i].endSec != nil && p[i + 1].startSec == nil {
            let rest = (i == 0) ? (recipe.bloomTimeSec ?? 30) : 30
            p[i + 1].startSec = p[i].endSec! + rest; changed = true
        }
        if changed { recipe.pours = p }   // guarded, so it converges in one extra pass
    }

    private func remove(_ pour: Pour) {
        Haptics.tap()
        recipe.pours.removeAll { $0.id == pour.id }
        reorder()
        recipe.pourCount = recipe.pours.isEmpty ? nil : recipe.pours.count
    }

    private func reorder() {
        for i in recipe.pours.indices { recipe.pours[i].order = i + 1 }
    }
}

/// One editable pour: time window + cumulative target on the first line, style/note below.
private struct PourRow: View {
    @Binding var pour: Pour
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("#\(pour.order)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 24)
                PourTimeField(placeholder: "0:00", seconds: $pour.startSec)
                Text("–").font(.caption).foregroundStyle(.secondary)
                PourTimeField(placeholder: "end", seconds: $pour.endSec)
                Spacer(minLength: 4)
                TextField("g", value: $pour.toGrams, format: .number.precision(.fractionLength(0...0)))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .frame(width: 46).font(.param(.subheadline))
                Text("g").font(.caption).foregroundStyle(.secondary)
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "minus.circle.fill").hitTarget(32)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Remove pour \(pour.order)")
            }
            TextField("style / note (centre, aggressive…)",
                      text: Binding(get: { pour.style ?? "" }, set: { pour.style = $0.nilIfBlank }))
                .font(.subheadline)
                .padding(.leading, 30)
        }
        .padding(.vertical, 3)
    }
}

/// A compact typeable time cell for a pour (m:ss or plain seconds). Mirrors TimeInputField but
/// pill-shaped and fixed-width for the row layout.
private struct PourTimeField: View {
    let placeholder: String
    @Binding var seconds: Int?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.center)
            .focused($focused)
            .font(.param(.subheadline))
            .frame(width: 54)
            .padding(.vertical, 4)
            .background(Theme.crema.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: text) { _, v in seconds = parseTime(v) }
            .onChange(of: focused) { _, isFocused in if !isFocused { text = seconds.map { timeText($0) } ?? "" } }
            .onChange(of: seconds) { _, v in if !focused { text = v.map { timeText($0) } ?? "" } }
            .onAppear { text = seconds.map { timeText($0) } ?? "" }
            .accessibilityLabel(placeholder == "end" ? "Pour end time" : "Pour start time")
    }
}
