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
    // Grind is stored as flat optional scalars, NOT an optional nested `GrindSetting?`: SwiftData
    // flattens embedded Codable structs into columns, and its decoder *crashes* on a nil nested
    // struct (i.e. any brew logged without a grind — `EXC_BREAKPOINT` in GrindSetting.init(from:)).
    // Optional scalars decode fine. `grind` below is a computed façade so the rest of the app is
    // unchanged.
    var grinderName: String?
    var grindMajor: Double?
    var grindClickOffset: Int?

    var grind: GrindSetting? {
        get {
            guard let grinderName else { return nil }
            return GrindSetting(grinderName: grinderName, major: grindMajor ?? 0, clickOffset: grindClickOffset ?? 0)
        }
        set {
            grinderName = newValue?.grinderName
            grindMajor = newValue?.major
            grindClickOffset = newValue?.clickOffset
        }
    }

    var waterTempC: Int?
    var doseGrams: Double?
    /// Ratio as the denominator, e.g. `15` means 1:15. Not restricted to a round grid — the
    /// +/- stepper nudges in 0.5s for convenience, but a value derived from a typed total water
    /// (e.g. 220g ÷ 15g = 14.666…) is stored at full precision so total water stays exact.
    var ratio: Double?
    /// An explicit total water override, used only when there's no dose to divide by (so a total
    /// can still be typed before the dose is known). Once a dose exists, total water is always
    /// derived as `dose × ratio` — see `setTotalWater` / `reconcileTotalWaterWithDose` — so this
    /// never becomes a second, silently-stale source of truth that stops reacting to ratio edits.
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

    /// A copy suitable for seeding the *next-brew plan*: the two measured outcomes you sit and
    /// watch for — shot time (espresso) and total drawdown (pourover) — are dropped. They're
    /// observed, not dialled, and the most variable numbers on the sheet, so a plan never
    /// pre-specifies them; you measure them fresh each brew. You can still type a target into the
    /// plan by hand — this only strips the value auto-carried from a previous brew.
    var asPlanSeed: Recipe {
        var r = self
        r.shotTimeSec = nil
        r.totalDrawdownSec = nil
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

    /// The number of pours a fresh breakdown should have, and the ceiling any pour-count value
    /// is capped to before it's used to size `pours`. Matches the "Pours" field's stepper range —
    /// shared so a value that reaches the model some other way (a typed value mid-keystroke, an
    /// imported/synced recipe) can never blow the per-pour array out to an unreasonable size.
    static let pourCountRange = 1...12

    /// Sets the *total* water directly (e.g. typed into a "Total water" field), keeping it and
    /// `ratio` bidirectionally in sync. When a dose is known, the total is folded straight into
    /// the ratio and no separate total is stored — so the two fields always describe the same
    /// number instead of one silently going stale when the other changes. Without a dose there's
    /// nothing to divide by, so the total is kept as an explicit override until one appears (see
    /// `reconcileTotalWaterWithDose`).
    mutating func setTotalWater(_ grams: Double?) {
        guard let grams, grams > 0 else {
            if let dose = doseGrams, dose > 0 { ratio = nil } else { totalWaterGrams = nil }
            return
        }
        if let dose = doseGrams, dose > 0 {
            ratio = grams / dose
            totalWaterGrams = nil
        } else {
            totalWaterGrams = grams
        }
    }

    /// Folds a standalone total-water override into the ratio the moment a dose becomes known.
    /// Call this when `doseGrams` changes — without it, a total typed before the dose was set
    /// would stay pinned at that value forever (since `effectiveWaterGrams` prefers an explicit
    /// `totalWaterGrams` over `dose × ratio`), silently ignoring every later ratio edit.
    mutating func reconcileTotalWaterWithDose() {
        guard let dose = doseGrams, dose > 0, let total = totalWaterGrams else { return }
        ratio = total / dose
        totalWaterGrams = nil
    }

    /// Grows or shrinks `pours` to exactly `count` rows (renumbering `order` to match), without
    /// touching any row's `toGrams`. Pure structural resize — pair with `reflowPourWeights()` to
    /// also refresh the suggested targets.
    mutating func reflowPourCount(to count: Int) {
        let target = max(0, count)
        if pours.count < target {
            for i in pours.count..<target { pours.append(Pour(order: i + 1)) }
        } else if pours.count > target {
            pours = Array(pours.prefix(target))
        }
        for i in pours.indices { pours[i].order = i + 1 }
    }

    /// Overwrites every row's cumulative target with a fresh suggested ramp for the current pour
    /// count and total water. A no-op when there's nothing to suggest from (see
    /// `suggestedCumulativeTargets`).
    mutating func reflowPourWeights() {
        let targets = suggestedCumulativeTargets(count: pours.count)
        guard targets.count == pours.count else { return }
        for i in pours.indices { pours[i].toGrams = targets[i] }
    }

    /// Appends one blank pour row (capped at `pourCountRange.upperBound`) and keeps `pourCount`
    /// in step with the new row count. Bidirectional sync with the "Pours" field is the whole
    /// point of this method existing rather than the caller mutating `pours` directly — the two
    /// must never be able to drift apart.
    mutating func addPour() {
        guard pours.count < Recipe.pourCountRange.upperBound else { return }
        pours.append(Pour(order: pours.count + 1))
        pourCount = pours.count
    }

    /// Removes the pour with `id`, renumbers the rest, and keeps `pourCount` in step with the
    /// new row count (nil once the last row is gone). The other half of `addPour()`'s
    /// bidirectional-sync guarantee, for the breakdown's per-row remove button.
    mutating func removePour(id: UUID) {
        pours.removeAll { $0.id == id }
        for i in pours.indices { pours[i].order = i + 1 }
        pourCount = pours.isEmpty ? nil : pours.count
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

/// Renders a ratio to at most 2 decimal places, without a trailing `.0` or `0` (15 → "15",
/// 15.5 → "15.5", a dose-derived 14.6667 → "14.67"). `String(r)` alone would print every
/// binary-decimal digit a derived ratio can carry (e.g. "14.666666666666666") — this rounds
/// first so bidirectionally-synced values stay readable.
func ratioText(_ r: Double) -> String {
    let rounded = (r * 100).rounded() / 100
    if rounded.truncatingRemainder(dividingBy: 1) == 0 { return String(Int(rounded)) }
    var s = String(format: "%.2f", rounded)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

/// Formats seconds as `m:ss` (135 → "2:15").
func timeText(_ sec: Int) -> String {
    String(format: "%d:%02d", sec / 60, sec % 60)
}
