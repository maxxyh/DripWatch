import Foundation

/// The bag field an OCR'd term belongs to. Drives both automatic classification (the seed
/// dictionary below) and the manual "file this term" chooser, and is the category we remember
/// when the user teaches us a term (see `LexiconTerm`).
enum BagField: String, Codable, CaseIterable, Identifiable {
    case name, roaster, country, region, farm, varietal, process, roastLevel, tastingNote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .roaster: return "Roaster"
        case .country: return "Country"
        case .region: return "Region"
        case .farm: return "Farm"
        case .varietal: return "Variety"
        case .process: return "Process"
        case .roastLevel: return "Roast level"
        case .tastingNote: return "Tasting note"
        }
    }

    var symbol: String {
        switch self {
        case .name: return "textformat"
        case .roaster: return "building.2"
        case .country: return "globe"
        case .region: return "map"
        case .farm: return "leaf"
        case .varietal: return "camera.macro"
        case .process: return "drop"
        case .roastLevel: return "flame"
        case .tastingNote: return "mouth"
        }
    }
}

/// A single automatically-recognized term and the field it maps to.
struct FieldMatch: Equatable {
    let field: BagField
    let value: String
}

/// A seed dictionary of common coffee terms — countries, varieties, processes, roast levels and
/// tasting notes — plus the logic that classifies a free-text OCR line by *what its words are*
/// rather than by an adjacent label. This is what lets a label-less blend bag ("Brazil Catuai
/// varietal, Natural") get filed correctly. Anything it can't place comes back as an "unknown"
/// for the user to file — and those choices are then remembered (see `LexiconTerm`).
enum CoffeeLexicon {

    // Single-word terms, lowercased.
    static let countries: Set<String> = [
        "brazil", "colombia", "ethiopia", "kenya", "guatemala", "panama", "honduras",
        "nicaragua", "peru", "bolivia", "ecuador", "mexico", "rwanda", "burundi", "tanzania",
        "uganda", "yemen", "india", "indonesia", "sumatra", "java", "sulawesi", "vietnam",
        "china", "thailand", "myanmar", "laos", "congo", "malawi", "zambia", "timor", "cuba",
        "jamaica", "hawaii", "philippines",
    ]

    static let multiWordCountries: [String] = [
        "costa rica", "el salvador", "papua new guinea", "new guinea", "dr congo", "democratic republic",
    ]

    static let varietals: Set<String> = [
        "catuai", "caturra", "bourbon", "typica", "gesha", "geisha", "heirloom", "pacamara",
        "pacas", "castillo", "catimor", "tabi", "maragogipe", "ruiru", "batian", "kent",
        "wush wush", "sidra", "chiroso", "obata", "marsellesa", "parainema", "icatu", "laurina",
        "mokka", "sl28", "sl34", "s795", "pache", "mundo", "tha1", "sudan", "rume",
    ]

    static let multiWordVarietals: [String] = [
        "pink bourbon", "red bourbon", "yellow bourbon", "villa sarchi", "mundo novo",
        "sudan rume", "wush wush", "sl 28", "sl 34", "java varietal",
    ]

    // Ordered longest-first so "medium-dark" wins over "medium".
    static let processes: [String] = [
        "anaerobic natural", "natural anaerobic", "anoxic natural", "carbonic maceration",
        "double fermented", "wet hulled", "washed", "natural", "honey", "anaerobic", "anoxic",
        "fermented", "pulped",
    ]

    static let roastLevels: [String] = [
        "extra dark", "medium-dark", "medium dark", "medium-light", "medium light",
        "medium", "light", "dark", "blonde", "cinnamon",
    ]

    static let tastingNotes: Set<String> = [
        "chocolate", "cocoa", "caramel", "nutty", "nut", "hazelnut", "almond", "nuttiness",
        "vanilla", "honey", "floral", "jasmine", "citrus", "orange", "lemon", "lime",
        "berry", "blueberry", "strawberry", "raspberry", "cherry", "plum", "peach", "apricot",
        "apple", "grape", "raisin", "date", "fig", "mango", "pineapple", "guava", "tropical",
        "tangerine", "blackberry", "mandarin", "lychee", "melon", "papaya", "passionfruit",
        "molasses", "toffee", "brown sugar", "maple", "malt", "spice", "cinnamon", "clove",
        "black tea", "bergamot", "wine", "winey", "juicy", "creamy", "buttery", "milk chocolate",
        "dark chocolate", "stone fruit", "red fruit",
    ]

    /// Words that carry no field information on their own (labels/qualifiers/brew methods) — kept
    /// out of the "unknown" pile so the manual chooser only shows terms worth filing.
    static let noise: Set<String> = [
        "varietal", "variety", "var", "process", "processed", "processing", "roast", "roasted",
        "beans", "bean", "coffee", "blend", "single", "origin", "the", "and", "of", "with",
        "notes", "espresso", "filter", "specialty", "arabica", "robusta", "mix", "medium",
    ]

