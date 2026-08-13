import Foundation
import Testing
@testable import DripWatch

@MainActor
struct SyncOutboxTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "SyncOutboxTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    @Test func survivesRecreation() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = SyncRecordKey(table: .beans, id: UUID())

        let first = SyncOutbox(defaults: defaults, storageKey: "outbox")
        first.record(key)

        let restored = SyncOutbox(defaults: defaults, storageKey: "outbox")
        #expect(restored.contains(key))
        #expect(restored.count == 1)
    }

    @Test func acknowledgeDoesNotClearANewerEdit() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = SyncRecordKey(table: .brews, id: UUID())
        let outbox = SyncOutbox(defaults: defaults, storageKey: "outbox")

        outbox.record(key)
        let inFlight = outbox.snapshot()
        outbox.record(key)
        outbox.acknowledge(inFlight)

        #expect(outbox.contains(key))
    }

    @Test func acknowledgeClearsTheSentGeneration() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = SyncRecordKey(table: .beanPhotos, id: UUID())
        let outbox = SyncOutbox(defaults: defaults, storageKey: "outbox")

        outbox.record(key)
        outbox.acknowledge(outbox.snapshot())

        #expect(outbox.isEmpty)
    }
}
