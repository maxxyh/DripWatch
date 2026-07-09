import Foundation
import Vision
import UIKit
import ImageIO

/// Best-effort fields parsed off a coffee-bag photo. Everything is optional — OCR is a
/// convenience that pre-fills the form; the user always reviews.
struct ParsedBag {
    var name: String?
    /// The roaster/brand. The heuristic parser leaves this nil (roaster is hard to place by rule);
    /// the on-device model fills it. See `BagParser`.
    var roaster: String?
    var country: String?
    var region: String?
    var farm: String?
    var varietal: String?
    var process: String?
    var roastLevel: String?
    var roasterNotes: String?
    var rawLines: [String] = []
    /// Meaningful text the parser couldn't confidently file — surfaced for the user to categorize
    /// (and, once categorized, remembered via `LexiconTerm`).
    var unresolved: [String] = []

    var filledCount: Int {
        [name, country, region, farm, varietal, process, roastLevel, roasterNotes].compactMap { $0 }.count
    }
}

/// One recognized line with its normalized bounding box (Vision origin is bottom-left).
struct OCRLine {
    let text: String
    let box: CGRect
    var midY: CGFloat { box.midY }
    var height: CGFloat { box.height }
}

/// On-device bag OCR via the Vision framework. No network, works offline — a concrete payoff
/// of building native. This only *reads* text; parsing into fields is a heuristic below.
enum BagOCR {

