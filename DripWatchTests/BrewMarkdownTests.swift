import Testing
@testable import DripWatch

struct BrewMarkdownTests {

    @Test func digitsRoundTripToSeconds() {
        #expect(secondsFromDigits("45") == 45)
        #expect(secondsFromDigits("28") == 28)
        #expect(secondsFromDigits("230") == 2 * 60 + 30)
        #expect(secondsFromDigits("1230") == 12 * 60 + 30)
        #expect(secondsFromDigits("") == nil)
        #expect(secondsFromDigits("2:30") == 2 * 60 + 30)   // non-digits are stripped

        #expect(secondsToDigits(45) == "45")
        #expect(secondsToDigits(150) == "230")
        #expect(secondsToDigits(90) == "130")
    }

    @Test func markdownIncludesBeanRecipeAndTaste() {
        let bean = Bean(name: "Voyager")
        bean.roasterName = "Voyager Craft"
        bean.process = "Washed"
        bean.roasterNotes = "Dates, vanilla"

        var r = Recipe()
        r.grind = GrindSetting(grinderName: "1Zpresso J", major: 3, clickOffset: -1)
        r.waterTempC = 92; r.doseGrams = 15; r.ratio = 16; r.pourCount = 4; r.bloomTimeSec = 30
        let brew = Brew(brewedAt: .now, method: .pourover, recipe: r)
        brew.bean = bean

        var t = Taste(); t.positives = ["honey"]; t.negatives = ["bitter"]; t.rating = 3
        brew.taste = t

        let md = BrewMarkdown.string(for: brew)
        #expect(md.contains("# Voyager — Pourover"))
        #expect(md.contains("Voyager Craft"))
        #expect(md.contains("**Recipe**"))
        #expect(md.contains("1Zpresso J · 3(\u{2212}1)"))
        #expect(md.contains("1:16"))
        #expect(md.contains("Bloom: 0:30"))
        #expect(md.contains("**Taste**"))
        #expect(md.contains("Good: honey"))
        #expect(md.contains("★★★☆☆"))
    }
}
