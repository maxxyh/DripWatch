import SwiftUI
import SwiftData

/// The shelf: a balanced two-column masonry of bean character cards. Primary entry point.
struct BeanListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bean.updatedAt, order: .reverse) private var beans: [Bean]
    @State private var addingBean = false
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                if activeBeans.isEmpty {
                    emptyState
                } else {
                    // Pin each column to exactly half the width so a wide card can never push the
                    // content past the viewport (which would let the shelf scroll sideways).
                    GeometryReader { geo in
                        let colWidth = max(0, (geo.size.width - Theme.Space.m * 2 - 14) / 2)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                masonry(shelfBeans, colWidth: colWidth)
                                if !finishedBeans.isEmpty {
                                    HStack {
                                        Text("Finished").font(.headline)
                                        Spacer()
                                        Text("\(finishedBeans.count)").font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    masonry(finishedBeans, colWidth: colWidth).opacity(0.6)
                                }
                            }
                            .padding(Theme.Space.m)
                        }
                    }
                }
            }
            .navigationTitle("Shelf")
            .navigationDestination(for: UUID.self) { id in
                if let bean = beans.first(where: { $0.id == id }) {
                    BeanDetailView(bean: bean)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        addingBean = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add bean")
                }
            }
            .sheet(isPresented: $addingBean) {
                AddBeanView()
            }
            #if DEBUG
            .onChange(of: activeBeans.map(\.id)) { _, _ in
                // DEBUG-only: jump straight to a brewed bean for verification/screenshots.
                guard path.isEmpty else { return }
                if UserDefaults.standard.bool(forKey: "openEspressoBean"),
                   let esp = activeBeans.first(where: { $0.timeline.contains { $0.method == .espresso } }) {
                    path = [esp.id]
                } else if UserDefaults.standard.bool(forKey: "openFirstBean"),
                          let target = activeBeans.first(where: { $0.brewCount > 0 }) ?? activeBeans.first {
                    path = [target.id]
                }
            }
            #endif
        }
        .tint(Theme.accent)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your shelf is empty", systemImage: "bag.fill")
        } description: {
            Text("Snap a coffee bag to start tracking how it brews.")
        } actions: {
            Button {
                Haptics.tap()
                addingBean = true
            } label: {
                Text("Add a bean").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var activeBeans: [Bean] { beans.filter { $0.deletedAt == nil } }
    private var shelfBeans: [Bean] { activeBeans.filter { !$0.isFinished } }
    private var finishedBeans: [Bean] { activeBeans.filter { $0.isFinished } }

    // MARK: Masonry

    /// Two columns, each bean greedily placed in the currently-shorter column (estimated from its
    /// content) so cards pack tightly instead of leaving the ragged row gaps a grid would.
    private func masonry(_ beans: [Bean], colWidth: CGFloat) -> some View {
        let split = balancedColumns(beans)
        return HStack(alignment: .top, spacing: 14) {
            column(split.left, colWidth: colWidth)
            column(split.right, colWidth: colWidth)
        }
    }

    private func column(_ beans: [Bean], colWidth: CGFloat) -> some View {
        VStack(spacing: 14) {
            ForEach(beans) { bean in
                NavigationLink(value: bean.id) {
                    BeanCardView(bean: bean, style: .shelf)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: colWidth, alignment: .top)
    }

    private func balancedColumns(_ beans: [Bean]) -> (left: [Bean], right: [Bean]) {
        var left: [Bean] = [], right: [Bean] = []
        var leftH: CGFloat = 0, rightH: CGFloat = 0
        for bean in beans {
            let h = estimatedHeight(bean)
            if leftH <= rightH { left.append(bean); leftH += h } else { right.append(bean); rightH += h }
        }
        return (left, right)
    }

    /// A rough height estimate — only the *relative* order matters for balancing the columns.
    private func estimatedHeight(_ bean: Bean) -> CGFloat {
        var h: CGFloat = 128 + 24 + 22   // photo + padding + name
        if bean.roasterName?.isEmpty == false { h += 16 }
        if bean.process?.isEmpty == false || bean.country?.isEmpty == false { h += 16 }
        h += CGFloat(min(bean.roasterNoteList.count, 3)) * 30
        return h
    }
}

#Preview {
    BeanListView()
        .modelContainer(for: [Bean.self, Brew.self, Grinder.self], inMemory: true)
}
