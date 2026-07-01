import Testing
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
}
