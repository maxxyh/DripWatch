import Foundation

/// Formats a brew as tidy Markdown — bean facts, the full recipe, how it tasted, and the planned
/// next brew — so it can be copied and pasted to an AI (or a friend) for brewing advice.
enum BrewMarkdown {

    static func string(for brew: Brew) -> String {
        let bean = brew.bean
        var sections: [String] = []

        let name = bean?.name.nilIfBlank ?? "Untitled bean"
        sections.append("# \(name) — \(brew.method.label)")

        var subtitle: [String] = []
        if let roaster = bean?.roasterName?.nilIfBlank { subtitle.append(roaster) }
        subtitle.append(brew.brewedAt.formatted(date: .abbreviated, time: .omitted))
        sections.append(subtitle.joined(separator: " · "))

        let facts = beanFacts(bean)
        if !facts.isEmpty { sections.append("**Bean**\n" + facts.joined(separator: "\n")) }

        sections.append("**Recipe**\n" + recipeLines(brew.recipe, method: brew.method).joined(separator: "\n"))

        let taste = tasteLines(brew.taste)
        if !taste.isEmpty { sections.append("**Taste**\n" + taste.joined(separator: "\n")) }

        if let next = brew.nextRecipeDraft {
            sections.append("**Planned next brew**\n" + recipeLines(next, method: brew.method).joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    /// Formats an entire brew history as Markdown for pasting into an AI for analysis across
    /// brews. Bean facts and the first recipe per method are written out once; every later brew
    /// of that method shows only what changed since the previous one (the same delta
    /// `BrewDiff` already computes for the on-screen annotation) instead of repeating the full
    /// recipe — so a long history stays proportional to how much actually changed, not to how
    /// many brews were logged. Taste notes and the next-brew plan are never "carried state", so
    /// they're always shown in full when present.
    static func string(forHistory brews: [Brew]) -> String {
        guard !brews.isEmpty else { return "" }
        let bean = brews.first?.bean
        let chronological = brews.sorted { $0.brewedAt < $1.brewedAt }
        let methods = Set(chronological.map(\.method))

        var sections: [String] = []

        let name = bean?.name.nilIfBlank ?? "Untitled bean"
        sections.append("# \(name) — Brew history (\(chronological.count) brew\(chronological.count == 1 ? "" : "s"))")

        if let roaster = bean?.roasterName?.nilIfBlank { sections.append(roaster) }

        let facts = beanFacts(bean)
        if !facts.isEmpty { sections.append("**Bean**\n" + facts.joined(separator: "\n")) }

        var previousRecipe: [BrewMethod: Recipe] = [:]
        for (index, brew) in chronological.enumerated() {
            var header = "## Brew \(index + 1) — \(brew.brewedAt.formatted(date: .abbreviated, time: .omitted))"
            if methods.count > 1 { header += " · \(brew.method.label)" }

            var body: [String] = []
            let isBaseline = previousRecipe[brew.method] == nil
            if let prev = previousRecipe[brew.method] {
                let diffs = BrewDiff.changes(from: prev, to: brew.recipe)
                body.append(diffs.isEmpty ? "**Recipe:** unchanged" : "**Changes:** " + diffs.joined(separator: "; "))
            } else {
                body.append("**Recipe**\n" + recipeLines(brew.recipe, method: brew.method).joined(separator: "\n"))
            }
            previousRecipe[brew.method] = brew.recipe

            // Notes are brew-specific commentary, not carried state, so they're worth repeating —
            // `recipeLines` above already covers them for a method's first/baseline brew.
            if !isBaseline, let notes = brew.recipe.notes?.nilIfBlank {
                body.append("**Notes:** \(notes)")
            }

            let taste = tasteLines(brew.taste)
            if !taste.isEmpty { body.append("**Taste**\n" + taste.joined(separator: "\n")) }

            if let next = brew.nextRecipeDraft {
                body.append("**Planned next brew**\n" + recipeLines(next, method: brew.method).joined(separator: "\n"))
            }

            sections.append(([header] + body).joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    private static func beanFacts(_ bean: Bean?) -> [String] {
        guard let bean else { return [] }
        var facts: [String] = []
        func add(_ label: String, _ value: String?) {
            if let v = value?.nilIfBlank { facts.append("- \(label): \(v)") }
        }
        let origin = [bean.region, bean.country].compactMap { $0?.nilIfBlank }.joined(separator: ", ")
        add("Origin", origin.isEmpty ? nil : origin)
        add("Farm", bean.farm)
        add("Variety", bean.varietal)
        add("Process", bean.process)
        add("Roast", bean.roastLevel)
        if let d = bean.roastDate { add("Roasted", d.formatted(date: .abbreviated, time: .omitted)) }
        if !bean.roasterNoteList.isEmpty { add("Roaster notes", bean.roasterNoteList.joined(separator: ", ")) }
        return facts
    }

    private static func recipeLines(_ r: Recipe, method: BrewMethod) -> [String] {
        var lines: [String] = []
        if let g = r.grind { lines.append("- Grind: \(g.display)") }

        if method == .espresso {
            if let d = r.doseGrams { lines.append("- Dose: \(gramText(d)) g") }
            if let y = r.yieldGrams { lines.append("- Yield: \(gramText(y)) g") }
            if let sr = r.shotRatio { lines.append("- Ratio: 1:\(ratioText((sr * 10).rounded() / 10))") }
            if let t = r.shotTimeSec { lines.append("- Shot time: \(timeText(t))") }
            if let pi = r.preInfusionSec { lines.append("- Pre-infusion: \(pi)s") }
            if let sw = r.surfWaitSec { lines.append("- Surf wait: \(sw)s") }
            if let sm = r.steamModeSec { lines.append("- Steam mode: \(sm)s") }
            if let t = r.waterTempC { lines.append("- Temp: \(t)°C") }
        } else {
            if let dripper = r.dripperName { lines.append("- Dripper: \(dripper)") }
            if let t = r.waterTempC { lines.append("- Temp: \(t)°C") }
            if let d = r.doseGrams { lines.append("- Dose: \(gramText(d)) g") }
            if let ratio = r.ratio { lines.append("- Ratio: 1:\(ratioText(ratio))") }
            if let w = r.effectiveWaterGrams { lines.append("- Water: \(gramText(w)) g") }
            if let p = r.pourCount { lines.append("- Pours: \(p)") }
            if let b = r.bloomTimeSec { lines.append("- Bloom: \(timeText(b))") }
            if let tdd = r.totalDrawdownSec { lines.append("- Drawdown (TDD): \(timeText(tdd))") }

            let allPours = r.canonicalPours.sorted { $0.order < $1.order }
            let pours = allPours.filter { $0.toGrams != nil || $0.startSec != nil || $0.style?.nilIfBlank != nil }
            if !pours.isEmpty {
                lines.append("- Pour-by-pour:")
                for p in pours {
                    var parts: [String] = []
                    if let s = p.startSec { parts.append(p.endSec.map { "\(timeText(s))–\(timeText($0))" } ?? timeText(s)) }
                    if let g = p.toGrams { parts.append("→ \(gramText(g)) g") }
                    if let style = p.style?.nilIfBlank { parts.append("(\(style))") }
                    let previousGrams = p.order == 1 ? 0 : allPours.first(where: { $0.order == p.order - 1 })?.toGrams
                    if let rate = pourFlowRateGramsPerSecond(from: previousGrams, to: p.toGrams, start: p.startSec, end: p.endSec) {
                        parts.append("· \(gramText((rate * 10).rounded() / 10)) g/s")
                    }
                    lines.append("  - #\(p.order): " + parts.joined(separator: " "))
                }
            }
        }

        if let notes = r.notes?.nilIfBlank { lines.append("- Notes: \(notes)") }
        if lines.isEmpty { lines.append("- (no parameters recorded)") }
        return lines
    }

    private static func tasteLines(_ t: Taste) -> [String] {
        var lines: [String] = []
        if !t.positives.isEmpty { lines.append("- Good: \(t.positives.joined(separator: ", "))") }
        if !t.negatives.isEmpty { lines.append("- Off: \(t.negatives.joined(separator: ", "))") }

        var balance: [String] = []
        if let a = t.balance.acidity { balance.append("acidity \(a)/5") }
        if let s = t.balance.sweetness { balance.append("sweetness \(s)/5") }
        if let b = t.balance.bitterness { balance.append("bitterness \(b)/5") }
        if let bd = t.balance.body { balance.append("body \(bd)/5") }
        if !balance.isEmpty { lines.append("- Balance: \(balance.joined(separator: ", "))") }

        if let r = t.rating { lines.append("- Rating: \(String(repeating: "★", count: r))\(String(repeating: "☆", count: max(0, 5 - r)))") }
        if let note = t.note?.nilIfBlank { lines.append("- Note: \(note)") }
        return lines
    }
}
