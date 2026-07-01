import SwiftUI
import SwiftData

/// The shelf: a two-column grid of bean character cards. Primary entry point of the app.
struct BeanListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bean.updatedAt, order: .reverse) private var beans: [Bean]
    @State private var addingBean = false
    @State private var path: [UUID] = []

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                if activeBeans.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(activeBeans) { bean in
                                NavigationLink(value: bean.id) {
                                    BeanCardView(bean: bean, style: .shelf)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Space.m)
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
}

#Preview {
    BeanListView()
        .modelContainer(for: [Bean.self, Brew.self, Grinder.self], inMemory: true)
}
