import Foundation
import SwiftData

enum BrewMethod: String, Codable, CaseIterable, Identifiable {
    case pourover
    case espresso
    var id: String { rawValue }
    var label: String { self == .pourover ? "Pourover" : "Espresso" }
    var symbol: String { self == .pourover ? "drop.fill" : "cup.and.saucer.fill" }
}

/// One brewing session: what we did (`recipe`), how it tasted (`taste`), and — drafted right
/// there while tasting — what to try next (`nextRecipeDraft`). Brews of a bean form a dated
/// chain; the draft is what the notebook's arrow points to.
@Model
final class Brew: Syncable {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    var brewedAt: Date = Date.now
    /// Stored as a raw string for sync simplicity; use `method` for typed access.
    var methodRaw: String = BrewMethod.pourover.rawValue
    var brewers: [String] = []

    var recipe: Recipe = Recipe()
    var taste: Taste = Taste()
    var nextRecipeDraft: Recipe?

    /// An optional shot of the result — latte art, the crema, the cup. Stored outside the main
    /// store for size, like the bag photo. Purely for the memory; nothing depends on it.
    var photoRemotePath: String? = nil
    @Attribute(.externalStorage) var photo: Data?

    var bean: Bean?

    init(brewedAt: Date = .now, method: BrewMethod = .pourover, recipe: Recipe = Recipe()) {
        self.brewedAt = brewedAt
        self.methodRaw = method.rawValue
        self.recipe = recipe
    }

    var method: BrewMethod {
        get { BrewMethod(rawValue: methodRaw) ?? .pourover }
        set { methodRaw = newValue.rawValue }
    }
}
