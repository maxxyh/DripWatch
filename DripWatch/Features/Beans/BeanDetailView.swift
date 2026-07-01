import SwiftUI
import SwiftData

/// A bean's home: its character card, the pending "next brew" plan, a prominent brew action,
/// and the full history log below.
struct BeanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var bean: Bean

    @State private var captureMethod: BrewMethod?
    @State private var confirmingDelete = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 16) {
                BeanCardView(bean: bean, style: .full)

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
                    BrewHistoryView(brews: bean.timeline, onDelete: delete)
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
        .confirmationDialog("Delete this bean and all its brews?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteBean() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func nextPlanCard(_ next: Recipe, method: BrewMethod) -> some View {
        Button {
            Haptics.tap()
            captureMethod = method
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("Plan for next \(method.label.lowercased())", systemImage: "arrow.turn.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
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
        .accessibilityHint("Starts a new \(method.label.lowercased()) from this plan")
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
        brew.deletedAt = .now
        brew.updatedAt = .now
        bean.updatedAt = .now
    }

    private func deleteBean() {
        bean.deletedAt = .now
        bean.updatedAt = .now
        Haptics.success()
        dismiss()
    }
}
