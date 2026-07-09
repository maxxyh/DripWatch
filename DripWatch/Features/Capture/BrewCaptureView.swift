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
    /// True once `nextDraft` reflects a real starting point (the brewed recipe, or a loaded
    /// draft). Until then, opening the plan pre-fills it from what you actually brewed.
    @State private var nextDraftSeeded: Bool

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
            _nextDraftSeeded = State(initialValue: true)
            _photoData = State(initialValue: editing.photo)
            _committed = State(initialValue: true)
            _liveBrew = State(initialValue: editing)
        } else {
            // New brew: seed only from a previous brew of the SAME method (recipes differ by method).
            let seed = bean.seedRecipe(for: method)
            _brewedAt = State(initialValue: .now)
            _recipe = State(initialValue: seed)
            _taste = State(initialValue: Taste())
            // A fresh brew starts with NO next-brew plan. Any pending plan already seeded THIS
            // brew's recipe above and is consumed on commit — carrying it forward would leave
            // every brew pointing a "next plan" at itself. The plan is drafted deliberately while
            // tasting, and pre-fills from what you actually brewed (see `planNext` onChange).
            _planNext = State(initialValue: false)
            _nextDraft = State(initialValue: seed)
            _nextDraftSeeded = State(initialValue: false)
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
            .onChange(of: planNext) { _, on in
                // Opening the plan for the first time pre-fills it with everything you just
                // brewed, so you change only what you want rather than starting from blank.
                if on, !nextDraftSeeded { nextDraft = recipe; nextDraftSeeded = true }
                edited = true; persist()
            }
            .onChange(of: nextDraft) { _, _ in nextDraftSeeded = true; edited = true; persist() }
            .onChange(of: photoData) { _, _ in edited = true; persist() }
            #if DEBUG
            .task {
                // DEBUG-only: jump straight into Brew mode for verification/screenshots.
                guard UserDefaults.standard.bool(forKey: "openBrewingPhase"), !committed else { return }
                if method == .pourover, recipe.doseGrams == nil { recipe.doseGrams = 20 }
                try? await Task.sleep(for: .milliseconds(300))
                commit()
                withAnimation { phase = .brewing }
            }
            #endif
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
            // The one number you sit and watch for while brewing — first-class, with a live
            // stopwatch, so you never have to dig into "Adjust recipe" to record it. Pourover
            // times the drawdown; espresso times the shot.
            BrewTimerField(
                label: method == .pourover ? "Total drawdown" : "Shot time",
                systemImage: method == .pourover ? "hourglass" : "timer",
                seconds: method == .pourover ? $recipe.totalDrawdownSec : $recipe.shotTimeSec
            )
            .dripCard()
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
            if !priorTasteBrews.isEmpty {
                PreviousNotesView(brews: priorTasteBrews,
                                  onAdd: { term, positive in addTasteTerm(term, positive: positive) })
            }
            photoCard
            nextCard
        }
    }

    /// Recent brews of this method that carry tasting notes — the memory you reach for while
    /// deciding how this cup tastes ("last time it was sour"). Excludes the brew being logged.
    private var priorTasteBrews: [Brew] {
        Array(bean.timeline
            .filter { $0.method == method && $0.id != liveBrew?.id && !$0.taste.isEmpty }
            .prefix(3))
    }

    /// Reuse a previous tasting term with one tap.
    private func addTasteTerm(_ term: String, positive: Bool) {
        if positive {
            if !taste.positives.contains(term) { taste.positives.append(term); Haptics.select() }
        } else {
            if !taste.negatives.contains(term) { taste.negatives.append(term); Haptics.select() }
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

            if method == .pourover {
                pourPlan
            } else {
                espressoTechnique
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
            // Total (finish) water — the number you actually pour to.
            if let w = recipe.effectiveWaterGrams, recipe.doseGrams != nil {
                s.append(("water", "\(gramText(w))g"))
            }
        }
        return s
    }

    /// The pour-by-pour plan you follow while watching the scale: cumulative weight targets (and
    /// timings when set). Uses your explicit breakdown if you made one — editable so a live
    /// correction sticks — otherwise a suggested ramp derived from pour count + total water.
    @ViewBuilder private var pourPlan: some View {
        let derived = recipe.hasPourBreakdown ? [] : recipe.suggestedCumulativeTargets(count: recipe.pourCount ?? 0)
        let hasLadder = recipe.hasPourBreakdown || !derived.isEmpty
        if hasLadder || recipe.bloomTimeSec != nil || recipe.totalDrawdownSec != nil {
            Divider().overlay(Theme.crema.opacity(0.3))
            HStack(alignment: .firstTextBaseline) {
                Text("Pour plan").overline()
                Spacer()
                if !pourPlanSummary.isEmpty {
                    Text(pourPlanSummary).font(.caption).foregroundStyle(.secondary)
                }
            }
            if recipe.hasPourBreakdown {
                ForEach($recipe.pours) { $pour in
                    pourRow(order: pour.order, grams: $pour.toGrams, start: pour.startSec, end: pour.endSec)
                }
            } else {
                ForEach(Array(derived.enumerated()), id: \.offset) { index, grams in
                    staticPourRow(order: index + 1, grams: grams)
                }
            }
        }
    }

    private var pourPlanSummary: String {
        var parts: [String] = []
        if let b = recipe.bloomTimeSec { parts.append("bloom \(timeText(b))") }
        if let p = recipe.pourCount { parts.append("\(p) pour\(p == 1 ? "" : "s")") }
        if let t = recipe.totalDrawdownSec { parts.append("TDD \(timeText(t))") }
        return parts.joined(separator: " · ")
    }

    private func pourRow(order: Int, grams: Binding<Double?>, start: Int?, end: Int?) -> some View {
        HStack(spacing: 10) {
            Text("#\(order)").font(.param(.subheadline, weight: .bold))
                .foregroundStyle(Theme.accent).frame(width: 28, alignment: .leading)
            if let start {
                Text(timeWindow(start, end)).font(.param(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("→").foregroundStyle(.secondary)
            TextField("—", value: grams, format: .number.precision(.fractionLength(0...0)))
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .font(.param(.title3, weight: .semibold)).frame(width: 66)
            Text("g").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func staticPourRow(order: Int, grams: Double) -> some View {
        HStack(spacing: 10) {
            Text("#\(order)").font(.param(.subheadline, weight: .bold))
                .foregroundStyle(Theme.accent).frame(width: 28, alignment: .leading)
            Spacer()
            Text("→").foregroundStyle(.secondary)
            Text(gramText(grams)).font(.param(.title3, weight: .semibold))
            Text("g").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func timeWindow(_ start: Int, _ end: Int?) -> String {
        if let end { return "\(timeText(start))–\(timeText(end))" }
        return timeText(start)
    }

    @ViewBuilder private var espressoTechnique: some View {
        let tech: [(String, String)] = [
            recipe.preInfusionSec.map { ("pre-infuse", "\($0)s") },
            recipe.surfWaitSec.map { ("surf", "\($0)s") },
            recipe.steamModeSec.map { ("steam", "\($0)s") },
        ].compactMap { $0 }
        if !tech.isEmpty {
            Divider().overlay(Theme.crema.opacity(0.3))
            Text("Manual technique").overline()
            WrapLayout(spacing: 20, lineSpacing: 10) {
                ForEach(tech, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.1).font(.param(.title3, weight: .semibold))
                        Text(item.0).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                    Text("Pre-filled with what you just brewed — change only what you want. This seeds your next brew.")
                        .font(.caption).foregroundStyle(.secondary)
                    // Highlight the delta vs. this brew, so the plan reads as "what I'm changing".
                    let planChanges = BrewDiff.changes(from: recipe, to: nextDraft)
                    if planChanges.isEmpty {
                        Text("No changes yet — tweak a value below.")
                            .font(.caption).foregroundStyle(.tertiary)
                    } else {
                        WrapLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(planChanges, id: \.self) {
                                Chip(text: $0, symbol: "arrow.right", tint: Theme.accent)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Planned changes: \(planChanges.joined(separator: ", "))")
                    }
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
                    .submitLabel(.next)
                    // Return adds the tag and keeps the keyboard up for the next one.
                    .onSubmit { add(); focused = true }
                    // Commit whatever's typed when the field loses focus (e.g. tapping Save),
                    // so a note you typed but didn't "enter" isn't silently lost.
                    .onChange(of: focused) { _, isFocused in if !isFocused { add() } }
                Button { add(); focused = true } label: { Image(systemName: "return").hitTarget(36) }
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

// MARK: - Brewing observations

/// A first-class, in-the-moment time capture for the number you sit and watch during a brew —
/// drawdown for pourover, shot time for espresso. A live stopwatch (tap Start when it begins,
/// Stop when it finishes) writes the seconds; the value also stays tappable so you can type it
/// straight in (digits only — "230" → 2:30). No digging into "Adjust recipe" for it.
struct BrewTimerField: View {
    let label: String
    let systemImage: String
    @Binding var seconds: Int?

    @State private var running = false
    @State private var startDate = Date.now
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 8)

            if running {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    Text(timeText(elapsed(at: context.date)))
                        .font(.param(.title, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
            } else {
                TextField("—", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .font(.param(.title, weight: .semibold))
                    .frame(maxWidth: 92)
                    .onChange(of: text) { _, newValue in
                        let (formatted, secs) = liveTimeEntry(newValue)
                        if formatted != newValue { text = formatted }
                        seconds = secs
                    }
                    .onChange(of: seconds) { _, v in if !focused { text = v.map { timeText($0) } ?? "" } }
                    .onAppear { text = seconds.map { timeText($0) } ?? "" }
                    .accessibilityLabel(label)
                    .accessibilityValue(seconds.map { timeText($0) } ?? "not set")
            }

            // Prominent when running (accent fill, contrast handled by the button style — no
            // hardcoded appearance), quiet otherwise.
            Button(action: toggle) {
                Image(systemName: running ? "stop.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(running ? Theme.accent : Color.secondary)
            .accessibilityLabel(running ? "Stop timing \(label)" : "Start timing \(label)")
        }
        // Advancing the phase (or dismissing) while the stopwatch is still running would tear
        // this view down and drop the elapsed time — the one number you're timing. Capture it.
        .onDisappear {
            if running { seconds = elapsed(at: .now); running = false }
        }
    }

    private func elapsed(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(startDate).rounded()))
    }

    private func toggle() {
        if running {
            seconds = elapsed(at: .now)
            running = false
            Haptics.success()
        } else {
            focused = false
            startDate = .now
            running = true
            Haptics.tap()
        }
    }
}

// MARK: - Previous tasting notes

/// While logging how this cup tastes, the last few brews' tasting notes for the same bean —
/// the memory you're implicitly comparing against. Positive/negative terms are tappable to
/// reuse in the current taste with one tap.
struct PreviousNotesView: View {
    let brews: [Brew]   // newest first, non-empty taste
    var onAdd: (_ term: String, _ positive: Bool) -> Void
    @State private var expanded = false

    private var visible: [Brew] { expanded ? brews : Array(brews.prefix(1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Previous notes", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                Text("tap a term to reuse").font(.caption2).foregroundStyle(.tertiary)
            }
            ForEach(visible, id: \.id) { brew in
                brewNote(brew)
                if brew.id != visible.last?.id {
                    Divider().overlay(Theme.crema.opacity(0.3))
                }
            }
            if brews.count > 1 {
                Button {
                    Haptics.tap(); withAnimation { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "Show \(brews.count - 1) more")
                        .font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .dripCard()
    }

    @ViewBuilder private func brewNote(_ brew: Brew) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(brew.brewedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if !brew.taste.positives.isEmpty || !brew.taste.negatives.isEmpty {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(brew.taste.positives, id: \.self) { term in
                        termButton(term, symbol: "plus", tint: Theme.sage, positive: true)
                    }
                    ForEach(brew.taste.negatives, id: \.self) { term in
                        termButton(term, symbol: "minus", tint: Theme.clay, positive: false)
                    }
                }
            }
            if let note = brew.taste.note, !note.isEmpty {
                Text("“\(note)”").font(.footnote.italic()).foregroundStyle(.secondary)
            }
        }
    }

    private func termButton(_ term: String, symbol: String, tint: Color, positive: Bool) -> some View {
        Button {
            onAdd(term, positive)
        } label: {
            Chip(text: term, symbol: symbol, tint: tint).hitTarget(32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(term), \(positive ? "good" : "bad"). Tap to reuse.")
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
