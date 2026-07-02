import SwiftUI
import SwiftData
import PhotosUI

/// Log a brew (pourover or espresso), taste it, and — right there while tasting — draft the
/// next brew, all in the same reusable editor. Seeds from the bean's pending draft (or the
/// last brew) so you rarely start from scratch.
struct BrewCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let bean: Bean
    let method: BrewMethod
    /// When set, we're editing this existing brew rather than logging a new one.
    let editingBrew: Brew?

    /// The three moments of a brew, each with different needs.
    enum Phase: Int, CaseIterable {
        case recipe, brewing, taste
        var title: String { ["Recipe", "Brewing", "Taste"][rawValue] }
    }

    @State private var phase: Phase = .recipe
    /// Whether the brew is persisted. Once true every edit autosaves and dismiss is safe.
    @State private var committed: Bool
    @State private var liveBrew: Brew?
    @State private var edited = false
    @State private var confirmingCancel = false

    @State private var brewedAt = Date.now
    @State private var recipe: Recipe
    @State private var taste: Taste
    @State private var showBalance = false
    @State private var showNext = false
    @State private var planNext: Bool
    @State private var nextDraft: Recipe

    // Optional result photo (latte art, crema, the cup).
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoOptions = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var preview: PreviewPhoto?

    init(bean: Bean, method: BrewMethod = .pourover, editing: Brew? = nil) {
        self.bean = bean
        self.method = editing?.method ?? method
        self.editingBrew = editing

        if let editing {
            // Editing: load exactly what was saved so nothing changes unless the user changes it.
            // It's already on disk, so every edit here autosaves.
            _brewedAt = State(initialValue: editing.brewedAt)
            _recipe = State(initialValue: editing.recipe)
            _taste = State(initialValue: editing.taste)
            _planNext = State(initialValue: editing.nextRecipeDraft != nil)
            _nextDraft = State(initialValue: editing.nextRecipeDraft ?? editing.recipe)
            _photoData = State(initialValue: editing.photo)
            _committed = State(initialValue: true)
            _liveBrew = State(initialValue: editing)
        } else {
            // New brew: seed only from a previous brew of the SAME method (recipes differ by method).
            let seed = bean.seedRecipe(for: method)
            _brewedAt = State(initialValue: .now)
            _recipe = State(initialValue: seed)
            _taste = State(initialValue: Taste())
            let pending = bean.pendingNextRecipe(for: method)
            _planNext = State(initialValue: pending != nil)
            _nextDraft = State(initialValue: pending ?? seed)
            _committed = State(initialValue: false)
            _liveBrew = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                phaseBar
                ScrollView {
                    Group {
                        switch phase {
                        case .recipe: recipePhase
                        case .brewing: brewingPhase
                        case .taste: tastePhase
                        }
                    }
                    .padding(Theme.Space.m)
                }
                bottomBar
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { leadingButton }
            }
            .scrollDismissesKeyboard(.interactively)
            .selectAllWhenNumericFocused()
            .task(id: photoItem) {
                if let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) {
                    photoData = downscale(data)
                }
            }
            .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in photoData = downscale(data) }.ignoresSafeArea()
            }
            .confirmationDialog("Brew photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showLibrary = true }
                if photoData != nil {
                    Button("Remove Photo", role: .destructive) { photoData = nil; photoItem = nil }
                }
            }
            .confirmationDialog("Discard this brew?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .photoViewer($preview)
            // Once committed, every change writes straight through — nothing to lose.
            .onChange(of: recipe) { _, _ in edited = true; persist() }
            .onChange(of: taste) { _, _ in edited = true; persist() }
            .onChange(of: brewedAt) { _, _ in edited = true; persist() }
            .onChange(of: planNext) { _, _ in edited = true; persist() }
            .onChange(of: nextDraft) { _, _ in edited = true; persist() }
            .onChange(of: photoData) { _, _ in edited = true; persist() }
        }
    }

    private var navTitle: String {
        (editingBrew == nil && !committed ? "New " : "") + method.label
    }

    // MARK: Phase navigation

    private var phaseBar: some View {
        HStack(spacing: 6) {
            ForEach(Phase.allCases, id: \.self) { p in
                let active = phase == p
                let reachable = committed || p == .recipe
                Button {
                    guard reachable else { return }
                    Haptics.select(); withAnimation { phase = p }
                } label: {
                    VStack(spacing: 6) {
                        Text("\(p.rawValue + 1) · \(p.title)")
                            .font(.caption.weight(active ? .semibold : .regular))
                            .foregroundStyle(active ? Theme.accent : (reachable ? Color(.label) : .secondary))
                        Rectangle()
                            .fill(active ? Theme.accent : Theme.crema)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!reachable)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(p.title) step\(active ? ", current" : "")")
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.top, 8)
    }

    private var leadingButton: some View {
        Group {
            if committed {
                Button("Done") { dismiss() }
            } else {
                Button("Cancel") { edited ? (confirmingCancel = true) : dismiss() }
            }
        }
    }

    private var bottomBar: some View {
        Button(action: advance) {
            Text(primaryTitle).font(.headline).frame(maxWidth: .infinity).frame(minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.accent)
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var primaryTitle: String {
        switch phase {
        case .recipe: return committed ? "Continue" : "Start brew"
        case .brewing: return "Finish & log taste"
        case .taste: return "Done"
        }
    }

    private func advance() {
        switch phase {
        case .recipe:
            if !committed { commit() }
            withAnimation { phase = .brewing }
        case .brewing:
            withAnimation { phase = .taste }
        case .taste:
            dismiss()
        }
    }

    /// Persist the brew the moment brewing starts, so a later dismiss can't lose the recipe.
    private func commit() {
        Haptics.success()
        let brew = Brew(brewedAt: brewedAt, method: method, recipe: recipe)
        brew.bean = bean
        context.insert(brew)
        liveBrew = brew
        committed = true
        persist()
    }

    /// Write the current draft through to the persisted brew. No-op until committed.
    private func persist() {
        guard committed, let brew = liveBrew else { return }
        brew.brewedAt = brewedAt
        brew.method = method
        brew.recipe = recipe
        brew.taste = taste
        brew.photo = photoData
        brew.nextRecipeDraft = planNext ? nextDraft : nil
        brew.updatedAt = .now
        // The plan seeds next time — but only from the newest brew of its method.
        if bean.lastBrew(for: method)?.id == brew.id {
            bean.setPendingNextRecipe(planNext ? nextDraft : nil, for: method)
        }
        bean.updatedAt = .now
    }

    // MARK: Phases

    private var recipePhase: some View {
        VStack(spacing: 16) {
            header
            recipeCard
        }
    }

    private var brewingPhase: some View {
        VStack(spacing: 16) {
            brewingReference
            DisclosureGroup {
                RecipeEditor(recipe: $recipe, method: method).padding(.top, 8)
            } label: {
                Label("Adjust recipe", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Theme.accent)
            .dripCard()
        }
    }

    private var tastePhase: some View {
        VStack(spacing: 16) {
            tasteCard
            photoCard
            nextCard
        }
    }

    /// The calm, glanceable reference to follow while grinding and pouring. Big instrument-style
    /// numbers; the pour targets stay tappable so a live correction is one tap (and autosaves).
    private var brewingReference: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bean.name.isEmpty ? "Untitled bean" : bean.name).font(.headline)
                    Text(method.label).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.sage)
            }

            if let g = recipe.grind {
                Text(g.display).font(.param(.title3, weight: .semibold)).foregroundStyle(Theme.accent)
            }

            if !bigStats.isEmpty {
                WrapLayout(spacing: 20, lineSpacing: 12) {
                    ForEach(bigStats, id: \.label) { stat in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.value).font(.param(.title, weight: .semibold))
                            Text(stat.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if method == .pourover, !recipe.pours.isEmpty {
                Divider().overlay(Theme.crema.opacity(0.3))
                Text("Pour to (g)").overline()
                ForEach($recipe.pours) { $pour in
                    HStack {
                        Text("#\(pour.order)").font(.param(.subheadline, weight: .bold))
                            .foregroundStyle(Theme.accent).frame(width: 28)
                        Spacer()
                        TextField("—", value: $pour.toGrams, format: .number.precision(.fractionLength(0...0)))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .font(.param(.title3, weight: .semibold)).frame(width: 72)
                        Text("g").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !bean.roasterNoteList.isEmpty {
                Divider().overlay(Theme.crema.opacity(0.3))
                Text("Roaster notes").overline()
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(bean.roasterNoteList, id: \.self) {
                        Chip(text: $0, symbol: "sparkles", tint: Theme.accent)
                    }
                }
            }
        }
        .dripCard()
    }

    /// The headline numbers for the brewing reference, per method.
    private var bigStats: [(label: String, value: String)] {
        var s: [(String, String)] = []
        if method == .espresso {
            if let d = recipe.doseGrams { s.append(("dose", "\(gramText(d))g")) }
            if let y = recipe.yieldGrams { s.append(("yield", "\(gramText(y))g")) }
            if let r = recipe.shotRatio { s.append(("ratio", "1:\(ratioText((r * 10).rounded() / 10))")) }
            if let t = recipe.shotTimeSec { s.append(("shot", "\(t)s")) }
        } else {
            if let t = recipe.waterTempC { s.append(("temp", "\(t)°")) }
            if let d = recipe.doseGrams { s.append(("dose", "\(gramText(d))g")) }
            if let r = recipe.ratio { s.append(("ratio", "1:\(ratioText(r))")) }
        }
        return s
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: method.symbol).foregroundStyle(Theme.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(bean.name.isEmpty ? "Untitled bean" : bean.name).font(.headline)
                Text(bean.togetherLabel).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            DatePicker("", selection: $brewedAt, displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel("Brew date")
        }
        .dripCard()
    }

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recipe", systemImage: "list.bullet.rectangle")
            if bean.pendingNextRecipe(for: method) != nil {
                Text("Seeded from your last “next brew” note.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            RecipeEditor(recipe: $recipe, method: method)
        }
        .dripCard()
    }

    private var tasteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("How did it taste?", systemImage: "mouth")

            // The roaster's own notes, as a reference to taste against.
            if !bean.roasterNoteList.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Roaster notes").overline()
                    WrapLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(bean.roasterNoteList, id: \.self) {
                            Chip(text: $0, symbol: "sparkles", tint: Theme.accent)
                        }
                    }
                }
            }

            // The everyday taste input: what was good, what was bad.
            ChipField(title: "Good", items: $taste.positives, tint: Theme.sage, symbol: "plus")
            ChipField(title: "Bad", items: $taste.negatives, tint: Theme.clay, symbol: "minus")

            // A free-text impression for nuance the chips can't hold — one tap away.
            DisclosureGroup(isExpanded: $showBalance) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tasting note").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("opened up as it cooled, short finish…",
                                  text: Binding(get: { taste.note ?? "" }, set: { taste.note = $0.nilIfBlank }),
                                  axis: .vertical)
                            .lineLimit(1...3)
                            .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Balance").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TasteBalanceEditor(balance: $taste.balance)
                    }
                    HStack {
                        Text("Overall").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        StarRating(rating: $taste.rating)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Note, balance & stars (optional)", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Theme.accent)
        }
        .dripCard()
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Photo", systemImage: "camera")
            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(height: 200).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { Haptics.tap(); preview = PreviewPhoto(data: data) }
                    .accessibilityLabel("Brew photo. Tap to preview.")
                HStack {
                    Button { Haptics.tap(); showPhotoOptions = true } label: {
                        Label("Change", systemImage: "photo")
                    }
                    Spacer()
                    Button(role: .destructive) { photoData = nil; photoItem = nil } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .font(.subheadline)
            } else {
                Button {
                    Haptics.tap(); showPhotoOptions = true
                } label: {
                    ZStack {
                        Theme.crema.opacity(0.18)
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill").font(.title)
                            Text("Add a photo").font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .frame(height: 120).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a brew photo")
            }
        }
        .dripCard()
    }

    /// Kept collapsed by default so the taste screen stays focused on tasting; the next-brew
    /// tweaks are a deliberate step you open when you're ready. A summary line shows any plan
    /// that's already carried forward without expanding the editor.
    private var nextCard: some View {
        DisclosureGroup(isExpanded: $showNext.animation()) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Plan a change for next time", isOn: $planNext.animation())
                    .font(.subheadline).tint(Theme.accent)
                if planNext {
                    Text("This becomes the starting point for the next brew.")
                        .font(.caption).foregroundStyle(.secondary)
                    RecipeEditor(recipe: $nextDraft, method: method)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Label("Next brew", systemImage: "arrow.turn.down.right")
                    .font(.headline).foregroundStyle(Theme.accent)
                Spacer()
                if planNext, !nextDraft.summaryLine.isEmpty {
                    Text(nextDraft.summaryLine)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .tint(Theme.accent)
        .dripCard()
    }

    private func sectionTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage).font(.headline)
    }

}