    /// Classify one comma-segment of an OCR line against learned terms first, then the seed
    /// dictionary. Returns the fields it could place plus any leftover meaningful text.
    static func classifySegment(_ raw: String, learned: [String: BagField] = [:]) -> (matches: [FieldMatch], unknowns: [String]) {
        let segment = raw.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-–"))
        let lower = segment.lowercased()
        guard segment.count >= 2 else { return ([], []) }

        // 1. Learned whole-segment match wins outright.
        if let field = learned[lower] { return ([FieldMatch(field: field, value: cleaned(segment))], []) }

        // A "Finca …" / "Hacienda …" / "… Estate" segment is a farm.
        if lower.hasPrefix("finca") || lower.hasPrefix("hacienda") || lower.contains(" estate") {
            return ([FieldMatch(field: .farm, value: cleaned(segment))], [])
        }

        var matches: [FieldMatch] = []

        // 2. Multi-word phrases (checked before single tokens so "pink bourbon" beats "bourbon").
        for c in multiWordCountries where lower.contains(c) { matches.append(FieldMatch(field: .country, value: titleCased(c))) }
        for v in multiWordVarietals where lower.contains(v) { matches.append(FieldMatch(field: .varietal, value: titleCased(v))) }

        // 3. Roast level + process phrases (longest first).
        if let r = roastLevels.first(where: { lower.contains($0) }) { matches.append(FieldMatch(field: .roastLevel, value: titleCased(r))) }
        if let p = processes.first(where: { lower.contains($0) }) { matches.append(FieldMatch(field: .process, value: titleCased(p))) }

        // 4. Single-token scan for countries and varieties (country wins ambiguous names).
        for token in tokens(in: segment) {
            let t = token.lowercased()
            if let field = learned[t] { matches.append(FieldMatch(field: field, value: cleaned(token))) }
            // Countries are proper place names — title-case them ("VIETNAM" → "Vietnam") so the
            // filled field reads consistently regardless of the bag's ALL-CAPS printing.
            else if countries.contains(t) { matches.append(FieldMatch(field: .country, value: cleaned(token).capitalized)) }
            else if varietals.contains(t) { matches.append(FieldMatch(field: .varietal, value: cleaned(token))) }
        }

        // 5. Fall back to a tasting note if the whole segment reads like one.
        if matches.isEmpty, tastingNotes.contains(where: { lower.contains($0) }) {
            matches.append(FieldMatch(field: .tastingNote, value: cleaned(segment)))
        }

        // 6. Anything left that's meaningful becomes an "unknown" to file manually.
        var unknowns: [String] = []
        if matches.isEmpty, isMeaningful(segment) { unknowns.append(cleaned(segment)) }

        return (deduped(matches), unknowns)
    }

    /// True if the text mentions any known flavour. Used to keep collecting wrapped tasting-note
    /// lines even when another word (e.g. a roast level like "dark" in "dark chocolate aftertaste")
    /// would otherwise shadow the flavour in `classifySegment`.
    static func hasTastingNote(_ text: String) -> Bool {
        let l = text.lowercased()
        return tastingNotes.contains { l.contains($0) }
    }

    // MARK: Helpers

    private static func tokens(in s: String) -> [String] {
        s.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 2 }
    }

    /// A segment worth surfacing: more than noise, not purely numeric, not a bare qualifier.
    private static func isMeaningful(_ s: String) -> Bool {
        let ts = tokens(in: s)
        guard !ts.isEmpty else { return false }
        let allNoise = ts.allSatisfy { noise.contains($0.lowercased()) }
        let allNumeric = ts.allSatisfy { $0.allSatisfy(\.isNumber) }
        return !allNoise && !allNumeric && s.count <= 40
    }

    /// Drop duplicates and same-field values that are substrings of a longer match (so we keep
    /// "Pink Bourbon" and drop the bare "Bourbon" it contains).
    private static func deduped(_ matches: [FieldMatch]) -> [FieldMatch] {
        var out: [FieldMatch] = []
        for m in matches {
            if out.contains(where: { $0.field == m.field && $0.value.caseInsensitiveCompare(m.value) == .orderedSame }) { continue }
            out.removeAll { $0.field == m.field && m.value.lowercased().contains($0.value.lowercased()) }
            if out.contains(where: { $0.field == m.field && $0.value.lowercased().contains(m.value.lowercased()) }) { continue }
            out.append(m)
        }
        return out
    }

    private static func cleaned(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-–"))
    }

    private static func titleCased(_ s: String) -> String {
        s.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
