import Testing
@testable import DripWatch

struct RecipeTests {

    @Test func shotRatioIsYieldOverDose() {
        var r = Recipe(); r.doseGrams = 18; r.yieldGrams = 36
        #expect(r.shotRatio == 2.0)
    }

    @Test func shotRatioNilWithoutBothValues() {
        var r = Recipe(); r.doseGrams = 18
        #expect(r.shotRatio == nil)
    }

    @Test func effectiveWaterDerivesFromDoseAndRatio() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 16
        #expect(r.effectiveWaterGrams == 240)
    }

    @Test func effectiveWaterPrefersExplicitValue() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 16; r.totalWaterGrams = 250
        #expect(r.effectiveWaterGrams == 250)
    }

    @Test func newRecipeIsEmpty() {
        #expect(Recipe().isEmpty)
    }

    @Test func blankPourDoesNotMakeRecipeNonEmpty() {
        var r = Recipe()
        r.pours = [Pour(order: 1)]   // an "Add pour" row the user never filled in
        #expect(r.isEmpty)
        #expect(!r.hasPourBreakdown)
    }

    @Test func filledPourCounts() {
        var r = Recipe()
        r.pours = [Pour(order: 1, toGrams: 50)]
        #expect(!r.isEmpty)
        #expect(r.hasPourBreakdown)
    }

    @Test func suggestedTargetsSplitEvenlyWithoutDose() {
        var r = Recipe(); r.totalWaterGrams = 240
        // No dose → even cumulative split, landing exactly on the total.
        #expect(r.suggestedCumulativeTargets(count: 4) == [60, 120, 180, 240])
    }

    @Test func suggestedTargetsAreBloomAwareWithDose() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 16   // total = 240, bloom = 45
        let t = r.suggestedCumulativeTargets(count: 4)
        #expect(t.first == 45)          // bloom ≈ 3× dose
        #expect(t.last == 240)          // ends on the total
        #expect(t.count == 4)
        #expect(t == t.sorted())        // strictly cumulative
    }

    @Test func suggestedTargetsEmptyWithoutTotal() {
        let r = Recipe()
        #expect(r.suggestedCumulativeTargets(count: 4).isEmpty)
    }

    @Test func summaryLineIncludesKeyParams() {
        var r = Recipe(); r.waterTempC = 92; r.ratio = 15; r.pourCount = 4
        let line = r.summaryLine
        #expect(line.contains("92°"))
        #expect(line.contains("1:15"))
        #expect(line.contains("4 pours"))
    }
}