// MARK: - Taste inputs

/// A labelled chip field: existing chips plus a small add field. Chips carry a +/− symbol so
/// good/off is not signalled by color alone.
struct ChipField: View {
    let title: String
    @Binding var items: [String]
    var tint: Color
    var symbol: String? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    @State private var entry = ""
    @FocusState private var focused: Bool

    private var placeholder: String { title.isEmpty ? "Add…" : "Add \(title.lowercased())…" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            if !items.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            Haptics.tap()
                            items.removeAll { $0 == item }
                        } label: {
                            Chip(text: item, symbol: symbol, tint: tint)
                                .hitTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item)\(title.isEmpty ? "" : ", \(title)"). Tap to remove.")
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $entry)
                    .textInputAutocapitalization(autocapitalization)
                    .font(.subheadline)
                    .focused($focused)
                    .onSubmit(add)
                    // Commit whatever's typed when the field loses focus (e.g. tapping Save),
                    // so a note you typed but didn't "enter" isn't silently lost.
                    .onChange(of: focused) { _, isFocused in if !isFocused { add() } }
                Button(action: add) { Image(systemName: "return").hitTarget(36) }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                    .disabled(entry.nilIfBlank == nil)
                    .accessibilityLabel("Add \(title)")
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Theme.crema.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func add() {
        guard let v = entry.nilIfBlank else { return }
        if !items.contains(v) { items.append(v); Haptics.select() }
        entry = ""
    }
}

/// A 0–5 star rating; tapping the current star clears it.
struct StarRating: View {
    @Binding var rating: Int?
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    Haptics.select()
                    rating = (rating == i) ? nil : i
                } label: {
                    Image(systemName: (rating ?? 0) >= i ? "star.fill" : "star")
                        .foregroundStyle(Theme.crema)
                        .hitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
