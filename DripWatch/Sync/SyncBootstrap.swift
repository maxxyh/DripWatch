import Foundation
import SwiftData

@MainActor
enum SyncBootstrap {
    static let completionKey = "dripwatch.sync.bootstrap.v1"

    static func prepareIfNeeded(
        context: ModelContext,
        outbox requestedOutbox: SyncOutbox? = nil,
        defaults: UserDefaults = .standard
    ) throws {
        let outbox = requestedOutbox ?? .shared
        guard !defaults.bool(forKey: completionKey) else { return }

        let beans = try context.fetch(FetchDescriptor<Bean>())
        let photos = try context.fetch(FetchDescriptor<BeanPhoto>())
        let brews = try context.fetch(FetchDescriptor<Brew>())
        let grinders = try context.fetch(FetchDescriptor<Grinder>())
        let terms = try context.fetch(FetchDescriptor<LexiconTerm>())

        // Fold the old one-photo field into the syncable gallery exactly once. Keep the
        // legacy bytes until the new row has been saved so a failed migration loses nothing.
        for bean in beans where bean.bagPhoto != nil && bean.photos.isEmpty {
            let photo = BeanPhoto(data: bean.bagPhoto, order: 0)
            photo.bean = bean
            context.insert(photo)
            outbox.record(SyncRecordKey(photo))
            bean.bagPhoto = nil
        }

        // Existing installations push first. A fresh installation has no rows and therefore
        // pulls first, preventing an empty local store from erasing anything remotely.
        for bean in beans { outbox.record(SyncRecordKey(bean)) }
        for photo in photos { outbox.record(SyncRecordKey(photo)) }
        for brew in brews { outbox.record(SyncRecordKey(brew)) }
        for grinder in grinders { outbox.record(SyncRecordKey(grinder)) }
        for term in terms { outbox.record(SyncRecordKey(term)) }

        try context.save()
    }

    static func markComplete(
        outbox requestedOutbox: SyncOutbox? = nil,
        defaults: UserDefaults = .standard
    ) {
        let outbox = requestedOutbox ?? .shared
        guard outbox.isEmpty else { return }
        defaults.set(true, forKey: completionKey)
    }
}
