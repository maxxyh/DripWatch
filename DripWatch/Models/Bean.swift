import Foundation
import SwiftData

/// The hero entity. A bean is a character card: the facts a roaster prints on the bag plus
/// the bag photo itself, and the growing log of brews we've made with it. All attributes have
/// defaults and the relationship is optional — the shape CloudKit sync will require later.
@Model
final class Bean: Syncable {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?

    // Bag facts (all optional — the photo alone makes a good card).
    var name: String = ""
    var roasterName: String?
    var country: String?
    var region: String?
    var farm: String?
    var varietal: String?
    var process: String?
    var roastLevel: String?
    var roastDate: Date?
    var roasterNotes: String?
    var myFlavorTags: [String] = []

    /// The bag photo — the card's hero visual. Stored outside the main store for size.
    @Attribute(.externalStorage) var bagPhoto: Data?

    /// Drafts of the next brew's recipe, jotted while tasting — kept per method since espresso
    /// and pourover recipes are shaped differently. Seed the next brew of that method.
    var pendingNextPourover: Recipe?
    var pendingNextEspresso: Recipe?

    @Relationship(deleteRule: .cascade, inverse: \Brew.bean)
    var brews: [Brew] = []

    init(name: String = "") {
        self.name = name
    }

    /// Active brews, newest first — the history log.
    var timeline: [Brew] {
        brews.filter { $0.deletedAt == nil }.sorted { $0.brewedAt > $1.brewedAt }
    }

    var brewCount: Int { timeline.count }
    var lastBrew: Brew? { timeline.first }

    /// A friendly label for the "brews together" chip.
    var togetherLabel: String {
        switch brewCount {
        case 0: return "Not brewed yet"
        case 1: return "Brewed once"
        default: return "Brewed \(brewCount) times"
        }
    }

    // MARK: Per-method loop helpers

    func lastBrew(for method: BrewMethod) -> Brew? {
        timeline.first { $0.method == method }
    }

    func pendingNextRecipe(for method: BrewMethod) -> Recipe? {
        method == .espresso ? pendingNextEspresso : pendingNextPourover
    }

    func setPendingNextRecipe(_ recipe: Recipe?, for method: BrewMethod) {
        if method == .espresso { pendingNextEspresso = recipe } else { pendingNextPourover = recipe }
    }

    /// The recipe to start the next brew from: the pending draft for that method, else the last
    /// brew of that method, else empty.
    func seedRecipe(for method: BrewMethod) -> Recipe {
        pendingNextRecipe(for: method) ?? lastBrew(for: method)?.recipe ?? Recipe()
    }
}
