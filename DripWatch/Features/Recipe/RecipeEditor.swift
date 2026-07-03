import SwiftUI

/// THE one reusable recipe editor. Used identically for logging a brew and for drafting the
/// next one. "Structured but mostly optional, progressive": the simple line is what you reach
/// for every day; the per-pour breakdown and notes stay folded away until you want them.
///
/// Values can be typed directly (tap and enter) or nudged with +/- where a small tweak is the
/// common move (temp, pours, dose, the manual-technique seconds). Focusing a numeric field
/// selects its contents so typing replaces rather than appends (see `selectAllWhenNumericFocused`).
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
        NumberField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 60...100, systemImage: "thermometer.medium", step: 1, stepDefault: 92)
        DecimalField(label: "Dose", unit: "g", value: $recipe.doseGrams, systemImage: "scalemass", step: 0.5, stepDefault: 15, range: 0...100, presets: [15, 20])
        RatioField(ratio: $recipe.ratio)
        NumberField(label: "Pours", unit: "", value: $recipe.pourCount, range: 1...12, systemImage: "drop", step: 1, stepDefault: 3)
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
        DecimalField(label: "Dose", unit: "g", value: $recipe.doseGrams, systemImage: "scalemass", step: 0.5, stepDefault: 18, range: 0...60, presets: [18, 20])
        DecimalField(label: "Yield", unit: "g", value: $recipe.yieldGrams, systemImage: "cup.and.saucer", step: 0.5, stepDefault: 36, range: 0...120)
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
        NumberField(label: "Pre-infusion", unit: "s", value: $recipe.preInfusionSec, range: 0...30, systemImage: "drop.circle", step: 1, stepDefault: 6)
        NumberField(label: "Surf wait", unit: "s", value: $recipe.surfWaitSec, range: 0...90, systemImage: "clock", step: 1, stepDefault: 8)
        NumberField(label: "Steam mode", unit: "s", value: $recipe.steamModeSec, range: 0...60, systemImage: "flame", step: 1, stepDefault: 4)

        // Advanced / future: a real °C reading (once a PID is fitted) plus free-text notes.
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                NumberField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 80...110, systemImage: "thermometer.medium", step: 1, stepDefault: 93)
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

/// A fixed-width `[−  value  +]` control. Every stepper row uses the same geometry, so the minus
/// and plus glyphs line up in tidy columns down the form. Neutral pill + hairline border with
/// accent glyphs — lighter than filled buttons. The value stays a tappable field for typing.
/// Shared with the grind picker so all steppers in the app match.
struct StepperCluster<Content: View>: View {
    let onMinus: () -> Void
    let onPlus: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            button("minus", onMinus)
            divider
            content.frame(width: 74).frame(maxHeight: .infinity)
            divider
            button("plus", onPlus)
        }
        .frame(height: 36)
        .background(Theme.crema.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            // Decorative only — must never intercept taps meant for the buttons.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.crema, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var divider: some View {
        Rectangle().fill(Theme.crema).frame(width: 1, height: 22).allowsHitTesting(false)
    }

    private func button(_ shape: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: shape)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 36)
                .contentShape(Rectangle())   // whole cell tappable, not just the glyph
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shape == "plus" ? "Increase" : "Decrease")
    }
}

