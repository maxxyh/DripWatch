import SwiftUI
import SwiftData

/// A bean's home: its character card, the pending "next brew" plan, a prominent brew action,
/// and the full history log below.
struct BeanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var bean: Bean

    @State private var captureMethod: BrewMethod?
    @State private var editingBrew: Brew?
    @State private var editingPlan: BrewMethod?
    /// Set when the plan editor asks to start a brew; launched after that sheet dismisses so we
    /// never present two sheets at once.
    @State private var pendingBrewMethod: BrewMethod?
    @State private var editingBean = false
    @State private var confirmingDelete = false
    @State private var preview: PreviewPhoto?

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 16) {
                BeanCardView(bean: bean, style: .full, onTapPhoto: {
                    if !bean.photoDatas.isEmpty { preview = PreviewPhoto(datas: bean.photoDatas) }
                })

                if let next = bean.pendingNextPourover {
                    nextPlanCard(next, method: .pourover)
                }
                if let next = bean.pendingNextEspresso {
                    nextPlanCard(next, method: .espresso)
                }

                brewButtons

                if bean.timeline.isEmpty {
                    emptyHistory
                } else {
                    HStack {
                        Text("History").font(.title3.bold())
                        Spacer()
                        Text(bean.togetherLabel).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .id("history")
                    BrewHistoryView(brews: bean.timeline,
                                    onEdit: { editingBrew = $0 },
                                    onDelete: delete,
                                    onTapPhoto: { preview = PreviewPhoto(data: $0) })
                }
            }
            .padding(Theme.Space.m)
        }
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "scrollToHistory") {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation { proxy.scrollTo("history", anchor: .top) }
            }
            if UserDefaults.standard.bool(forKey: "openBrewSheet") {
                try? await Task.sleep(for: .milliseconds(300))
                captureMethod = UserDefaults.standard.bool(forKey: "openEspressoBean") ? .espresso : .pourover
            }
        }
        #endif
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(bean.name.isEmpty ? "Bean" : bean.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { Haptics.tap(); editingBean = true } label: {
                        Label("Edit bean", systemImage: "pencil")
                    }
                    Button { toggleFinished() } label: {
                        Label(bean.isFinished ? "Reopen bean" : "Mark as finished",
                              systemImage: bean.isFinished ? "arrow.uturn.backward" : "checkmark.seal")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete bean", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Bean options")
            }
        }
        .sheet(item: $captureMethod) { method in
            BrewCaptureView(bean: bean, method: method)
        }
        .sheet(item: $editingBrew) { brew in
            BrewCaptureView(bean: bean, editing: brew)
        }
        .sheet(item: $editingPlan, onDismiss: {
            if let method = pendingBrewMethod { pendingBrewMethod = nil; captureMethod = method }
        }) { method in
            NextPlanEditor(bean: bean, method: method) {
                // Brew from the plan: remember the choice, close this sheet, then the onDismiss
                // above opens the capture (seeded from the plan we just saved).
                pendingBrewMethod = method
                editingPlan = nil
            }
        }
        .sheet(isPresented: $editingBean) {
            AddBeanView(editing: bean)
        }
        .confirmationDialog("Delete this bean and all its brews?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteBean() }
            Button("Cancel", role: .cancel) {}
        }
        .photoViewer($preview)
    }

    private func nextPlanCard(_ next: Recipe, method: BrewMethod) -> some View {
        // The delta vs. the last brew, so "what am I changing?" is answerable at a glance —
        // right on the card, without opening the editor.
        let changes = bean.lastBrew(for: method).map { BrewDiff.changes(from: $0.recipe, to: next) } ?? []
        return Button {
            Haptics.tap()
            editingPlan = method
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Plan for next \(method.label.lowercased())", systemImage: "arrow.turn.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.footnote).foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Change from your last brew").overline()
                        WrapLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(changes, id: \.self) { Chip(text: $0, symbol: "arrow.right", tint: Theme.accent) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Change from your last brew: \(changes.joined(separator: ", "))")
                }
                RecipeReadout(recipe: next)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.m)
            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit this plan, or brew from it")
    }

    private var brewButtons: some View {
        HStack(spacing: 12) {
            // Pourover is the primary action (filled red); espresso is a secondary (bordered).
            Button {
                Haptics.tap(); captureMethod = .pourover
            } label: {
                Label("Pourover", systemImage: BrewMethod.pourover.symbol)
                    .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.accent)

            Button {
                Haptics.tap(); captureMethod = .espresso
            } label: {
                Label("Espresso", systemImage: BrewMethod.espresso.symbol)
                    .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 46)
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.secondary)
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 6) {
            Image(systemName: "cup.and.saucer").font(.title).foregroundStyle(Theme.crema)
            Text("No brews yet").font(.headline)
            Text("Log your first brew to start the loop.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
    }

    /// Soft-delete a brew (sync-friendly), then refresh the pending plan.
    private func delete(_ brew: Brew) {
        Haptics.tap()
        brew.softDelete()
        bean.markDirty()
    }

    /// Mark the bag finished (or reopen it) — it moves to the shelf's Finished section, kept.
    private func toggleFinished() {
        bean.finishedAt = bean.isFinished ? nil : .now
        bean.markDirty()
        Haptics.success()
    }

    private func deleteBean() {
        for brew in bean.brews where brew.isActive {
            brew.softDelete()
        }
        for photo in bean.photos where photo.isActive {
            photo.softDelete()
        }
        bean.softDelete()
        Haptics.success()
        dismiss()
    }
}
