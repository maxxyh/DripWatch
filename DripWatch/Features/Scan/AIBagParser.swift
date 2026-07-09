#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The structured shape the on-device model is constrained to produce (guided generation). Each
/// `@Guide` tells the model what the field means — the same distinctions a person makes reading a
/// bag: the *name* is the specific coffee/lot, distinct from the *roaster* brand; unfamiliar places
/// are origin; evocative food words are flavours.
@available(iOS 26, *)
@Generable
struct GeneratedBag {
    @Guide(description: "The coffee's own name or lot — NOT the roaster brand or the country. Unfamiliar proper nouns are usually this. Blank if there isn't one.")
    var name: String?
    @Guide(description: "The roaster or brand name (the company that roasted it).")
    var roaster: String?
    @Guide(description: "Country of origin, e.g. Ethiopia, Colombia.")
    var country: String?
    @Guide(description: "Region, zone, or town within the country.")
    var region: String?
    @Guide(description: "Farm, producer, estate, or washing station (e.g. 'Finca Varietales', a producer's name).")
    var farm: String?
    @Guide(description: "Coffee variety/varietal — a cultivar name (Geisha, Bourbon, SL-34) or a numeric selection code (e.g. 74158).")
    var varietal: String?
    @Guide(description: "Processing method, e.g. Washed, Natural, Anaerobic Natural, Honey.")
    var process: String?
    @Guide(description: "Roast level or roast style if stated, e.g. Medium, Filter, Espresso.")
    var roastLevel: String?
    @Guide(description: "Tasting / flavour notes, as separate items, e.g. Tangerine, Pink Peach, Bergamot.")
    var tastingNotes: [String]
}

/// Parses a bag by handing its OCR'd text to Apple's on-device model. Returns nil when the model is
/// unavailable (so `BagParser` falls back to the heuristic) or the request fails.
///
/// NOTE: written against the WWDC25 Foundation Models API. Verify signatures against the shipping
/// SDK when the project moves to Xcode 26 — the surface (LanguageModelSession / respond(generating:))
/// may have shifted.
@available(iOS 26, *)
enum AIBagParser {

    static func parse(texts: [String], learned: [String: BagField]) async -> ParsedBag? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        guard !texts.isEmpty else { return nil }

        let learnedHints = learned.isEmpty ? "" : "\n\nThe user has previously told you: "
            + learned.map { "'\($0.key)' is a \($0.value.label.lowercased())" }.joined(separator: "; ") + "."

        let instructions = Instructions("""
        You extract structured fields from the raw text OCR'd off a coffee bag. The lines arrive in \
        an arbitrary order, are often unlabelled, and may contain OCR noise. Infer each field from \
        meaning, the way a coffee person would: recognizable places are the origin (country/region); \
        a "Finca"/estate/producer name is the farm; evocative food, fruit, or floral words are \
        tasting notes; an unfamiliar proper noun is usually the coffee's name; the roaster is the \
        brand. Leave a field blank if the bag doesn't state it — never invent values.\(learnedHints)
        """)

        do {
            let session = LanguageModelSession(instructions: instructions)
            let prompt = "Coffee bag text:\n" + texts.joined(separator: "\n")
            let generated = try await session.respond(to: prompt, generating: GeneratedBag.self).content

            var bag = ParsedBag()
            bag.name = generated.name?.nilIfBlank
            bag.roaster = generated.roaster?.nilIfBlank
            bag.country = generated.country?.nilIfBlank
            bag.region = generated.region?.nilIfBlank
            bag.farm = generated.farm?.nilIfBlank
            bag.varietal = generated.varietal?.nilIfBlank
            bag.process = generated.process?.nilIfBlank
            bag.roastLevel = generated.roastLevel?.nilIfBlank
            let notes = generated.tastingNotes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            bag.roasterNotes = notes.isEmpty ? nil : notes.joined(separator: ", ")
            bag.rawLines = texts
            return bag
        } catch {
            return nil
        }
    }
}
#endif
