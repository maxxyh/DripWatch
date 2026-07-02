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

    /// A stepless grinder (worm-drive, e.g. DF54) is dialled to a continuous number rather than
    /// counted in clicks — the picker offers a ruler + decimal instead of a dial + click offset.
    var stepless: Bool = false

    init(name: String = "", stepless: Bool = false) {
        self.name = name
        self.stepless = stepless
    }
}
