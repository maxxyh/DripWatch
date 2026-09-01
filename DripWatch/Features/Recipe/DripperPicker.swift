import SwiftUI

/// A small visual quick picker for the pourover brewer. The three familiar drippers are presets,
/// while the text field keeps the recipe open to any brewer the user adds later.
struct DripperPicker: View {
    @Binding var selection: String?

    static let presets: [DripperPreset] = [
        .init(name: "Hario V60 (Ceramic)", assetName: "DripperHarioV60Ceramic"),
        .init(name: "V60 Neo", assetName: "DripperV60Neo"),
        .init(name: "April Brewer", assetName: "DripperAprilPlastic"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dripper", systemImage: "mug")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Self.presets) { preset in
                    let selected = selection?.dripperIdentityKey == preset.name.dripperIdentityKey
                    Button {
                        Haptics.select()
                        selection = selected ? nil : preset.name
                    } label: {
                        VStack(spacing: 5) {
                            Image(preset.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 42)
                            Text(preset.shortName)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected ? Theme.accent : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .padding(.horizontal, 4)
                        .background(selected ? Theme.accent.opacity(0.1) : Theme.crema.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Theme.accent.opacity(0.5) : Theme.crema, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dripper, \(preset.name)\(selected ? ", selected" : "")")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            TextField("Other dripper", text: Binding(
                get: { selection ?? "" },
                set: { selection = $0.nilIfBlank }
            ))
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .font(.subheadline)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Theme.crema.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Dripper name")
        }
    }
}

struct DripperPreset: Identifiable {
    let name: String
    let assetName: String
    var id: String { name }

    var shortName: String {
        switch name {
        case "Hario V60 (Ceramic)": "V60"
        case "April Brewer": "April"
        default: name
        }
    }
}
