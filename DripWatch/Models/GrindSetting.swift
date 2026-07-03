import Foundation

/// A grind setting expressed in the grinder's *own* absolute vocabulary — the full,
/// reproducible value you actually dial in (e.g. `1Zpresso J · 3(−1)` or, on a stepless
/// grinder, `DF54 · 4.5`).
///
/// `major` is the dial number — a `Double` so stepless grinders (worm-drive, no clicks) can
/// record a fractional setting like `4.5`; stepped grinders just use whole values. `clickOffset`
/// is clicks away from `major`, where **positive = finer/clockwise** and **negative =
/// coarser/anticlockwise** (always `0` for a stepless grinder). The absolute value is what gets
/// displayed everywhere — `−1` alone is meaningless, especially when bean-hopping across
/// different grinders. A brew-to-brew *delta* is computed separately (see BrewDiff) and is only
/// ever shown as an annotation on top of this absolute value.
struct GrindSetting: Codable, Hashable {
    var grinderName: String
    var major: Double
    var clickOffset: Int

    init(grinderName: String, major: Double, clickOffset: Int = 0) {
        self.grinderName = grinderName
        self.major = major
        self.clickOffset = clickOffset
    }
    // NOTE: do NOT add a custom Codable init(from:) here. SwiftData flattens this struct into
    // columns using the *synthesized* Codable conformance; a hand-written init(from:) breaks its
    // composite decoder and crashes on load (even for correctly-stored data). The `major` Int→Double
    // change was the launch crash on old stores — the fix is a fresh store, not a tolerant decoder.

    /// The click offset rendered like the notebook: `(+2)`, `(−1)`, or empty when zero.
    var offsetText: String {
        if clickOffset == 0 { return "" }
        return clickOffset > 0 ? "(+\(clickOffset))" : "(−\(abs(clickOffset)))"
    }

    /// The dial number without a trailing `.0` (3 → "3", 4.5 → "4.5").
    var majorText: String {
        major.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(major)) : String(format: "%.1f", major)
    }

    /// Full absolute display, e.g. `1Zpresso J · 3(−1)` or `DF54 · 4.5`.
    var display: String {
        "\(grinderName) · \(majorText)\(offsetText)"
    }

    /// Just the setting part without the grinder name, e.g. `3(−1)` or `4.5`.
    var settingText: String {
        "\(majorText)\(offsetText)"
    }
}
