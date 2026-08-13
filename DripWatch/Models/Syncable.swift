import Foundation

/// Every persisted model carries these fields so that turning on multi-user sync
/// (CloudKit now, a real backend later) is additive rather than a rewrite:
/// a stable `id`, an `updatedAt` for last-writer-wins, and a soft-delete via
/// `deletedAt` (nil == active) so a delete on one device can propagate cleanly.
protocol Syncable: AnyObject {
    static var syncTable: SyncTable { get }
    var id: UUID { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

extension Syncable {
    var isActive: Bool { deletedAt == nil }

    @MainActor
    func markDirty() {
        updatedAt = .now
        SyncOutbox.shared.record(SyncRecordKey(self))
    }

    @MainActor
    func softDelete() {
        deletedAt = .now
        markDirty()
    }
}

extension SyncRecordKey {
    init<T: Syncable>(_ record: T) {
        self.init(table: T.syncTable, id: record.id)
    }
}

extension Bean {
    static let syncTable: SyncTable = .beans
}

extension Brew {
    static let syncTable: SyncTable = .brews
}

extension BeanPhoto {
    static let syncTable: SyncTable = .beanPhotos
}

extension Grinder {
    static let syncTable: SyncTable = .grinders
}

extension LexiconTerm {
    static let syncTable: SyncTable = .lexiconTerms
}
