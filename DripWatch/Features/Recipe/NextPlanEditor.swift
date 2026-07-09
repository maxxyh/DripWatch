import SwiftUI
import SwiftData

/// Edit the pending "next brew" plan on its own — without logging a brew. The plan card on the
/// bean opens this so you can refine what you'll try next as ideas come to you (not only in the
/// moment you're tasting). Changes autosave onto the bean's pending draft; the diff vs. your
/// last brew is highlighted so you can see exactly what you're changing. From here you can jump
/// straight into brewing the plan, or discard it.
struct NextPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var bean: Bean
    let method: BrewMethod
    /// Called when the user chooses to brew this plan now — the presenter starts a capture that
    /// seeds from this (freshly saved) plan.
    var onBrew: () -> Void

    @State private var draft: Recipe
    @State private var confirmingDiscard = false

    init(bean: Bean, method: BrewMethod, onBrew: @escaping () -> Void) {
        self.bean = bean
        self.method = method
        self.onBrew = onBrew
        _draft = State(initialValue: bean.pendingNextRecipe(for: method) ?? bean.seedRecipe(for: method))
    }

    /// The brew this plan is a change *from* — the newest brew of the same method.
    private var reference: Recipe? { bean.lastBrew(for: method)?.recipe }
    private var changes: [String] { reference.map { BrewDiff.changes(from: $0, to: draft) } ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        changeCard
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Plan", systemImage: "list.bullet.rectangle").font(.headline)
                            RecipeEditor(recipe: $draft, method: method)
                        }
                        .dripCard()
                    }
                    .padding(Theme.Space.m)
                }
                brewBar
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Next \(method.label)")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .selectAllWhenNumericFocused()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { confirmingDiscard = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Discard plan")
                }
            }
            .confirmationDialog("Discard this plan?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard plan", role: .destructive) { discard() }
                Button("Keep editing", role: .cancel) {}
            }
            // Autosave straight onto the bean's pending draft so the plan card stays in sync.
            .onChange(of: draft) { _, _ in persist() }
        }
    }

    /// The plan set against the brew it changes: the reference recipe with the planned delta
    /// highlighted, so "what am I actually changing?" is answerable at a glance.
    private var changeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Planning your next \(method.label.lowercased())", systemImage: "arrow.turn.down.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            if reference == nil {
                Text("No previous brew to compare against yet — set the dials you want to start from.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if changes.isEmpty {
                Text("Same as your last brew. Tweak a value below to plan a change.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Change from your last brew").overline()
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(changes, id: \.self) { Chip(text: $0, symbol: "arrow.right", tint: Theme.accent) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Planned changes: \(changes.joined(separator: ", "))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dripCard()
    }

    private var brewBar: some View {
        Button {
            persist()
            Haptics.tap()
            onBrew()
        } label: {
            Label("Brew this now", systemImage: method.symbol)
                .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.accent)
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func persist() {
        bean.setPendingNextRecipe(draft, for: method)
        bean.updatedAt = .now
    }

    private func discard() {
        bean.setPendingNextRecipe(nil, for: method)
        bean.updatedAt = .now
        Haptics.tap()
        dismiss()
    }
}
