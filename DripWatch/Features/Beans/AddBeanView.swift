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

    /// A bag photo being edited — either an existing `BeanPhoto` (kept by identity) or a freshly
    /// added image not yet persisted.
    private struct PhotoDraft: Identifiable {
        let id = UUID()
        var data: Data
        var existing: BeanPhoto?
    }

    @State private var photoDrafts: [PhotoDraft]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var scanNote: String?
    @State private var preview: PreviewPhoto?

    @State private var showPhotoOptions = false
    @State private var showLibrary = false
    @State private var showCamera = false

    @Query private var lexiconTerms: [LexiconTerm]
    /// Terms OCR couldn't file, awaiting the user's category choice.
    @State private var unresolved: [String] = []

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
    /// Roaster's tasting notes as chips (stored comma-joined on the bean).
    @State private var roasterNoteTags: [String]

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
        _roasterNoteTags = State(initialValue: bean?.roasterNoteList ?? [])

        // Load existing gallery (by identity so unchanged photos aren't re-inserted), falling
        // back to the legacy single photo — which will migrate into the gallery on save.
        var drafts: [PhotoDraft] = []
        if let bean {
            if !bean.orderedPhotos.isEmpty {
                drafts = bean.orderedPhotos.compactMap { p in p.data.map { PhotoDraft(data: $0, existing: p) } }
            } else if let legacy = bean.bagPhoto {
                drafts = [PhotoDraft(data: legacy, existing: nil)]
            }
        }
        _photoDrafts = State(initialValue: drafts)
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
                unresolvedSection
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
                Section {
                    ChipField(title: "", items: $roasterNoteTags, tint: Theme.accent,
                              symbol: "sparkles", autocapitalization: .words)
                } header: {
                    Text("Roaster's notes")
                } footer: {
                    Text("The roaster's tasting notes — shown on the shelf and while you taste.")
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
            .task(id: photoItems) {
                guard !photoItems.isEmpty else { return }
                for item in photoItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        appendPhoto(downscale(data))
                    }
                }
                photoItems = []
            }
            .photosPicker(isPresented: $showLibrary, selection: $photoItems,
                          maxSelectionCount: 5, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in appendPhoto(downscale(data)) }
                    .ignoresSafeArea()
            }
            .confirmationDialog("Add bag photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showLibrary = true }
            }
            .photoViewer($preview)
        }
    }

    // MARK: Photos

    private var photoSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photoDrafts) { draft in photoThumb(draft) }
                    addPhotoTile
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            if !photoDrafts.isEmpty {
                Button {
                    Task { await scan() }
                } label: {
                    HStack {
                        if scanning { ProgressView().controlSize(.small) }
                        Label(scanning ? "Scanning…"
                                       : "Scan text from \(photoDrafts.count == 1 ? "photo" : "\(photoDrafts.count) photos")",
                              systemImage: "text.viewfinder")
                    }
                }
                .disabled(scanning)
                if let scanNote {
                    Text(scanNote).font(.caption).foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Add each surface the roaster prints on — all are scanned together.")
        }
    }

    private func photoThumb(_ draft: PhotoDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            if let ui = UIImage(data: draft.data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 108, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.tap()
                        let idx = photoDrafts.firstIndex { $0.id == draft.id } ?? 0
                        preview = PreviewPhoto(datas: photoDrafts.map(\.data), index: idx)
                    }
            }
            Button {
                Haptics.tap()
                photoDrafts.removeAll { $0.id == draft.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
    }

    private var addPhotoTile: some View {
        Button {
            Haptics.tap()
            showPhotoOptions = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "camera.fill").font(.title2)
                Text(photoDrafts.isEmpty ? "Add bag photo" : "Add").font(.caption.weight(.medium))
            }
            .foregroundStyle(Theme.accent)
            .frame(width: 108, height: 140)
            .background(Theme.crema.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add bag photo")
    }

    private func appendPhoto(_ data: Data) {
        photoDrafts.append(PhotoDraft(data: data, existing: nil))
    }

    // MARK: OCR

    /// Runs on-device OCR across *all* the bag photos, merges the results, and fills any fields
    /// the user hasn't already typed into. Roasters often split facts across surfaces, so a
    /// value found on any one photo counts.
    @MainActor private func scan() async {
        guard !photoDrafts.isEmpty else { return }
        scanning = true
        defer { scanning = false }

        var merged = ParsedBag()
        var found = false
        for draft in photoDrafts {
            let lines = await BagOCR.recognize(from: draft.data)
            guard !lines.isEmpty else { continue }
            found = true
            merged = mergeBags(merged, BagOCR.parse(lines, learned: learnedMap))
        }
        guard found else { scanNote = "No text found — try clearer, straight-on photos."; return }

        var filled = 0
        func fill(_ field: inout String, _ value: String?) {
            guard field.isEmpty, let value, !value.isEmpty else { return }
            field = value; filled += 1
        }
        fill(&name, merged.name)
        fill(&country, merged.country)
        fill(&region, merged.region)
        fill(&farm, merged.farm)
        fill(&varietal, merged.varietal)
        fill(&process, merged.process)
        fill(&roastLevel, merged.roastLevel)
        if roasterNoteTags.isEmpty {
            roasterNoteTags = splitTags(merged.roasterNotes)
            if !roasterNoteTags.isEmpty { filled += 1 }
        }
        unresolved = mergeUnique(unresolved, merged.unresolved)

        var parts: [String] = []
        if filled > 0 { parts.append("Filled \(filled) field\(filled == 1 ? "" : "s")") }
        if !unresolved.isEmpty { parts.append("\(unresolved.count) to file below") }
        scanNote = parts.isEmpty ? "Couldn't map fields — edit manually." : parts.joined(separator: " · ")
        if filled > 0 || !unresolved.isEmpty { Haptics.success() } else { Haptics.tap() }
    }

    /// Merge two parsed bags: single-value fields take the first found; list-style fields
    /// (country / variety / roaster notes) union their entries; unknowns pool together.
    private func mergeBags(_ a: ParsedBag, _ b: ParsedBag) -> ParsedBag {
        var m = a
        m.name = a.name ?? b.name
        m.region = a.region ?? b.region
        m.farm = a.farm ?? b.farm
        m.process = a.process ?? b.process
        m.roastLevel = a.roastLevel ?? b.roastLevel
        m.country = joinLists(a.country, b.country)
        m.varietal = joinLists(a.varietal, b.varietal)
        m.roasterNotes = joinLists(a.roasterNotes, b.roasterNotes)
        m.unresolved = mergeUnique(a.unresolved, b.unresolved)
        return m
    }

    private func joinLists(_ a: String?, _ b: String?) -> String? {
        let items = mergeUnique(splitTags(a), splitTags(b))
        return items.isEmpty ? nil : items.joined(separator: ", ")
    }

    private func splitTags(_ s: String?) -> [String] {
        (s ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func mergeUnique(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        return (a + b).filter { seen.insert($0.lowercased()).inserted }
    }

    /// User-taught terms, lowercased → field, consulted first when parsing.
    private var learnedMap: [String: BagField] {
        Dictionary(lexiconTerms.filter { $0.deletedAt == nil }.map { ($0.term, $0.field) },
                   uniquingKeysWith: { first, _ in first })
    }

    // MARK: Interactive term filing

    /// "We're not sure what these are" — each unknown term gets a menu to file it into a field.
    /// Filing both fills the field now and remembers the term so it auto-files next time.
    @ViewBuilder private var unresolvedSection: some View {
        if !unresolved.isEmpty {
            Section("Not sure what these are") {
                Text("Tap a term to file it — DripWatch remembers your choice for next time.")
                    .font(.caption).foregroundStyle(.secondary)
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(unresolved, id: \.self) { term in
                        Menu {
                            ForEach(BagField.allCases) { field in
                                Button { assign(term, to: field) } label: {
                                    Label(field.label, systemImage: field.symbol)
                                }
                            }
                            Divider()
                            Button(role: .destructive) { ignore(term) } label: {
                                Label("Ignore", systemImage: "xmark")
                            }
                        } label: {
                            Chip(text: term, symbol: "questionmark.circle", tint: Theme.accent)
                        }
                        .accessibilityLabel("Unfiled term \(term). Tap to choose a category.")
                    }
                }
            }
        }
    }

    /// File a term into a field (appending when the field already holds a value), remember it, and
    /// clear it from the unresolved list.
    private func assign(_ term: String, to field: BagField) {
        Haptics.success()
        appendValue(term, to: field)
        rememberTerm(term, field: field)
        ignore(term)
    }

    private func ignore(_ term: String) {
        unresolved.removeAll { $0 == term }
    }

    private func appendValue(_ value: String, to field: BagField) {
        func set(_ target: inout String) {
            target = target.isEmpty ? value : target + ", " + value
        }
        switch field {
        case .name: set(&name)
        case .roaster: set(&roaster)
        case .country: set(&country)
        case .region: set(&region)
        case .farm: set(&farm)
        case .varietal: set(&varietal)
        case .process: set(&process)
        case .roastLevel: set(&roastLevel)
        case .tastingNote:
            if !roasterNoteTags.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                roasterNoteTags.append(value)
            }
        }
    }

    /// Upsert a learned term so future scans classify it automatically.
    private func rememberTerm(_ term: String, field: BagField) {
        let key = term.lowercased()
        if let existing = lexiconTerms.first(where: { $0.deletedAt == nil && $0.term == key }) {
            existing.field = field
            existing.updatedAt = .now
        } else {
            context.insert(LexiconTerm(term: key, field: field))
        }
    }

    // MARK: Save

    /// Save is allowed with just a photo or just a name — the card works from either.
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty || !photoDrafts.isEmpty }

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
        bean.roasterNotes = roasterNoteTags.isEmpty ? nil : roasterNoteTags.joined(separator: ", ")
        bean.updatedAt = .now
        if editingBean == nil { context.insert(bean) }
        applyPhotos(to: bean)
        Haptics.success()
        dismiss()
    }

    /// Reconcile the edited gallery onto the bean: soft-delete removed photos, reorder kept ones,
    /// insert new ones, and retire the legacy single photo (now represented in `photos`).
    private func applyPhotos(to bean: Bean) {
        let kept = Set(photoDrafts.compactMap { $0.existing?.id })
        for photo in bean.photos where photo.deletedAt == nil && !kept.contains(photo.id) {
            photo.deletedAt = .now
            photo.updatedAt = .now
        }
        for (index, draft) in photoDrafts.enumerated() {
            if let existing = draft.existing {
                existing.order = index
                existing.updatedAt = .now
            } else {
                let photo = BeanPhoto(data: draft.data, order: index)
                photo.bean = bean
                context.insert(photo)
            }
        }
        bean.bagPhoto = nil
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
