import SwiftUI

/// The roaster-bag dot scale (Acidity ●●●●○○○). Read-only display and an editable variant.
/// Uses filled/empty *shapes* plus a text value, so it never relies on color alone (HIG §6).
struct TasteBalanceView: View {
    let balance: TasteBalance
    var max = 5
    @Environment(\.dynamicTypeSize) private var typeSize

    private var rows: [(String, Int)] {
        var r: [(String, Int)] = []
        if let v = balance.acidity { r.append(("Acidity", v)) }
        if let v = balance.sweetness { r.append(("Sweetness", v)) }
        if let v = balance.bitterness { r.append(("Bitterness", v)) }
        if let v = balance.body { r.append(("Body", v)) }
        return r
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.0) { name, value in
                    Group {
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                DotRow(value: value, max: max)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Text(name.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 78, alignment: .leading)
                                DotRow(value: value, max: max)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(name)
                    .accessibilityValue("\(value) of \(max)")
                }
            }
        }
    }
}

/// A row of filled/empty dots.
struct DotRow: View {
    let value: Int
    var max = 5
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max, id: \.self) { i in
                Circle()
                    .fill(i < value ? Theme.accent : Theme.crema.opacity(0.25))
                    .frame(width: 9, height: 9)
            }
        }
    }
}

/// An editable balance axis: label + tappable dots (each dot ≥44pt hit area via padding).
struct TasteBalanceEditor: View {
    @Binding var balance: TasteBalance

    var body: some View {
        VStack(spacing: 4) {
            axis("Acidity", value: $balance.acidity)
            axis("Sweetness", value: $balance.sweetness)
            axis("Bitterness", value: $balance.bitterness)
            axis("Body", value: $balance.body)
        }
    }

    private func axis(_ name: String, value: Binding<Int?>) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.subheadline)
                .frame(width: 92, alignment: .leading)
            ForEach(1...5, id: \.self) { i in
                Button {
                    Haptics.select()
                    // Tapping the current value clears it, so an axis can be left unset.
                    value.wrappedValue = (value.wrappedValue == i) ? nil : i
                } label: {
                    Circle()
                        .fill((value.wrappedValue ?? 0) >= i ? Theme.accent : Theme.crema.opacity(0.25))
                        .frame(width: 18, height: 18)
                        .frame(width: 30, height: 44) // generous touch target (HIG §1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(name) \(i)")
            }
            Spacer(minLength: 0)
        }
    }
}
