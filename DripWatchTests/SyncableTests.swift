import Foundation
import Testing
@testable import DripWatch

@MainActor
struct SyncableTests {
    @Test func mapsEachModelToItsSyncTable() {
        #expect(SyncRecordKey(Bean()).table == .beans)
        #expect(SyncRecordKey(Brew()).table == .brews)
        #expect(SyncRecordKey(BeanPhoto(data: nil)).table == .beanPhotos)
        #expect(SyncRecordKey(Grinder()).table == .grinders)
        #expect(SyncRecordKey(LexiconTerm()).table == .lexiconTerms)
    }

    @Test func markDirtyUpdatesTimestampAndOutbox() {
        let brew = Brew()
        brew.updatedAt = Date(timeIntervalSince1970: 0)

        brew.markDirty()

        #expect(brew.updatedAt > Date(timeIntervalSince1970: 0))
        #expect(SyncOutbox.shared.contains(SyncRecordKey(brew)))
    }

    @Test func softDeleteSetsDeletionTimestampAndMarksTheRecord() {
        let photo = BeanPhoto(data: nil)
        photo.updatedAt = Date(timeIntervalSince1970: 0)

        photo.softDelete()

        #expect(photo.deletedAt != nil)
        #expect(photo.updatedAt > Date(timeIntervalSince1970: 0))
        #expect(SyncOutbox.shared.contains(SyncRecordKey(photo)))
    }
}
