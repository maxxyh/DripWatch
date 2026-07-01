import Testing
@testable import DripWatch

struct BrewDiffTests {

    private func grind(_ name: String, _ major: Int, _ offset: Int) -> GrindSetting {
        GrindSetting(grinderName: name, major: major, clickOffset: offset)
    }

    @Test func coarserWhenOffsetDecreasesSameDial() {
        var a = Recipe(); a.grind = grind("1Zpresso J", 3, 0)
        var b = Recipe(); b.grind = grind("1Zpresso J", 3, -1)
        #expect(BrewDiff.changes(from: a, to: b).contains("1 click coarser"))
    }

    @Test func finerWhenOffsetIncreasesSameDial() {
        var a = Recipe(); a.grind = grind("1Zpresso J", 3, -1)
        var b = Recipe(); b.grind = grind("1Zpresso J", 3, 1)
        #expect(BrewDiff.changes(from: a, to: b).contains("2 clicks finer"))
    }

    @Test func differentDialDoesNotAssertDirection() {
        // Across dials, clicks-per-rotation is grinder-specific — never claim finer/coarser.
        var a = Recipe(); a.grind = grind("Niche Zero", 12, 0)
        var b = Recipe(); b.grind = grind("Niche Zero", 11, 0)
        let changes = BrewDiff.changes(from: a, to: b)
        #expect(!changes.contains { $0.contains("finer") || $0.contains("coarser") })
        #expect(changes.contains { $0.contains("12") && $0.contains("11") })
    }

    @Test func temperatureDirection() {
        var a = Recipe(); a.waterTempC = 92
        var b = Recipe(); b.waterTempC = 89
        #expect(BrewDiff.changes(from: a, to: b).contains { $0.contains("cooler") })
    }

    @Test func espressoYieldAndShotTime() {
        var a = Recipe(); a.yieldGrams = 36; a.shotTimeSec = 28
        var b = Recipe(); b.yieldGrams = 40; b.shotTimeSec = 30
        let c = BrewDiff.changes(from: a, to: b)
        #expect(c.contains { $0.contains("4g yield") })
        #expect(c.contains { $0.contains("28s") && $0.contains("30s") })
    }

    @Test func manualMachineTechniqueDeltas() {
        var a = Recipe(); a.preInfusionSec = 6; a.surfWaitSec = 8; a.steamModeSec = 4
        var b = Recipe(); b.preInfusionSec = 8; b.surfWaitSec = 11; b.steamModeSec = 4
        let c = BrewDiff.changes(from: a, to: b)
        #expect(c.contains("pre-infuse 6s → 8s"))
        #expect(c.contains("surf 8s → 11s"))
        // steamMode unchanged → no entry for it.
        #expect(!c.contains { $0.hasPrefix("steam") })
    }

    @Test func identicalRecipesHaveNoChanges() {
        var a = Recipe(); a.waterTempC = 92; a.ratio = 15
        #expect(BrewDiff.changes(from: a, to: a).isEmpty)
    }
}
