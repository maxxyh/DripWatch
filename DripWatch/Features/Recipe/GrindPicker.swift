import SwiftUI

/// Picks a grind in the grinder's *own* absolute vocabulary — grinder name, major dial, and
/// ± click offset — always showing the full reproducible value (`1Zpresso J · 3(−1)`).
/// Remembers the last grinder used so repeat capture is one glance.
struct GrindPicker: View {
    @Binding var grind: GrindSetting?
    @AppStorage("lastGrinderName") private var lastGrinder = "1Zpresso J"

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

            if grind == nil {
                Button {
                    Haptics.tap()
                    grind = GrindSetting(grinderName: lastGrinder, major: 3, clickOffset: 0)
                } label: {
                    Label("Set grind", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                editor
            }
        }
    }

    @ViewBuilder private var editor: some View {
        // Grinder name (remembered for next time).
        TextField("Grinder", text: Binding(
            get: { grind?.grinderName ?? "" },
            set: { grind?.grinderName = $0; lastGrinder = $0 }
        ))
        .textInputAutocapitalization(.words)
        .font(.subheadline)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Theme.crema.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

        HStack(spacing: 14) {
            stepper(label: "Dial",
                    value: Binding(get: { grind?.major ?? 0 }, set: { grind?.major = $0 }),
                    range: 0...60,
                    display: "\(grind?.major ?? 0)")
            stepper(label: "Clicks",
                    value: Binding(get: { grind?.clickOffset ?? 0 }, set: { grind?.clickOffset = $0 }),
                    range: -30...30,
                    display: grind.map { $0.clickOffset == 0 ? "0" : ($0.clickOffset > 0 ? "+\($0.clickOffset)" : "\($0.clickOffset)") } ?? "0",
                    hint: "+ finer · − coarser")

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
