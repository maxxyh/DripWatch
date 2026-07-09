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
            // The on-disk store couldn't be opened — usually a store left inconsistent by a crash
            // (or an incompatible migration). Rather than fatal-crashing on every launch forever,
            // move the bad store aside (kept for recovery/inspection) and start fresh, so the app
            // is usable again. Local-first for now, so this is an acceptable last resort.
            print("⚠️ ModelContainer failed to open: \(error)\nRelocating store and retrying.")
            relocateStore(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("ModelContainer failed even after relocating the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            BeanListView()
                .task {
                    SampleData.seedIfRequested(container.mainContext)
                    DataMaintenance.normalizeExistingIfNeeded(container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

/// Move a store (and its `-wal`/`-shm` sidecars) aside so a corrupt store can't brick launch.
/// The files are renamed (not deleted), so the data is preserved on disk for later recovery.
private func relocateStore(at url: URL) {
    let fm = FileManager.default
    let stamp = Int(Date.now.timeIntervalSince1970)
    for suffix in ["", "-wal", "-shm"] {
        let source = URL(fileURLWithPath: url.path + suffix)
        guard fm.fileExists(atPath: source.path) else { continue }
        let destination = URL(fileURLWithPath: url.path + suffix + ".corrupt-\(stamp)")
        try? fm.moveItem(at: source, to: destination)
    }
}
