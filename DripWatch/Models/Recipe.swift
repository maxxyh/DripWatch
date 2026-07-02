import Foundation

/// One pour in a pourover, as it appears in the notebook — a cumulative water target
/// (`toGrams`), the window it was poured over (`startSec`…`endSec`), and an optional style note
/// ("centre", "aggressive"). This is the *advanced* layer: recipes work fine with just a pour
/// count and no breakdown.
struct Pour: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var order: Int
    var toGrams: Double?
    /// When this pour began, in seconds from brew start.
    var startSec: Int?
    /// When this pour finished (start of the drawdown before the next pour).
    var endSec: Int?
    var style: String?

    init(order: Int, toGrams: Double? = nil, startSec: Int? = nil, endSec: Int? = nil, style: String? = nil) {
        self.order = order
        self.toGrams = toGrams
        self.startSec = startSec
        self.endSec = endSec
        self.style = style
    }
}

/// The reusable heart of the app. A `Recipe` is embedded on a `Brew` (what you did) and is
/// *also* what a next-brew draft is (what you plan to do) — same shape, same editor. Nearly
/// everything is optional so a recipe can be as terse as `92°, 4 pours, 1:15` or expand into
/// a full per-pour breakdown only when wanted.
struct Recipe: Codable, Hashable {
    var grind: GrindSetting?
    var waterTempC: Int?
    var doseGrams: Double?
    /// Ratio as the denominator, e.g. `15` means 1:15.
    var ratio: Double?
    var totalWaterGrams: Double?
    var pourCount: Int?
    var bloomTimeSec: Int?
    /// Total drawdown time (TDD) in seconds.
    var totalDrawdownSec: Int?
    /// Free-text pour style / agitation ("aggressive, high, centre pour").
    var notes: String?
    var pours: [Pour] = []

    // Espresso-specific (ignored for pourover): the shot's yield in the cup and its time.
    var yieldGrams: Double?
    var shotTimeSec: Int?

    // Manual-machine technique for non-PID/non-pressure setups (e.g. Gaggia Classic Pro).
    // Temperature is controlled by "surfing" rather than measured: wait N seconds after the
    // brew light, then flip the steam switch (steaming mode) for M seconds to raise the boiler.
    // Pre-infusion is "poor man's" — bleeding group pressure via the steam wand for K seconds.
    var preInfusionSec: Int?   // poor-man's pre-infusion (steam-wand bleed)
    var surfWaitSec: Int?      // seconds waited after the brew light comes on (post-purge)
    var steamModeSec: Int?     // seconds the steam switch is flipped on (temperature surf)

    init() {}

    /// A sensible starting point for a fresh pourover — the values you'd otherwise re-type every
    /// brew (92°, 30s bloom, 1:15, 3 pours). Dose is left blank (it varies by cup) and drawdown
    /// too — that's a "see how it goes" number, not something to plan up front. All still editable.
    static func newPourover() -> Recipe {
        var r = Recipe()
        r.waterTempC = 92
        r.bloomTimeSec = 30
        r.ratio = 15
        r.pourCount = 3
        return r
    }

    /// Brew ratio for espresso (yield ÷ dose), e.g. 2.0 for a 1:2 shot.
    var shotRatio: Double? {
        guard let d = doseGrams, d > 0, let y = yieldGrams else { return nil }
        return y / d
    }

    /// Total water, preferring an explicit value, otherwise derived from dose × ratio.
    var effectiveWaterGrams: Double? {
        if let w = totalWaterGrams { return w }
        if let d = doseGrams, let r = ratio { return d * r }
        return nil
    }

    /// Suggested cumulative water targets for `count` pours, used to pre-fill the breakdown so
    /// you're not doing arithmetic mid-brew. When a dose is known, the bloom (pour 1) gets ~3×
    /// dose and the rest is split evenly to the total; otherwise it's a plain even split. The
    /// last target always lands exactly on the total. Empty when there's no total to work from.
    func suggestedCumulativeTargets(count: Int) -> [Double] {
        guard count > 0, let total = effectiveWaterGrams, total > 0 else { return [] }
        func r5(_ x: Double) -> Double { max(0, (x / 5).rounded() * 5) }

        var targets: [Double]
        if count >= 2, let dose = doseGrams, dose > 0, r5(dose * 3) < total {
            let bloom = r5(dose * 3)
            let step = (total - bloom) / Double(count - 1)
            targets = (0..<count).map { i in i == 0 ? bloom : bloom + step * Double(i) }
        } else {
            targets = (1...count).map { total * Double($0) / Double(count) }
        }
        targets = targets.map(r5)
        targets[count - 1] = r5(total)   // land exactly on the total
        return targets
    }

    /// Pours that actually carry data (a blank "Add pour" row doesn't count).
    var meaningfulPours: [Pour] {
        pours.filter { $0.toGrams != nil || $0.startSec != nil || $0.endSec != nil || ($0.style?.isEmpty == false) }
    }

    /// True when the per-pour breakdown has real content — drives progressive disclosure.
    var hasPourBreakdown: Bool { !meaningfulPours.isEmpty }

    /// True when nothing at all has been entered.
    var isEmpty: Bool {
        grind == nil && waterTempC == nil && doseGrams == nil && ratio == nil
            && totalWaterGrams == nil && pourCount == nil && bloomTimeSec == nil
            && totalDrawdownSec == nil && yieldGrams == nil && shotTimeSec == nil
            && preInfusionSec == nil && surfWaitSec == nil && steamModeSec == nil
            && (notes?.isEmpty ?? true) && meaningfulPours.isEmpty
    }

    /// A short one-line summary for history rows, e.g. `92° · 1:15 · 4 pours` or `18g → 36g · 28s`.
    var summaryLine: String {
        var parts: [String] = []
        if let g = grind { parts.append(g.settingText) }
        if let t = waterTempC { parts.append("\(t)°") }
        if let d = doseGrams, let y = yieldGrams { parts.append("\(gramText(d))→\(gramText(y))g") }
        if let r = ratio { parts.append("1:\(ratioText(r))") }
        if let p = pourCount { parts.append("\(p) pour\(p == 1 ? "" : "s")") }
        if let st = shotTimeSec { parts.append("\(st)s") }
        return parts.joined(separator: " · ")
    }
}

/// Renders a ratio without a trailing `.0` (15 → "15", 15.5 → "15.5").
func ratioText(_ r: Double) -> String {
    r.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(r)) : String(r)
}

/// Formats seconds as `m:ss` (135 → "2:15").
func timeText(_ sec: Int) -> String {
    String(format: "%d:%02d", sec / 60, sec % 60)
}
