import Foundation

/// Computes the human-readable *delta* between one brew's recipe and the previous brew's for
/// the same bean — the notebook's arrow made legible. This is only ever shown as an annotation
/// on top of the always-visible absolute recipe; it never replaces it.
enum BrewDiff {

    /// A list of terse change phrases, e.g. ["2 clicks coarser", "3° cooler", "1:15 → 1:16"].
    /// Empty when nothing meaningful changed.
    static func changes(from prev: Recipe, to curr: Recipe) -> [String] {
        var out: [String] = []

        if let g = grindChange(from: prev.grind, to: curr.grind) { out.append(g) }

        if let a = prev.waterTempC, let b = curr.waterTempC, a != b {
            let d = b - a
            out.append("\(abs(d))° \(d > 0 ? "hotter" : "cooler")")
        }

        if let a = prev.ratio, let b = curr.ratio, a != b {
            out.append("1:\(ratioText(a)) → 1:\(ratioText(b))")
        }

        if let a = prev.doseGrams, let b = curr.doseGrams, a != b {
            let d = b - a
            out.append("\(d > 0 ? "+" : "−")\(gramText(abs(d)))g dose")
        }

        if let a = prev.yieldGrams, let b = curr.yieldGrams, a != b {
            let d = b - a
            out.append("\(d > 0 ? "+" : "−")\(gramText(abs(d)))g yield")
        }

        if let a = prev.shotTimeSec, let b = curr.shotTimeSec, a != b {
            out.append("shot \(a)s → \(b)s")
        }

        if let a = prev.pourCount, let b = curr.pourCount, a != b {
            out.append("\(a) → \(b) pours")
        }

        if let a = prev.totalDrawdownSec, let b = curr.totalDrawdownSec, a != b {
            out.append("TDD \(timeText(a)) → \(timeText(b))")
        }

        return out
    }

    /// Grind delta. A finer/coarser *direction* is only asserted when unambiguous — same
    /// grinder and same major dial, comparing click offsets (per the + = finer / − = coarser
    /// convention). Across different dials the clicks-per-rotation varies by grinder, so we
    /// show the absolute change rather than guess a direction.
    private static func grindChange(from prev: GrindSetting?, to curr: GrindSetting?) -> String? {
        guard let prev, let curr else { return nil }

        if prev.grinderName == curr.grinderName && prev.major == curr.major {
            let d = curr.clickOffset - prev.clickOffset
            if d == 0 { return nil }
            return "\(abs(d)) click\(abs(d) == 1 ? "" : "s") \(d > 0 ? "finer" : "coarser")"
        }
        if prev.grinderName != curr.grinderName {
            return "grinder → \(curr.grinderName)"
        }
        return "grind \(prev.settingText) → \(curr.settingText)"
    }
}

/// Grams without a trailing `.0` (18.0 → "18", 18.5 → "18.5").
func gramText(_ g: Double) -> String {
    g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
}
