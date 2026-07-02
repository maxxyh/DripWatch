import SwiftUI
import SwiftData
import PhotosUI

/// Add or edit a "bag" (character card), presented as a sheet. The photo leads because it's
/// the card's hero — snap it with the camera or pick from the library. Every text field keeps
/// its label visible so you can verify where OCR put things, and process/roast have one-tap
/// presets.
struct AddBeanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// When set, we're editing this bean rather than creating a new one.
    let editingBean: Bean?

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var scanning = false
    @State private var scanNote: String?

    @State private var showPhotoOptions = false
    @State private var showLibrary = false
    @State private var showCamera = false

    @State private var name: String
    @State private var roaster: String
    @State private var country: String
    @State private var region: String
    @State private var farm: String
    @State private var varietal: String
    @State private var process: String
    @State private var roastLevel: String
    @State private var hasRoastDate: Bool
    @State private var roastDate: Date
    @State private var roasterNotes: String

    private static let processPresets = ["Washed", "Natural", "Honey", "Anaerobic"]
    private static let roastPresets = ["Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"]

    init(editing bean: Bean? = nil) {
        self.editingBean = bean
        _name = State(initialValue: bean?.name ?? "")
        _roaster = State(initialValue: bean?.roasterName ?? "")
        _country = State(initialValue: bean?.country ?? "")
        _region = State(initialValue: bean?.region ?? "")
        _farm = State(initialValue: bean?.farm ?? "")
        _varietal = State(initialValue: bean?.varietal ?? "")
        _process = State(initialValue: bean?.process ?? "")
        _roastLevel = State(initialValue: bean?.roastLevel ?? "")
        // Default roast date ON for new beans (we only buy dated bags); reflect reality when editing.
        _hasRoastDate = State(initialValue: bean == nil ? true : (bean?.roastDate != nil))
        _roastDate = State(initialValue: bean?.roastDate ?? .now)
        _roasterNotes = State(initialValue: bean?.roasterNotes ?? "")
        _photoData = State(initialValue: bean?.bagPhoto)
    }

    private var isEditing: Bool { editingBean != nil }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                Section("Bean") {
                    LabeledTextField(label: "Name", placeholder: "e.g. Pure Forest", text: $name)
                    LabeledTextField(label: "Roaster", placeholder: "e.g. Nylon", text: $roaster)
                }
                Section("Origin") {
                    LabeledTextField(label: "Country", placeholder: "e.g. Ethiopia", text: $country)
                    LabeledTextField(label: "Region", placeholder: "e.g. Guji", text: $region)
                    LabeledTextField(label: "Farm", placeholder: "e.g. Shakiso", text: $farm)
                    LabeledTextField(label: "Variety", placeholder: "e.g. Heirloom", text: $varietal)
                }
                Section("Roast") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledTextField(label: "Process", placeholder: "e.g. Washed", text: $process)
                        PresetChips(options: Self.processPresets, selection: $process)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledTextField(label: "Roast level", placeholder: "e.g. Medium", text: $roastLevel)
                        PresetChips(options: Self.roastPresets, selection: $roastLevel)
                    }
                    Toggle("Roast date", isOn: $hasRoastDate.animation())
                    if hasRoastDate {
                        DatePicker("Roasted on", selection: $roastDate, in: ...Date.now, displayedComponents: .date)
                    }
                }
                Section("Roaster's notes") {
                    TextField("Tastes like…", text: $roasterNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Bean" : "New Bean")
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
            .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in photoData = downscale(data) }
                    .ignoresSafeArea()
            }
            .confirmationDialog("Bag photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showLibrary = true }
                if photoData != nil {
                    Button("Remove Photo", role: .destructive) { photoData = nil; photoItem = nil; scanNote = nil }
                }
            }
        }
    }

    // MARK: Photo

    private var photoSection: some View {
        Section {
            Button {
                Haptics.tap()
                showPhotoOptions = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let photoData, let ui = UIImage(data: photoData) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("Tap to change")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                    } else {
                        ZStack {
                            Theme.crema.opacity(0.18)
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill").font(.title)
                                Text("Add bag photo").font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .accessibilityLabel(photoData == nil ? "Add bag photo" : "Change bag photo")

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
    }

    // MARK: OCR

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

        scanNote = filled > 0 ? "Filled \(filled) field\(filled == 1 ? "" : "s") — check the labels below." : "Couldn't map fields — edit manually."
        if filled > 0 { Haptics.success() } else { Haptics.tap() }
    }

    // MARK: Save

    /// Save is allowed with just a photo or just a name — the card works from either.
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty || photoData != nil }

    private func save() {
        let bean = editingBean ?? Bean()
        bean.name = name.trimmingCharacters(in: .whitespaces)
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
        bean.updatedAt = .now
        if editingBean == nil { context.insert(bean) }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Reusable form pieces

/// A text field that keeps a small uppercase label above it — so a value stays identifiable
/// (which field is this?) even after it's filled in by hand or by OCR.
private struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
        }
        .padding(.vertical, 2)
    }
}

/// One-tap presets. Tapping a chip fills the bound field; tapping the active chip clears it.
/// Free text still wins — the chips just save typing for the common cases.
private struct PresetChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        WrapLayout(spacing: 6, lineSpacing: 6) {
            ForEach(options, id: \.self) { option in
                let active = selection.caseInsensitiveCompare(option) == .orderedSame
                Button {
                    Haptics.select()
                    selection = active ? "" : option
                } label: {
                    Chip(text: option,
                         symbol: active ? "checkmark" : nil,
                         tint: active ? Theme.accent : .secondary)
                        .hitTarget(34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option)\(active ? ", selected" : "")")
            }
        }
    }
}

/// A camera capture sheet (UIImagePickerController — SwiftUI's PhotosPicker can't take photos).
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
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
