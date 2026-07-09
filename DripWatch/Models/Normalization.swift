import Foundation
import SwiftData

extension String {
    /// Title-case for display consistency, preserving codes and acronyms so coffee terms survive:
    /// any token containing a digit (SL-34, THA1, S795, USDA 762) or a short all-caps acronym
    /// (SL, USDA) keeps its case; everything else is Title Cased. Applied to bean facts and tasting
    /// notes — but NEVER to the roaster name (brands keep their own casing).
    var normalizedTerm: String {
        split(separator: " ", omittingEmptySubsequences: true)
            .map { word in
                word.split(separator: "-", omittingEmptySubsequences: false)
                    .map(String.titleCasePart)
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }

    private static func titleCasePart(_ part: Substring) -> String {
        let p = String(part)
        guard !p.isEmpty else { return p }
        if p.contains(where: \.isNumber) { return p }                    // codes: SL-34, THA1, 762
        let letters = p.filter(\.isLetter)
        if !letters.isEmpty, letters.count <= 4, p == p.uppercased() { return p }   // acronyms: SL, USDA
        return p.prefix(1).uppercased() + p.dropFirst().lowercased()
    }
}

extension Array where Element == String {
    /// Normalize each term and drop case-insensitive duplicates, order preserved.
    var normalizedTerms: [String] {
        var seen = Set<String>()
        return compactMap { term in
            let n = term.normalizedTerm
            return seen.insert(n.lowercased()).inserted ? n : nil
        }
    }
}

/// One-time data hygiene. Kept out of the models so the transform is easy to test and re-run.
enum DataMaintenance {
    private static let didNormalizeKey = "didNormalizeTermsV1"

    /// Normalize the casing of existing beans/brews once, so data logged before normalization (and
    /// the recovered notebook) reads consistently. Roaster names are deliberately left alone.
    static func normalizeExistingIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didNormalizeKey) else { return }
        guard let beans = try? context.fetch(FetchDescriptor<Bean>()) else { return }

        for bean in beans {
            bean.name = bean.name.normalizedTerm
            bean.country = bean.country?.normalizedTerm
            bean.region = bean.region?.normalizedTerm
            bean.farm = bean.farm?.normalizedTerm
            bean.varietal = bean.varietal?.normalizedTerm
            bean.process = bean.process?.normalizedTerm
            bean.roastLevel = bean.roastLevel?.normalizedTerm
            bean.roasterNotes = bean.roasterNotes.map(normalizeCommaList)
            bean.myFlavorTags = bean.myFlavorTags.normalizedTerms
            // bean.roasterName intentionally untouched.
            for brew in bean.brews {
                brew.taste.positives = brew.taste.positives.normalizedTerms
                brew.taste.negatives = brew.taste.negatives.normalizedTerms
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: didNormalizeKey)
    }

    /// Normalize a comma-joined list (how roaster notes are stored), deduping case-insensitively.
    static func normalizeCommaList(_ value: String) -> String {
        value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .normalizedTerms
            .joined(separator: ", ")
    }
}
