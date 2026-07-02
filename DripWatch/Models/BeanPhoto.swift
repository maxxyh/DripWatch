import Foundation
import SwiftData

/// One bag photo belonging to a bean. A bean can have several — roasters often split the facts
/// across the front, back and sides of the bag — and all of them are OCR'd. `order` sets the
/// hero (lowest first). Stored outside the main store for size, like all photos. Sync-shaped.
@Model
final class BeanPhoto: Syncable {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var order: Int = 0
    @Attribute(.externalStorage) var data: Data?

    var bean: Bean?

    init(data: Data?, order: Int = 0) {
        self.data = data
        self.order = order
    }
}
