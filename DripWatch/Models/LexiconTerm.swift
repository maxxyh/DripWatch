import Foundation
import SwiftData

/// A term the user has taught us — "when you see this string again, it's a `field`". Written when
/// the user files an unrecognized OCR term into a category, so the bag scanner gets smarter with
/// use (the growing library the notebook never had). Sync-shaped like everything else.
@Model
final class LexiconTerm: Syncable {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    /// The matched text, stored lowercased for case-insensitive lookup.
    var term: String = ""
    /// Stored as a raw string for sync simplicity; use `field` for typed access.
    var fieldRaw: String = BagField.varietal.rawValue

    init(term: String = "", field: BagField = .varietal) {
        self.term = term.lowercased()
        self.fieldRaw = field.rawValue
    }

    var field: BagField {
        get { BagField(rawValue: fieldRaw) ?? .varietal }
        set { fieldRaw = newValue.rawValue }
    }
}
