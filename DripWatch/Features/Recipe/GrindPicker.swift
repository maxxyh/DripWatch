import SwiftUI
import SwiftData

/// Picks a grind in the grinder's *own* absolute vocabulary — grinder name, major dial, and
/// ± click offset — always showing the full reproducible value (`1Zpresso J · 3(−1)`).
/// Grinders you've used are saved, so picking one again is a single tap (we only own a few).
struct GrindPicker: View {
    @Binding var grind: GrindSetting?

    @Environment(\.modelContext) private var context
    @Query(sort: \Grinder.name) private var grinders: [Grinder]
    @AppStorage("lastGrinderName") private var lastGrinder = "1Zpresso J"

    /// Saved, non-deleted grinder names (deduped), newest-known first-ish by name sort.
    private var savedNames: [String] {
        var seen = Set<String>()
        return grinders
            .filter { $0.deletedAt == nil && !$0.name.isEmpty }
            .map(\.name)
            .filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Grind", systemImage: "dial.medium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let g = grind {
                    Text(g.display)
                        .font(.param(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            // Saved grinders — tap to select / switch. Always available so a wrong pick is one tap to fix.
            if !savedNames.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(savedNames, id: \.self) { name in
                        Button {
                            Haptics.select()
                            selectGrinder(name)
                        } label: {
                            Chip(text: name,
                                 symbol: grind?.grinderName == name ? "checkmark" : nil,
                                 tint: grind?.grinderName == name ? Theme.accent : .secondary)
                                .hitTarget(36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Grinder \(name)\(grind?.grinderName == name ? ", selected" : "")")
                    }
                }
            }

            if grind == nil {
                Button {
                    Haptics.tap()
                    let name = savedNames.first ?? lastGrinder
                    grind = GrindSetting(grinderName: name, major: 3, clickOffset: 0)
                    saveGrinder(name)
                } label: {
                    Label("Set grind", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                editor
            }
        }
        // Backfill: any grinder we're already using should be remembered as a tappable chip,
        // even if the user never edits the name field this session.
        .onAppear { if let name = grind?.grinderName { saveGrinder(name) } }
    }

    @ViewBuilder private var editor: some View {
        // Grinder name (free text for a new grinder; also remembered + saved for next time).
        TextField("Grinder", text: Binding(
            get: { grind?.grinderName ?? "" },
            set: { grind?.grinderName = $0; lastGrinder = $0 }
        ))
        .textInputAutocapitalization(.words)
        .submitLabel(.done)
        .onSubmit { if let name = grind?.grinderName { saveGrinder(name) } }
        .font(.subheadline)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Theme.crema.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

        // Stepless (worm-drive, e.g. DF54) vs. stepped (dial + clicks) — remembered per grinder.
        Toggle(isOn: Binding(get: { currentStepless }, set: { setStepless($0) })) {
            Text("Stepless (number, no clicks)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .tint(Theme.accent)

        if currentStepless {
            steplessEditor
        } else {
            steppedEditor
        }
    }

    /// Stepless: a draggable ruler for the whole number, a decimal field for precise entry.
    @ViewBuilder private var steplessEditor: some View {
        HStack(spacing: 14) {
            GrindRuler(value: Binding(get: { grind?.major ?? 0 }, set: { grind?.major = $0 }))
            VStack(alignment: .leading, spacing: 2) {
                Text("Setting").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("—", value: Binding(get: { grind?.major }, set: { grind?.major = $0 ?? 0 }),
                          format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .font(.param(.title3, weight: .semibold))
                    .frame(width: 48)
            }
            clearButton
        }
    }

    /// Stepped: the notebook's dial + click offset.
    @ViewBuilder private var steppedEditor: some View {
        HStack(spacing: 14) {
            stepper(label: "Dial",
                    value: Binding(get: { Int(grind?.major ?? 0) }, set: { grind?.major = Double($0) }),
                    range: 0...60,
                    display: grind?.majorText ?? "0")
            stepper(label: "Clicks",
                    value: Binding(get: { grind?.clickOffset ?? 0 }, set: { grind?.clickOffset = $0 }),
                    range: -30...30,
                    display: grind.map { $0.clickOffset == 0 ? "0" : ($0.clickOffset > 0 ? "+\($0.clickOffset)" : "\($0.clickOffset)") } ?? "0",
                    hint: "+ finer · − coarser")
            clearButton
        }
    }

    private var clearButton: some View {
        Button(role: .destructive) {
            Haptics.tap()
            grind = nil
        } label: {
            Image(systemName: "xmark.circle.fill").imageScale(.large).hitTarget()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Clear grind")
    }

    /// Whether the currently-selected grinder is a stepless machine (looked up by name).
    private var currentStepless: Bool {
        guard let name = grind?.grinderName else { return false }
        return grinders.first { $0.deletedAt == nil && $0.name == name }?.stepless ?? false
    }

    /// Record a grinder's kind (stepless or stepped) so the right input shows next time. Forcing
    /// clicks to zero when going stepless keeps the absolute value honest (no phantom offset).
    private func setStepless(_ value: Bool) {
        guard let raw = grind?.grinderName, let name = raw.nilIfBlank else { return }
        Haptics.select()
        if let existing = grinders.first(where: { $0.deletedAt == nil && $0.name == name }) {
            existing.stepless = value
            existing.updatedAt = .now
        } else {
            context.insert(Grinder(name: name, stepless: value))
        }
        if value { grind?.clickOffset = 0 }
    }

    /// Select a saved grinder, keeping the current dial/clicks (just swapping the machine).
    /// Switching to a stepless grinder drops the click offset, which it doesn't have.
    private func selectGrinder(_ name: String) {
        if grind == nil {
            grind = GrindSetting(grinderName: name, major: 3, clickOffset: 0)
        } else {
            grind?.grinderName = name
        }
        if grinders.first(where: { $0.deletedAt == nil && $0.name == name })?.stepless == true {
            grind?.clickOffset = 0
        }
        lastGrinder = name
        saveGrinder(name)
    }

    /// Upsert a grinder by name so it appears as a tappable chip next time.
    private func saveGrinder(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !grinders.contains(where: { $0.deletedAt == nil && $0.name == name }) else { return }
        context.insert(Grinder(name: name))
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, display: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(display)
                    .font(.param(.title3, weight: .semibold))
                    .frame(minWidth: 34, alignment: .leading)
                Stepper("") {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1; Haptics.select() }
                } onDecrement: {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1; Haptics.select() }
                }
                .labelsHidden()
            }
            if let hint { Text(hint).font(.caption2).foregroundStyle(.tertiary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(display)
    }
}
