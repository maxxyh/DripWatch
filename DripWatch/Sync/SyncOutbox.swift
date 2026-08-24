import Foundation

/// The server table and stable model id that identify one syncable row.
enum SyncTable: String, Codable, CaseIterable, Sendable {
    case beans
    case brews
    case beanPhotos = "bean_photos"
    case grinders
    case lexiconTerms = "lexicon_terms"
}

struct SyncRecordKey: Hashable, Codable, Sendable {
    let table: SyncTable
    let id: UUID
}

/// A tiny durable journal of rows that still need to reach Supabase.
///
/// Each touch receives a generation. A sync acknowledges only the exact generation it sent,
/// so an edit made while a request is in flight remains pending for the next cycle.
@MainActor
final class SyncOutbox {
    private struct Entry: Codable {
        let key: SyncRecordKey
        let generation: UInt64
    }

    private struct PersistedState: Codable {
        var nextGeneration: UInt64 = 1
        var entries: [Entry] = []
    }

    /// Fixture launches must not persist UUIDs from their in-memory store into the production
    /// journal. `markDirty()` always targets this shared outbox, so isolation belongs here too.
    static let shared = SyncOutbox(isRecordingEnabled: !SampleData.isRequested)

    private let defaults: UserDefaults
    private let storageKey: String
    private let isRecordingEnabled: Bool
    private var nextGeneration: UInt64
    private var pending: [SyncRecordKey: UInt64]
    var onRecord: (() -> Void)?

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dripwatch.sync.outbox.v1",
        isRecordingEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.isRecordingEnabled = isRecordingEnabled

        if let data = defaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            nextGeneration = max(state.nextGeneration, 1)
            pending = Dictionary(
                state.entries.map { ($0.key, $0.generation) },
                uniquingKeysWith: max
            )
        } else {
            nextGeneration = 1
            pending = [:]
        }
    }

    @discardableResult
    func record(_ key: SyncRecordKey) -> UInt64 {
        guard isRecordingEnabled else { return 0 }
        let generation = nextGeneration
        nextGeneration &+= 1
        if nextGeneration == 0 { nextGeneration = 1 }
        pending[key] = generation
        persist()
        onRecord?()
        return generation
    }

    /// A stable batch token. Callers retain this while awaiting the network.
    func snapshot() -> [SyncRecordKey: UInt64] {
        pending
    }

    func contains(_ key: SyncRecordKey) -> Bool {
        pending[key] != nil
    }

    var isEmpty: Bool { pending.isEmpty }
    var count: Int { pending.count }

    /// Remove only rows that have not been edited again since `batch` was captured.
    func acknowledge(_ batch: [SyncRecordKey: UInt64]) {
        for (key, sentGeneration) in batch where pending[key] == sentGeneration {
            pending.removeValue(forKey: key)
        }
        persist()
    }

    private func persist() {
        let entries = pending
            .map { Entry(key: $0.key, generation: $0.value) }
            .sorted {
                if $0.key.table.rawValue != $1.key.table.rawValue {
                    return $0.key.table.rawValue < $1.key.table.rawValue
                }
                return $0.key.id.uuidString < $1.key.id.uuidString
            }
        let state = PersistedState(nextGeneration: nextGeneration, entries: entries)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
