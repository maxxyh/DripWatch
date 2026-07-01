import Foundation

/// A grind setting expressed in the grinder's *own* absolute vocabulary — the full,
/// reproducible value you actually dial in (e.g. `1Zpresso J · 3(−1)`).
///
/// `major` is the dial number; `clickOffset` is clicks away from it, where **positive =
/// finer/clockwise** and **negative = coarser/anticlockwise**. The absolute value is what
/// gets displayed everywhere — `−1` alone is meaningless, especially when bean-hopping
/// across different grinders. A brew-to-brew *delta* is computed separately (see BrewDiff)
/// and is only ever shown as an annotation on top of this absolute value.
struct GrindSetting: Codable, Hashable {
    var grinderName: String
    var major: Int
    var clickOffset: Int

    init(grinderName: String, major: Int, clickOffset: Int = 0) {
        self.grinderName = grinderName
        self.major = major
        self.clickOffset = clickOffset
    }

    /// The click offset rendered like the notebook: `(+2)`, `(−1)`, or empty when zero.
    var offsetText: String {
        if clickOffset == 0 { return "" }
        return clickOffset > 0 ? "(+\(clickOffset))" : "(−\(abs(clickOffset)))"
    }

    /// Full absolute display, e.g. `1Zpresso J · 3(−1)`.
    var display: String {
        "\(grinderName) · \(major)\(offsetText)"
    }

    /// Just the setting part without the grinder name, e.g. `3(−1)`.
    var settingText: String {
        "\(major)\(offsetText)"
    }
}