/// A typeable integer field. Tap the value and enter it directly; empty renders as "—". When
/// `step` is set, an aligned +/- cluster nudges the value (a blank field jumps to `stepDefault`
/// on first tap). Out-of-range entries are clamped.
private struct NumberField: View {
    let label: String
    let unit: String
    @Binding var value: Int?
    var range: ClosedRange<Int>? = nil
    var systemImage: String
    var step: Int? = nil
    var stepDefault: Int = 0
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if step != nil {
                StepperCluster(onMinus: { bump(-1) }, onPlus: { bump(1) }) { valueField }
            } else {
                valueField.frame(width: 90)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "not set")
        .accessibilityAdjustableAction { direction in
            guard step != nil else { return }
            switch direction {
            case .increment: bump(1)
            case .decrement: bump(-1)
            default: break
            }
        }
    }

    private var valueField: some View {
        HStack(spacing: 2) {
            TextField("—", value: $value, format: .number)
                .keyboardType(.numberPad).multilineTextAlignment(.center)
                .focused($focused).font(.param(.body, weight: .semibold))
                .onChange(of: focused) { _, isFocused in if !isFocused { clamp() } }
            if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func bump(_ direction: Int) {
        guard let step else { return }
        Haptics.select()
        value = value == nil ? clamped(stepDefault) : clamped(value! + direction * step)
    }

    private func clamp() { if let v = value { value = clamped(v) } }
    private func clamped(_ v: Int) -> Int {
        guard let range else { return v }
        return min(max(v, range.lowerBound), range.upperBound)
    }
}

/// A decimal field (dose, yield). Optional +/- nudge by `step` (e.g. 0.5 g), snapping to the grid;
/// a blank field jumps to `stepDefault` on first tap. `presets` adds quick-pick chips (e.g. your
/// two usual doses, 15 g / 20 g) beneath the field — tap to fill, tap again to clear, type to override.
private struct DecimalField: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    var systemImage: String
    var step: Double? = nil
    var stepDefault: Double = 0
    var range: ClosedRange<Double>? = nil
    var presets: [Double] = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                Label(label, systemImage: systemImage)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if step != nil {
                    StepperCluster(onMinus: { bump(-1) }, onPlus: { bump(1) }) { valueField }
                } else {
                    valueField.frame(width: 90)
                }
            }
            if !presets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { presetChip($0) }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\(gramText($0)) \(unit)" } ?? "not set")
        .accessibilityAdjustableAction { direction in
            guard step != nil else { return }
            switch direction {
            case .increment: bump(1)
            case .decrement: bump(-1)
            default: break
            }
        }
    }

    private var valueField: some View {
        HStack(spacing: 2) {
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad).multilineTextAlignment(.center)
                .font(.param(.body, weight: .semibold))
            if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func presetChip(_ preset: Double) -> some View {
        let active = value == preset
        return Button {
            Haptics.select()
            value = active ? nil : preset
        } label: {
            Chip(text: "\(gramText(preset))\(unit)", symbol: active ? "checkmark" : nil,
                 tint: active ? Theme.accent : .secondary)
                .hitTarget(32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(gramText(preset)) \(unit)\(active ? ", selected" : "")")
    }

    private func bump(_ direction: Int) {
        guard let step else { return }
        Haptics.select()
        let raw = value == nil ? stepDefault : value! + Double(direction) * step
        let snapped = (raw / step).rounded() * step
        if let range { value = min(max(snapped, range.lowerBound), range.upperBound) }
        else { value = max(0, snapped) }
    }
}

/// Ratio entered as the denominator: "1 : [15]", with +/- in 0.5 steps.
private struct RatioField: View {
    @Binding var ratio: Double?
    var step: Double = 0.5
    var stepDefault: Double = 15
    var range: ClosedRange<Double> = 1...30

    var body: some View {
        HStack(spacing: 8) {
            Label("Ratio", systemImage: "divide").font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            StepperCluster(onMinus: { bump(-1) }, onPlus: { bump(1) }) {
                HStack(spacing: 1) {
                    Text("1:").font(.param(.body, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("—", value: $ratio, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad).multilineTextAlignment(.leading)
                        .font(.param(.body, weight: .semibold))
                        .frame(width: 30)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ratio")
        .accessibilityValue(ratio.map { "1 to \(ratioText($0))" } ?? "not set")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: bump(1)
            case .decrement: bump(-1)
            default: break
            }
        }
    }

    private func bump(_ direction: Int) {
        Haptics.select()
        let raw = ratio == nil ? stepDefault : ratio! + Double(direction) * step
        let snapped = (raw / step).rounded() * step
        ratio = min(max(snapped, range.lowerBound), range.upperBound)
    }
}

/// A time field you fill with just digits — no colon to type. "230" → 2:30, "45" → 0:45,
/// "28" → 0:28. Shows the raw digits while editing (number pad), and formats to m:ss when you
/// tap away.
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
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .font(.param(.body, weight: .semibold))
                .frame(maxWidth: 80)
                .onChange(of: text) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue { text = digits }
                    seconds = secondsFromDigits(digits)
                }
                .onChange(of: focused) { _, isFocused in syncText(editing: isFocused) }
                .onChange(of: seconds) { _, newValue in if !focused { text = newValue.map { timeText($0) } ?? "" } }
        }
        .onAppear { text = seconds.map { timeText($0) } ?? "" }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(seconds.map { timeText($0) } ?? "not set")
    }

    /// Show raw digits while editing (natural for the number pad), formatted m:ss when done.
    private func syncText(editing: Bool) {
        text = editing ? (seconds.map { secondsToDigits($0) } ?? "")
                       : (seconds.map { timeText($0) } ?? "")
    }
}

/// Digits typed on a number pad → seconds. The last two digits are seconds, the rest minutes:
/// "45" → 45s, "230" → 2:30, "1230" → 12:30. Empty → nil.
func secondsFromDigits(_ raw: String) -> Int? {
    let d = raw.filter(\.isNumber)
    guard !d.isEmpty else { return nil }
    if d.count <= 2 { return Int(d) }
    let secs = Int(d.suffix(2)) ?? 0
    let mins = Int(d.dropLast(2)) ?? 0
    return mins * 60 + secs
}

/// Seconds → the digit string you'd type for them (round-trips with `secondsFromDigits`).
func secondsToDigits(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    return m > 0 ? "\(m)\(String(format: "%02d", s))" : "\(s)"
}

/// Editable per-pour list, driven by the pour *count* so you don't add rows one-by-one: set
/// "Pours" to 4 and four rows appear. Cumulative water targets are suggested and **re-flow to a
/// clean ramp whenever you change the count** (add/remove a pour), so you never end up with a
/// stale middle and an empty last row. A seeded recipe's existing weights are preserved on load.
/// Timings are off by default — reveal them only when you actually have a schedule to follow, so
/// the app never invents times you'd have to delete.
private struct PourBreakdown: View {
    @Binding var recipe: Recipe
    @State private var syncedCount: Int?
    @State private var showTimes: Bool

    init(recipe: Binding<Recipe>) {
        _recipe = recipe
        // Show the time columns up front only if the recipe already carries timings.
        let hasTimes = recipe.wrappedValue.pours.contains { $0.startSec != nil || $0.endSec != nil }
        _showTimes = State(initialValue: hasTimes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recipe.pours.isEmpty {
                Text("Set a pour count above to lay out the pours, or add one below.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Toggle(isOn: $showTimes.animation()) {
                    Text("Add pour timings").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .tint(Theme.accent)
                HStack {
                    Text("#").frame(width: 24)
                    if showTimes { Text("start – end") }
                    Spacer()
                    Text("to (g)")
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            ForEach($recipe.pours) { $pour in
                PourRow(pour: $pour, showTimes: showTimes) { remove(pour) }
            }
            Button {
                Haptics.tap()
                recipe.pourCount = (recipe.pourCount ?? recipe.pours.count) + 1
            } label: {
                Label("Add pour", systemImage: "plus.circle")
            }
            .font(.subheadline).buttonStyle(.plain).foregroundStyle(Theme.accent)
        }
        .onAppear { syncToCount() }
        .onChange(of: recipe.pourCount) { _, _ in syncToCount() }
    }

    /// Match the row count to `pourCount`, then decide on weights: on first layout keep whatever
    /// a seeded recipe brought (only suggest into a fully-blank set); on any later count change,
    /// re-flow the whole cumulative ramp so add/remove always leaves a sensible, complete set.
    private func syncToCount() {
        guard let target = recipe.pourCount, target >= 0 else { return }
        if recipe.pours.count < target {
            for i in recipe.pours.count..<target { recipe.pours.append(Pour(order: i + 1)) }
        } else if recipe.pours.count > target {
            recipe.pours = Array(recipe.pours.prefix(target))
        }
        reorder()

        if syncedCount == nil {
            if recipe.pours.allSatisfy({ $0.toGrams == nil }) { applySuggestedWeights() }
        } else if target != syncedCount {
            applySuggestedWeights()
        }
        syncedCount = target
    }

    private func applySuggestedWeights() {
        let targets = recipe.suggestedCumulativeTargets(count: recipe.pours.count)
        guard targets.count == recipe.pours.count else { return }
        for i in recipe.pours.indices { recipe.pours[i].toGrams = targets[i] }
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

/// One editable pour: cumulative target (+ optional time window) on the first line, style/note
/// below. Time cells appear only when the breakdown's "Add pour timings" toggle is on.
private struct PourRow: View {
    @Binding var pour: Pour
    var showTimes: Bool
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("#\(pour.order)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 24)
                if showTimes {
                    PourTimeField(placeholder: "start", seconds: $pour.startSec)
                    Text("–").font(.caption).foregroundStyle(.secondary)
                    PourTimeField(placeholder: "end", seconds: $pour.endSec)
                }
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

/// A compact digit-entry time cell for a pour — no colon to type (see TimeInputField). Pill-shaped
/// and fixed-width for the row layout.
private struct PourTimeField: View {
    let placeholder: String
    @Binding var seconds: Int?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .focused($focused)
            .font(.param(.subheadline))
            .frame(width: 54)
            .padding(.vertical, 4)
            .background(Theme.crema.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: text) { _, v in
                let digits = v.filter(\.isNumber)
                if digits != v { text = digits }
                seconds = secondsFromDigits(digits)
            }
            .onChange(of: focused) { _, isFocused in
                text = isFocused ? (seconds.map { secondsToDigits($0) } ?? "")
                                 : (seconds.map { timeText($0) } ?? "")
            }
            .onChange(of: seconds) { _, v in if !focused { text = v.map { timeText($0) } ?? "" } }
            .onAppear { text = seconds.map { timeText($0) } ?? "" }
            .accessibilityLabel(placeholder == "end" ? "Pour end time" : "Pour start time")
    }
}
