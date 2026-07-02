import SwiftUI
import SwiftData

@main
struct DripWatchApp: App {
    /// Shared SwiftData container. Local-first today; the schema is written to be
    /// sync-ready (stable ids, updatedAt, soft-delete) so CloudKit can be switched on later.
    let container: ModelContainer = {
        let schema = Schema([
            Bean.self,
            BeanPhoto.self,
            Brew.self,
            Grinder.self,
            LexiconTerm.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            BeanListView()
                .task { SampleData.seedIfRequested(container.mainContext) }
        }
        .modelContainer(container)
    }
}
