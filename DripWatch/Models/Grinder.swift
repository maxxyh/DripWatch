import Foundation
import SwiftData

/// A grinder the user owns. Kept lightweight: a name and, optionally, how many clicks make
/// up one `major` step (so grind deltas can be computed across different major settings).
@Model
final class Grinder: Syncable {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var name: String = ""

    init(name: String = "") {
        self.name = name
    }
}
