import SwiftUI
import SwiftData
import PhotosUI

/// Focused "add a bag" task, presented as a sheet. The photo leads because it's the card's
/// hero; every text field is optional (OCR will fill them for you later).
struct AddBeanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var scanning = false
    @State private var scanNote: String?

    @State private var name = ""
    @State private var roaster = ""
    @State private var country = ""
    @State private var region = ""
    @State private var farm = ""
    @State private var varietal = ""
    @State private var process = ""
    @State private var roastLevel = ""
    @State private var hasRoastDate = false
    @State private var roastDate = Date.now
    @State private var roasterNotes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            if let photoData, let ui = UIImage(data: photoData) {
                                Image(uiImage: ui)
                                    .resizable().scaledToFill()
                            } else {
                                Theme.crema.opacity(0.18)
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill").font(.title)
                                    Text("Add bag photo").font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(Theme.accent)
                            }
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Add bag photo")

                    if photoData != nil {
                        Button {
                            Task { await scan() }
                        } label: {
                            HStack {
                                if scanning { ProgressView().controlSize(.small) }
                                Label(scanning ? "Scanning…" : "Scan text from photo",
                                      systemImage: "text.viewfinder")
                            }
                        }
                        .disabled(scanning)
                        if let scanNote {
                            Text(scanNote).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Bean") {
                    TextField("Name (e.g. Pure Forest)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Roaster", text: $roaster)
                        .textInputAutocapitalization(.words)
                }

                Section("Origin") {
                    TextField("Country", text: $country).textInputAutocapitalization(.words)
                    TextField("Region", text: $region).textInputAutocapitalization(.words)
                    TextField("Farm", text: $farm).textInputAutocapitalization(.words)
                    TextField("Variety", text: $varietal).textInputAutocapitalization(.words)
                }

                Section("Roast") {
                    TextField("Process (e.g. Washed, Natural)", text: $process)
                        .textInputAutocapitalization(.words)
                    TextField("Roast level", text: $roastLevel)
                        .textInputAutocapitalization(.words)
                    Toggle("Roast date", isOn: $hasRoastDate.animation())
                    if hasRoastDate {
                        DatePicker("Roasted on", selection: $roastDate, displayedComponents: .date)
                    }
                }

                Section("Roaster's notes") {
                    TextField("Tastes like…", text: $roasterNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Bean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .task(id: photoItem) {
                if let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) {
                    photoData = downscale(data)
                }
            }
        }
    }

    /// Runs on-device OCR and fills any fields the user hasn't already typed into.
    @MainActor private func scan() async {
        guard let photoData else { return }
        scanning = true
        defer { scanning = false }
        let lines = await BagOCR.recognize(from: photoData)
        guard !lines.isEmpty else { scanNote = "No text found — try a clearer, straight-on photo."; return }
        let bag = BagOCR.parse(lines)

        var filled = 0
        func fill(_ field: inout String, _ value: String?) {
            guard field.isEmpty, let value, !value.isEmpty else { return }
            field = value; filled += 1
        }
        fill(&name, bag.name)
        fill(&region, bag.region)
        fill(&farm, bag.farm)
        fill(&varietal, bag.varietal)
        fill(&process, bag.process)
        fill(&roastLevel, bag.roastLevel)
        fill(&roasterNotes, bag.roasterNotes)

        scanNote = filled > 0 ? "Filled \(filled) field\(filled == 1 ? "" : "s") — review below." : "Couldn't map fields — edit manually."
        if filled > 0 { Haptics.success() } else { Haptics.tap() }
    }

    /// Save is allowed with just a photo or just a name — the card works from either.
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty || photoData != nil }

    private func save() {
        let bean = Bean(name: name.trimmingCharacters(in: .whitespaces))
        bean.roasterName = roaster.nilIfBlank
        bean.country = country.nilIfBlank
        bean.region = region.nilIfBlank
        bean.farm = farm.nilIfBlank
        bean.varietal = varietal.nilIfBlank
        bean.process = process.nilIfBlank
        bean.roastLevel = roastLevel.nilIfBlank
        bean.roastDate = hasRoastDate ? roastDate : nil
        bean.roasterNotes = roasterNotes.nilIfBlank
        bean.bagPhoto = photoData
        context.insert(bean)
        Haptics.success()
        dismiss()
    }
}

/// Downscales a captured image so the store stays lean (bag shots don't need full res).
func downscale(_ data: Data, maxDimension: CGFloat = 1400, quality: CGFloat = 0.8) -> Data {
    guard let image = UIImage(data: data) else { return data }
    let longest = max(image.size.width, image.size.height)
    guard longest > maxDimension else { return image.jpegData(compressionQuality: quality) ?? data }
    let scale = maxDimension / longest
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    return scaled.jpegData(compressionQuality: quality) ?? data
}

extension String {
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
