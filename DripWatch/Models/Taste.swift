import Foundation

/// The dot-scale balance printed on specialty bags (Acidity ●●●●○○○). Each axis is 0…5,
/// optional so you can skip it entirely. Mirrors the roaster-card visual language.
struct TasteBalance: Codable, Hashable {
    var acidity: Int?
    var sweetness: Int?
    var bitterness: Int?
    var body: Int?

    var isEmpty: Bool { acidity == nil && sweetness == nil && bitterness == nil && body == nil }
}

/// Tasting notes, kept as terse as the notebook: `(+)` and `(−)` chips, an optional
/// dot-scale balance, and an optional overall rating.
struct Taste: Codable, Hashable {
    var positives: [String] = []
    var negatives: [String] = []
    var balance: TasteBalance = TasteBalance()
    /// Optional overall rating, 1…5.
    var rating: Int?
    /// Optional free-text impression — the nuance/context the +/− chips can't hold
    /// ("opened up as it cooled", "sweet finish but short").
    var note: String?

    init() {}

    var isEmpty: Bool {
        positives.isEmpty && negatives.isEmpty && balance.isEmpty && rating == nil
            && (note?.isEmpty ?? true)
    }
}
