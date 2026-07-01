import Foundation

/// Every persisted model carries these fields so that turning on multi-user sync
/// (CloudKit now, a real backend later) is additive rather than a rewrite:
/// a stable `id`, an `updatedAt` for last-writer-wins, and a soft-delete via
/// `deletedAt` (nil == active) so a delete on one device can propagate cleanly.
protocol Syncable {
    var id: UUID { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

extension Syncable {
    var isActive: Bool { deletedAt == nil }
}