    static func recognize(from data: Data) async -> [OCRLine] {
        guard let uiImage = UIImage(data: data), let cg = uiImage.cgImage else { return [] }
        // Respect the photo's EXIF orientation — otherwise a portrait camera shot is handed
        // to Vision sideways and every bounding box (and the columnar heuristic) is wrong.
        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { obs -> OCRLine? in
                    guard let best = obs.topCandidates(1).first else { return nil }
                    let text = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : OCRLine(text: text, box: obs.boundingBox)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// Maps recognized lines to fields. Handles two bag layouts:
    /// 1. Inline — "PROCESS: Washed" (value on the same line after a separator).
    /// 2. Columnar — a label column beside a value column; the value is found by position
    ///    (same row band, immediately to the right of the label). Each value line is consumed
    ///    once so two fields can't claim the same value.
    static func parse(_ lines: [OCRLine], learned: [String: BagField] = [:]) -> ParsedBag {
        var bag = ParsedBag()
        bag.rawLines = lines.map(\.text)
        var consumed = Set<Int>()

        let keys: [(tokens: [String], assign: (inout ParsedBag, String) -> Void)] = [
            (["variety", "varietal", "varieties"], { $0.varietal = $1 }),
            (["region", "zone"],      { $0.region = $1 }),
            (["farm", "producer"],    { $0.farm = $1 }),
            (["process", "processing"], { $0.process = $1 }),
            (["roast level"],         { $0.roastLevel = $1 }),
        ]

        func isLabelLine(_ line: OCRLine) -> Bool {
            let l = line.text.lowercased()
            let hasToken = keys.contains { $0.tokens.contains { l.contains($0) } }
                || l.contains("roasted") || l.contains("altitude") || l.contains("taste")
                || l.contains("tasting") || l.contains("origin")
                || noteLabelPhrases.contains { l.contains($0) }
            guard hasToken else { return false }
            // A real label is a short column header ("VARIETY", "ROAST LEVEL") or an inline
            // "key: value" — not a descriptive line that merely mentions the word (a blend's
            // "Brazil Catuai varietal, Natural"), which we still want to classify by content.
            return l.split(separator: " ").count <= 2 || l.contains(":")
        }

        for (tokens, assign) in keys {
            guard let li = lines.firstIndex(where: { line in
                let l = line.text.lowercased()
                // The token must START the line — a real label ("VARIETY: …", "PRODUCER | …"),
                // not a word buried in a farm or blend name ("Finca Varietales", "Catuai varietal").
                return tokens.contains { token in
                    guard let r = l.range(of: token) else { return false }
                    return l.distance(from: l.startIndex, to: r.lowerBound) <= 2
                }
            }) else { continue }
            let label = lines[li]

            // 1. Inline "key: value".
            if let inline = valueAfterKey(label.text) { assign(&bag, inline); continue }

            // 2. Columnar: nearest unconsumed non-label line on the same row band, strictly right.
            let band = max(label.height, 0.02) * 0.8
            let candidate = lines.enumerated()
                .filter { !consumed.contains($0.offset) && !isLabelLine($0.element)
                          && abs($0.element.midY - label.midY) < band
                          && $0.element.box.minX > label.box.minX }
                .min(by: { $0.element.box.minX < $1.element.box.minX })
            if let cand = candidate {
                assign(&bag, cleanValue(cand.element.text)); consumed.insert(cand.offset); continue
            }

            // 3. Vertical layout: the value sits on the line directly *below* the label (many bags
            //    stack "PRODUCER:" over "The Dharmawan Family"). Vision's y is bottom-up, so "below"
            //    is a smaller midY; take the nearest such non-label line roughly under the label.
            let gap = max(label.height, 0.02) * 3
            let below = lines.enumerated()
                .filter { !consumed.contains($0.offset) && !isLabelLine($0.element)
                          && !isBoilerplate($0.element.text)
                          && $0.element.midY < label.midY
                          && (label.midY - $0.element.midY) < gap
                          && abs($0.element.box.minX - label.box.minX) < 0.22 }
                .max(by: { $0.element.midY < $1.element.midY })
            if let b = below { assign(&bag, cleanValue(b.element.text)); consumed.insert(b.offset) }
        }

        // Fallback for an unlabeled process word printed on its own (e.g. "ANOXIC NATURAL").
        if bag.process == nil {
            for (i, line) in lines.enumerated() where !consumed.contains(i) && !isLabelLine(line) {
                if let p = knownProcess(line.text.lowercased()), line.text.count < 30 {
                    bag.process = p; break
                }
            }
        }

        // Roaster's tasting notes: any common label phrasing ("tasting notes", "taste notes",
        // "tastes like", "notes of"), with the value inline after the label and/or continuing on
        // the following line(s). Notes wrap unpredictably, so we split on commas *and* periods
        // (OCR often reads a "," as a "."), and only keep following lines that still look like
        // notes — a separated list, or something the lexicon recognizes as a flavor.
        if bag.roasterNotes == nil,
           let idx = lines.firstIndex(where: { line in
               let l = line.text.lowercased()
               return noteLabelPhrases.contains { l.contains($0) }
           }) {
            var collected: [String] = []
            if let inline = valueAfterNoteLabel(lines[idx].text) { collected += splitNotes(inline) }
            var j = idx + 1
            while j < lines.count, collected.count < 10 {
                let line = lines[j]
                guard !isLabelLine(line), !isBoilerplate(line.text), !looksLikeCodeOrNumber(line.text) else { break }
                let hasSeparator = line.text.contains { ",.;•·".contains($0) }
                guard hasSeparator || CoffeeLexicon.hasTastingNote(line.text) else { break }
                collected += splitNotes(line.text)
                j += 1
            }
            let cleaned = collected.map(cleanValue).filter { $0.count > 1 }
            if !cleaned.isEmpty { bag.roasterNotes = dedupeJoin(cleaned) }
        }

        // Name = the largest print that isn't a label, boilerplate, a process word, or a number.
        bag.name = lines.enumerated()
            .filter { !consumed.contains($0.offset) && !isLabelLine($0.element)
                      && !isBoilerplate($0.element.text)
                      && knownProcess($0.element.text.lowercased()) == nil
                      && !isNumeric($0.element.text)
                      // A bare origin ("Colombia"), a flavor/farm line, or a lone metadata word
                      // ("FILTER") is not the coffee's name.
                      && !isOriginOrFlavorLine($0.element.text)
                      && !isMetadataWord($0.element.text) }
            .max(by: { $0.element.height < $1.element.height })?
            .element.text

        // Content pass: for label-less bags (e.g. a blend printed as "Brazil Catuai varietal,
        // Natural"), classify each remaining line by *what its words are*. Fills only empty fields
        // — never overrides a label — and gathers anything it can't place as `unresolved`.
        var countryParts: [String] = []
        var varietalParts: [String] = []
        var noteParts: [String] = []
        for (i, line) in lines.enumerated() where !consumed.contains(i)
            && !isLabelLine(line) && !isBoilerplate(line.text) && line.text != bag.name {
            for segment in line.text.split(whereSeparator: { ",|".contains($0) }).map(String.init) {
                let (matches, unknowns) = CoffeeLexicon.classifySegment(segment, learned: learned)
                for m in matches {
                    switch m.field {
                    case .country: countryParts.append(m.value)
                    case .varietal: varietalParts.append(m.value)
                    case .tastingNote: noteParts.append(m.value)
                    case .process where bag.process == nil: bag.process = m.value
                    case .roastLevel where bag.roastLevel == nil: bag.roastLevel = m.value
                    case .region where bag.region == nil: bag.region = m.value
                    case .farm where bag.farm == nil: bag.farm = m.value
                    case .name where bag.name == nil: bag.name = m.value
                    default: break
                    }
                }
                bag.unresolved.append(contentsOf: unknowns)
            }
        }
        if bag.country == nil, !countryParts.isEmpty { bag.country = dedupeJoin(countryParts) }
        if bag.varietal == nil, !varietalParts.isEmpty { bag.varietal = dedupeJoin(varietalParts) }
        // Merge lexicon-detected flavors with any the label extractor already captured (a
        // single-word note like "Candy" the extractor stopped at can still be picked up here).
        let mergedNotes = (bag.roasterNotes.map(splitNotes) ?? []) + noteParts
        if !mergedNotes.isEmpty { bag.roasterNotes = dedupeJoin(mergedNotes) }

        // De-duplicate unresolved, and drop anything we ended up filing into a field anyway.
        let filled = Set([bag.name, bag.country, bag.region, bag.farm, bag.varietal, bag.process,
                          bag.roastLevel, bag.roasterNotes].compactMap { $0?.lowercased() })
        var seen = Set<String>()
        bag.unresolved = bag.unresolved.filter { term in
            let key = term.lowercased()
            guard !filled.contains(key), seen.insert(key).inserted else { return false }
            return true
        }

        return bag
    }

    /// Joins parts with ", " while dropping case-insensitive duplicates, order preserved.
    private static func dedupeJoin(_ parts: [String]) -> String {
        var seen = Set<String>()
        return parts.filter { seen.insert($0.lowercased()).inserted }.joined(separator: ", ")
    }

    // MARK: Helpers

    private static func valueAfterKey(_ line: String) -> String? {
        for sep in [":", " | ", "|", " - ", "–"] {
            if let range = line.range(of: sep) {
                let v = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { return cleanValue(v) }
            }
        }
        return nil
    }

    // MARK: Tasting-note helpers

    private static let noteLabelPhrases = ["tasting notes", "taste notes", "tastes like", "notes of"]

    /// The text after a notes label phrase on the same line ("TASTE NOTES: caramel, cocoa" → the
    /// part after "notes"). Nil when the label stands alone.
    private static func valueAfterNoteLabel(_ text: String) -> String? {
        let lower = text.lowercased()
        for phrase in noteLabelPhrases {
            guard let range = lower.range(of: phrase) else { continue }
            let offset = lower.distance(from: lower.startIndex, to: range.upperBound)
            let after = text[text.index(text.startIndex, offsetBy: offset)...]
            let value = after.trimmingCharacters(in: CharacterSet(charactersIn: " :.-–"))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Split a note line into individual notes on commas or periods (OCR frequently reads a
    /// separating "," as a "."), plus a couple of other bullet separators.
    private static func splitNotes(_ text: String) -> [String] {
        text.split(whereSeparator: { ",.;•·|".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A line that's clearly not a tasting note — a weight/altitude/price code, or a "(18:210)"
    /// style stamp — so note collection stops before it.
    private static func looksLikeCodeOrNumber(_ text: String) -> Bool {
        text.contains("(") || text.contains(")") || text.filter(\.isNumber).count >= 2
    }

    private static func knownProcess(_ lower: String) -> String? {
        ["anaerobic natural", "natural anaerobic", "anoxic natural", "carbonic maceration",
         "washed", "natural", "honey", "anaerobic", "anoxic"].first { lower.contains($0) }?.capitalized
    }

    /// A line that classifies as a bare origin, a flavor, or a farm/producer — never the coffee's
    /// name (a "Finca …" line is the farm, and its notes get split out by the content pass).
    private static func isOriginOrFlavorLine(_ text: String) -> Bool {
        let field = CoffeeLexicon.classifySegment(text).matches.first?.field
        return field == .country || field == .tastingNote || field == .farm
    }

    /// A line made up only of brew-method / qualifier words ("FILTER", "ESPRESSO", "BLEND") —
    /// metadata printed on the bag, never the coffee's name.
    private static func isMetadataWord(_ text: String) -> Bool {
        let tokens = text.lowercased().split { !$0.isLetter }.map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy { CoffeeLexicon.noise.contains($0) }
    }

    /// Country / competition / marketing lines that shouldn't be taken as the coffee's name.
    private static func isBoilerplate(_ text: String) -> Bool {
        let l = text.lowercased()
        let junk = ["specialty", "roaster", "top ", "vncp", "net wt", "whole bean",
                    "việt nam", "viet nam", "with notes", "tastes like", "bright acidity",
                    "masl", "m.a.s.l", "altitude"]
        // "coffee" marks a roaster tagline ("… Coffee Roasters") only in a longer phrase — a short
        // two-word product name like "Alo Coffee" is fine to keep.
        if l.contains("coffee"), text.split(separator: " ").count > 2 { return true }
        // A coffee name never starts with a digit (that's an altitude / weight / price line).
        return junk.contains { l.contains($0) } || text.count <= 2 || (text.first?.isNumber ?? false)
    }

    /// True when a line is only digits/punctuation (altitude, price, weight) — never a name.
    private static func isNumeric(_ text: String) -> Bool {
        let stripped = text.filter { !$0.isWhitespace && !$0.isPunctuation }
        return !stripped.isEmpty && stripped.allSatisfy { $0.isNumber }
    }

    private static func cleanValue(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-–")).capitalizedFirst
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
