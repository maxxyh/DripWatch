import Foundation

/// The single entry point for turning a bag's OCR'd lines into a `ParsedBag`.
///
/// Bag layouts vary enormously and reading them well is a semantic task — "these unfamiliar words
/// sound like a name", "that's a country", "those are tasting notes". That's what an LLM does
/// natively, so when Apple's on-device model is available we use it as the primary parser and keep
/// the heuristic `BagOCR.parse` as the fallback (unsupported devices, older OS, model downloading,
/// or Apple Intelligence turned off).
///
/// The AI path lives behind `#if canImport(FoundationModels)` so this compiles unchanged on the
/// current SDK — it's dormant until the project moves to the iOS 26 / Xcode 26 toolchain, at which
/// point `AIBagParser` activates with no other changes here.
enum BagParser {

    static func parse(_ lines: [OCRLine], learned: [String: BagField] = [:]) async -> ParsedBag {
        let heuristic = BagOCR.parse(lines, learned: learned)

        #if canImport(FoundationModels)
        if #available(iOS 26, *), let ai = await AIBagParser.parse(texts: lines.map(\.text), learned: learned) {
            return merged(ai: ai, heuristic: heuristic)
        }
        #endif

        return heuristic
    }

    #if canImport(FoundationModels)
    /// Prefer the model's fields, but fall back to the heuristic for anything it left blank, and
    /// keep the heuristic's raw lines / unresolved terms so the "file unknowns" UI still works.
    @available(iOS 26, *)
    private static func merged(ai: ParsedBag, heuristic h: ParsedBag) -> ParsedBag {
        var bag = ai
        bag.name = bag.name ?? h.name
        bag.roaster = bag.roaster ?? h.roaster
        bag.country = bag.country ?? h.country
        bag.region = bag.region ?? h.region
        bag.farm = bag.farm ?? h.farm
        bag.varietal = bag.varietal ?? h.varietal
        bag.process = bag.process ?? h.process
        bag.roastLevel = bag.roastLevel ?? h.roastLevel
        bag.roasterNotes = bag.roasterNotes ?? h.roasterNotes
        bag.rawLines = h.rawLines
        bag.unresolved = bag.unresolved.isEmpty ? h.unresolved : bag.unresolved
        return bag
    }
    #endif
}
