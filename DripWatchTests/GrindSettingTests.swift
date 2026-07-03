import Testing
import Foundation
@testable import DripWatch

struct GrindSettingTests {

    @Test func offsetTextUsesSignedNotation() {
        #expect(GrindSetting(grinderName: "X", major: 2, clickOffset: 0).offsetText == "")
        #expect(GrindSetting(grinderName: "X", major: 2, clickOffset: 2).offsetText == "(+2)")
        // Negative uses a real minus sign (U+2212), not a hyphen.
        #expect(GrindSetting(grinderName: "X", major: 2, clickOffset: -3).offsetText == "(\u{2212}3)")
    }

    @Test func displayShowsFullAbsoluteValue() {
        let g = GrindSetting(grinderName: "1Zpresso J", major: 3, clickOffset: -1)
        #expect(g.display.hasPrefix("1Zpresso J"))
        #expect(g.display.hasSuffix("3(\u{2212}1)"))
        #expect(g.settingText == "3(\u{2212}1)")
    }

    @Test func zeroOffsetHasNoParen() {
        let g = GrindSetting(grinderName: "Niche", major: 12, clickOffset: 0)
        #expect(g.settingText == "12")
    }

    @Test func steplessDecimalDisplaysWithoutTrailingZero() {
        // Whole values read as integers; a stepless setting keeps its half-step.
        #expect(GrindSetting(grinderName: "DF54", major: 5).majorText == "5")
        #expect(GrindSetting(grinderName: "DF54", major: 4.5).majorText == "4.5")
        #expect(GrindSetting(grinderName: "DF54", major: 4.5).display == "DF54 · 4.5")
    }

    @Test func decodesLegacyIntMajorFromStrictCoder() throws {
        // `major` used to be an Int, persisted by SwiftData's strict plist coder. A brew saved by
        // an old build must still decode (this is the launch crash we shipped and fixed).
        let legacy: [String: Any] = ["grinderName": "1Zpresso J", "major": 3, "clickOffset": -1]
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        let g = try PropertyListDecoder().decode(GrindSetting.self, from: data)
        #expect(g.grinderName == "1Zpresso J")
        #expect(g.major == 3)
        #expect(g.clickOffset == -1)
    }

    @Test func decodesDoubleMajorFromStrictCoder() throws {
        let current: [String: Any] = ["grinderName": "DF54", "major": 4.5, "clickOffset": 0]
        let data = try PropertyListSerialization.data(fromPropertyList: current, format: .binary, options: 0)
        let g = try PropertyListDecoder().decode(GrindSetting.self, from: data)
        #expect(g.major == 4.5)
    }
}
