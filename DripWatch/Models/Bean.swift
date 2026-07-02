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

    /// Legacy single hero photo. Superseded by `photos` (multiple bag surfaces); kept so existing
    /// beans keep their shot, and folded into `photoDatas` as a fallback. Migrated into `photos`
    /// the next time the bean is edited.
    @Attribute(.externalStorage) var bagPhoto: Data?

    /// Bag photos — some roasters print facts across several surfaces, so a bean can hold a
    /// gallery. The first (by `order`) is the card's hero visual; all are OCR'd together.
    @Relationship(deleteRule: .cascade, inverse: \BeanPhoto.bean)
    var photos: [BeanPhoto] = []

    /// Drafts of the next brew's recipe, jotted while tasting — kept per method since espresso
    /// and pourover recipes are shaped differently. Seed the next brew of that method.
    var pendingNextPourover: Recipe?
    var pendingNextEspresso: Recipe?

    @Relationship(deleteRule: .cascade, inverse: \Brew.bean)
    var brews: [Brew] = []

    init(name: String = "") {
        self.name = name
    }

    /// Roaster's printed tasting notes as individual chips (stored comma-joined). The roaster's
    /// notes are a tasting reference maxx leans on, so they render as chips across the app.
    var roasterNoteList: [String] {
        (roasterNotes ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Active photos, hero first. Empty relationship falls back to the legacy `bagPhoto`.
    var orderedPhotos: [BeanPhoto] {
        photos.filter { $0.deletedAt == nil && $0.data != nil }.sorted { $0.order < $1.order }
    }

    /// Every bag image as raw data, hero first — the gallery, with legacy fallback.
    var photoDatas: [Data] {
        let list = orderedPhotos.compactMap(\.data)
        if !list.isEmpty { return list }
        if let bagPhoto { return [bagPhoto] }
        return []
    }

    /// The hero visual — first gallery photo, else the legacy single photo.
    var primaryPhotoData: Data? { photoDatas.first }

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
    /// brew of that method, else a method-appropriate default (pourover gets sensible dials so
    /// you're not typing temp/bloom/drawdown from zero every time).
    func seedRecipe(for method: BrewMethod) -> Recipe {
        if let pending = pendingNextRecipe(for: method) { return pending }
        if let last = lastBrew(for: method)?.recipe { return last }
        return method == .pourover ? .newPourover() : Recipe()
    }

    /// Whole days elapsed since the roast date (0 = roasted today). Nil when no roast date.
    var daysSinceRoast: Int? {
        guard let roastDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: roastDate),
                                  to: cal.startOfDay(for: .now)).day
    }
}
