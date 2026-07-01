import SwiftUI

/// THE one reusable recipe editor. Used identically for logging a brew and for drafting the
/// next one. "Structured but mostly optional, progressive": the simple line is what you reach
/// for every day; the per-pour breakdown and notes stay folded away until you want them.
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
        IntField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 60...100, systemImage: "thermometer.medium")
        DecimalField(label: "Dose", unit: "g", value: $recipe.doseGrams, systemImage: "scalemass")
        RatioField(ratio: $recipe.ratio)
        IntField(label: "Pours", unit: "", value: $recipe.pourCount, range: 1...12, systemImage: "drop")
        TimeField(label: "Bloom", seconds: $recipe.bloomTimeSec, systemImage: "timer")
        TimeField(label: "Drawdown (TDD)", seconds: $recipe.totalDrawdownSec, systemImage: "hourglass")

        // Progressive: everything below is optional detail.
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                PourBreakdown(pours: $recipe.pours)
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
        TimeField(label: "Shot time", seconds: $recipe.shotTimeSec, systemImage: "timer")

        // Manual technique — how temperature and pre-infusion are controlled without a PID.
        Text("Manual technique").overline().padding(.top, 4)
        IntField(label: "Pre-infusion", unit: "s", value: $recipe.preInfusionSec, range: 0...30, systemImage: "drop.circle")
        IntField(label: "Surf wait", unit: "s", value: $recipe.surfWaitSec, range: 0...90, systemImage: "clock")
        IntField(label: "Steam mode", unit: "s", value: $recipe.steamModeSec, range: 0...60, systemImage: "flame")

        // Advanced / future: a real °C reading (once a PID is fitted) plus free-text notes.
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                IntField(label: "Temp", unit: "°C", value: $recipe.waterTempC, range: 80...110, systemImage: "thermometer.medium")
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

/// An integer field with a label, unit, and inline stepper. Empty renders as "—".
private struct IntField: View {
    let label: String
    let unit: String
    @Binding var value: Int?
    let range: ClosedRange<Int>
    var systemImage: String

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { "\($0)\(unit.isEmpty ? "" : " \(unit)")" } ?? "—")
                .font(.param(.body, weight: .semibold))
                .foregroundStyle(value == nil ? .secondary : Color(.label))
            Stepper("") {
                let n = (value ?? range.lowerBound - 1) + 1
                value = min(n, range.upperBound); Haptics.select()
            } onDecrement: {
                if let v = value { value = v > range.lowerBound ? v - 1 : nil; Haptics.select() }
            }
            .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? "not set")
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

/// A time field showing m:ss, edited by stepping ±5s (fast) with a long-press-friendly stepper.
private struct TimeField: View {
    let label: String
    @Binding var seconds: Int?
    var systemImage: String

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(seconds.map { timeText($0) } ?? "—")
                .font(.param(.body, weight: .semibold))
                .foregroundStyle(seconds == nil ? .secondary : Color(.label))
            Stepper("") {
                seconds = (seconds ?? 0) + 5; Haptics.select()
            } onDecrement: {
                if let s = seconds { seconds = s > 5 ? s - 5 : nil; Haptics.select() }
            }
            .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(seconds.map { timeText($0) } ?? "not set")
    }
}

/// Editable per-pour list: cumulative target grams, optional time, optional style.
private struct PourBreakdown: View {
    @Binding var pours: [Pour]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($pours) { $pour in
                HStack(spacing: 8) {
                    Text("#\(pour.order)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 26)
                    TextField("to g", value: $pour.toGrams, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.numberPad).frame(maxWidth: 60)
                        .font(.param(.subheadline))
                    Text("g").font(.caption).foregroundStyle(.secondary)
                    TextField("style", text: Binding(get: { pour.style ?? "" }, set: { pour.style = $0.nilIfBlank }))
                        .font(.subheadline)
                    Button(role: .destructive) { remove(pour) } label: {
                        Image(systemName: "minus.circle.fill").hitTarget(36)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Remove pour \(pour.order)")
                }
            }
            Button {
                Haptics.tap()
                pours.append(Pour(order: (pours.map(\.order).max() ?? 0) + 1))
            } label: {
                Label("Add pour", systemImage: "plus.circle")
            }
            .font(.subheadline).buttonStyle(.plain).foregroundStyle(Theme.accent)
        }
    }

    private func remove(_ pour: Pour) {
        Haptics.tap()
        pours.removeAll { $0.id == pour.id }
        for (i, _) in pours.enumerated() { pours[i].order = i + 1 }
    }
}
