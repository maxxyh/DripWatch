import SwiftUI
import SwiftData

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

    @State private var brewedAt = Date.now
    @State private var recipe: Recipe
    @State private var taste: Taste
    @State private var showBalance = false
    @State private var planNext: Bool
    @State private var nextDraft: Recipe

    init(bean: Bean, method: BrewMethod = .pourover, editing: Brew? = nil) {
        self.bean = bean
        self.method = editing?.method ?? method
        self.editingBrew = editing

        if let editing {
            // Editing: load exactly what was saved so nothing changes unless the user changes it.
            _brewedAt = State(initialValue: editing.brewedAt)
            _recipe = State(initialValue: editing.recipe)
            _taste = State(initialValue: editing.taste)
            _planNext = State(initialValue: editing.nextRecipeDraft != nil)
            _nextDraft = State(initialValue: editing.nextRecipeDraft ?? editing.recipe)
        } else {
            // New brew: seed only from a previous brew of the SAME method (recipes differ by method).
            let seed = bean.seedRecipe(for: editing?.method ?? method)
            _brewedAt = State(initialValue: .now)
            _recipe = State(initialValue: seed)
            _taste = State(initialValue: Taste())
            let pending = bean.pendingNextRecipe(for: editing?.method ?? method)
            _planNext = State(initialValue: pending != nil)
            _nextDraft = State(initialValue: pending ?? seed)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    recipeCard
                    tasteCard
                    nextCard
                }
                .padding(Theme.Space.m)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("\(editingBrew == nil ? "New" : "Edit") \(method.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $planNext.animation()) {
                Label {
                    Text("Plan the next brew").font(.headline)
                } icon: {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(Theme.accent)
                }
            }
            .tint(Theme.accent)

            if planNext {
                Text("What should we change next time? This becomes the starting point for the next brew.")
                    .font(.caption).foregroundStyle(.secondary)
                RecipeEditor(recipe: $nextDraft, method: method)
            }
        }
        .dripCard()
    }

    private func sectionTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage).font(.headline)
    }

    private func save() {
        let brew: Brew
        if let editingBrew {
            brew = editingBrew
            brew.brewedAt = brewedAt
            brew.method = method
            brew.recipe = recipe
            brew.updatedAt = .now
        } else {
            brew = Brew(brewedAt: brewedAt, method: method, recipe: recipe)
            brew.bean = bean
            context.insert(brew)
        }
        brew.taste = taste
        brew.nextRecipeDraft = planNext ? nextDraft : nil

        // The plan becomes the bean's pending seed for next time — but only if this is the
        // newest brew of its method (editing an older brew shouldn't clobber the current plan).
        if bean.lastBrew(for: method)?.id == brew.id {
            bean.setPendingNextRecipe(planNext ? nextDraft : nil, for: method)
        }
        bean.updatedAt = .now

        Haptics.success()
        dismiss()
    }
}

// MARK: - Taste inputs

/// A labelled chip field: existing chips plus a small add field. Chips carry a +/− symbol so
/// good/off is not signalled by color alone.
struct ChipField: View {
    let title: String
    @Binding var items: [String]
    var tint: Color
    var symbol: String
    @State private var entry = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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
                        .accessibilityLabel("\(item), \(title). Tap to remove.")
                    }
                }
            }
            HStack {
                TextField("Add \(title.lowercased())…", text: $entry)
                    .textInputAutocapitalization(.never)
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
