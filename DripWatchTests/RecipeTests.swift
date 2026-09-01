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

    @Test func dripperMakesRecipeNonEmptyAndAppearsInSummary() {
        var r = Recipe()
        r.dripperName = "V60 Neo"
        #expect(!r.isEmpty)
        #expect(r.summaryLine == "V60 Neo")
    }

    @Test func planSeedDropsMeasuredTimesButKeepsDials() {
        var r = Recipe()
        r.doseGrams = 18; r.yieldGrams = 42; r.ratio = 2.3
        r.shotTimeSec = 40; r.totalDrawdownSec = 150
        let seed = r.asPlanSeed
        // The measured outcomes you sit and watch for are not planned.
        #expect(seed.shotTimeSec == nil)
        #expect(seed.totalDrawdownSec == nil)
        // Everything you actually dial in is preserved.
        #expect(seed.doseGrams == 18)
        #expect(seed.yieldGrams == 42)
        #expect(seed.ratio == 2.3)
    }

    @Test func blankPourDoesNotMakeRecipeNonEmpty() {
        var r = Recipe()
        r.pours = [Pour(order: 1)]   // a laid-out row that never got a weight
        #expect(r.isEmpty)
        #expect(!r.hasPourBreakdown)
    }

    @Test func filledPourCounts() {
        var r = Recipe()
        r.pours = [Pour(order: 1, toGrams: 50)]
        #expect(!r.isEmpty)
        #expect(r.hasPourBreakdown)
    }

    @Test func canonicalPourTimingsUseBrewStartAndBloomAsSpecialStarts() {
        var r = Recipe()
        r.bloomTimeSec = 45
        r.pours = [
            Pour(order: 1, startSec: 12),
            Pour(order: 2, startSec: 60),
            Pour(order: 3, startSec: 90),
        ]

        r.canonicalizePourTimings()

        #expect(r.pours.map(\.startSec) == [0, 45, 90])
    }

    @Test func changingBloomUpdatesSecondPourStartWithoutTouchingLaterPours() {
        var r = Recipe()
        r.pours = [Pour(order: 1), Pour(order: 2), Pour(order: 3, startSec: 90)]

        r.setBloomTime(40)

        #expect(r.bloomTimeSec == 40)
        #expect(r.pours.map(\.startSec) == [0, 40, 90])
    }

    @Test func canonicalTimingsPromoteALegacySecondPourStartToBloom() {
        var r = Recipe()
        r.pours = [Pour(order: 1), Pour(order: 2, startSec: 45)]

        r.canonicalizePourTimings()

        #expect(r.bloomTimeSec == 45)
        #expect(r.pours.map(\.startSec) == [0, 45])
    }

    @Test func clearingBloomAlsoClearsTheSecondPourStart() {
        var r = Recipe()
        r.bloomTimeSec = 45
        r.pours = [Pour(order: 1, startSec: 0), Pour(order: 2, startSec: 45)]

        r.setBloomTime(nil)

        #expect(r.bloomTimeSec == nil)
        #expect(r.pours.map(\.startSec) == [0, nil])
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

    // MARK: - Bidirectional ratio ↔ total water sync

    @Test func settingTotalWaterWithKnownDoseDerivesRatio() {
        var r = Recipe(); r.doseGrams = 15
        r.setTotalWater(225)
        #expect(r.ratio == 15)
        // No standalone override left behind — it must stay reactive to future ratio/dose edits.
        #expect(r.totalWaterGrams == nil)
        #expect(r.effectiveWaterGrams == 225)
    }

    @Test func settingTotalWaterRoundTripsThroughANonRoundRatio() {
        // 220g over a 15g dose isn't a .5-aligned ratio — the old stepper-only grid couldn't
        // represent it. It must still round-trip exactly through ratio → effective water.
        var r = Recipe(); r.doseGrams = 15
        r.setTotalWater(220)
        #expect(r.ratio != nil)
        let water = r.effectiveWaterGrams!
        #expect(abs(water - 220) < 0.0001)
    }

    @Test func settingTotalWaterWithoutDoseStoresExplicitOverride() {
        var r = Recipe()   // no dose yet
        r.setTotalWater(240)
        #expect(r.totalWaterGrams == 240)
        #expect(r.ratio == nil)
        #expect(r.effectiveWaterGrams == 240)
    }

    @Test func clearingTotalWaterWithKnownDoseClearsRatio() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 15
        r.setTotalWater(nil)
        #expect(r.ratio == nil)
        #expect(r.effectiveWaterGrams == nil)
    }

    @Test func clearingTotalWaterWithoutDoseClearsOverride() {
        var r = Recipe()
        r.setTotalWater(240)
        r.setTotalWater(nil)
        #expect(r.totalWaterGrams == nil)
        #expect(r.effectiveWaterGrams == nil)
    }

    @Test func changingRatioAfterTotalWaterKeepsThemInSync() {
        // The core bug report: editing ratio must still move the effective water even after the
        // total-water field has been touched — a naive implementation that stashes an explicit
        // `totalWaterGrams` override here would freeze water at the old value forever.
        var r = Recipe(); r.doseGrams = 15
        r.setTotalWater(225)          // ratio 15
        r.ratio = 16                  // edited directly via the ratio field
        #expect(r.effectiveWaterGrams == 240)
    }

    @Test func reconcileFoldsStandaloneTotalIntoRatioOnceDoseAppears() {
        // Total water typed before a dose was known must not stay pinned once a dose shows up —
        // otherwise every later ratio edit would be silently ignored.
        var r = Recipe()
        r.setTotalWater(240)           // no dose yet → explicit override
        r.doseGrams = 15
        r.reconcileTotalWaterWithDose()
        #expect(r.ratio == 16)
        #expect(r.totalWaterGrams == nil)
        #expect(r.effectiveWaterGrams == 240)
        // And it now tracks further ratio edits again.
        r.ratio = 15
        #expect(r.effectiveWaterGrams == 225)
    }

    @Test func reconcileIsNoOpWithoutAStandaloneTotal() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 15
        r.reconcileTotalWaterWithDose()
        #expect(r.ratio == 15)
        #expect(r.totalWaterGrams == nil)
    }

    @Test func reconcileIsNoOpWithoutADose() {
        var r = Recipe()
        r.setTotalWater(240)
        r.reconcileTotalWaterWithDose()
        #expect(r.totalWaterGrams == 240)
        #expect(r.ratio == nil)
    }

    // MARK: - Ratio display precision

    @Test func ratioTextRoundsHighPrecisionRatiosToTwoDecimals() {
        #expect(ratioText(220.0 / 15.0) == "14.67")
    }

    @Test func ratioTextDropsTrailingZerosAfterRounding() {
        #expect(ratioText(15.0) == "15")
        #expect(ratioText(15.5) == "15.5")
        #expect(ratioText(15.50) == "15.5")
        #expect(ratioText(15.001) == "15")
    }

    // MARK: - Pour-count safety

    @Test func suggestedTargetsStayBoundedAtTheDeclaredPourCountCeiling() {
        // Defends the fix for a live-typed pourCount transiently exceeding the field's range
        // (e.g. typing "150" walks through 1, 15, 150) — building a suggestion list at the
        // capped ceiling must stay cheap and correct rather than sizing off the raw input.
        var r = Recipe(); r.doseGrams = 15; r.ratio = 16
        let capped = Recipe.pourCountRange.upperBound
        let t = r.suggestedCumulativeTargets(count: capped)
        #expect(t.count == capped)
        #expect(t.last == 240)
        #expect(t == t.sorted())
    }

    // MARK: - Pour-breakdown reflow (the "next brew" bug)

    @Test func reflowPourCountGrowsAndRenumbersWithoutTouchingWeights() {
        var r = Recipe()
        r.pours = [Pour(order: 1, toGrams: 50), Pour(order: 2, toGrams: 100)]
        r.reflowPourCount(to: 4)
        #expect(r.pours.count == 4)
        #expect(r.pours.map(\.order) == [1, 2, 3, 4])
        // Existing rows' weights are untouched by a pure count resize.
        #expect(r.pours[0].toGrams == 50)
        #expect(r.pours[1].toGrams == 100)
        #expect(r.pours[2].toGrams == nil)
        #expect(r.pours[3].toGrams == nil)
    }

    @Test func reflowPourCountShrinksAndRenumbers() {
        var r = Recipe()
        r.pours = (1...5).map { Pour(order: $0, toGrams: Double($0) * 40) }
        r.reflowPourCount(to: 2)
        #expect(r.pours.count == 2)
        #expect(r.pours.map(\.order) == [1, 2])
        #expect(r.pours.map(\.toGrams) == [40, 80])
    }

    @Test func reflowPourWeightsOverwritesEveryRowWithTheCurrentSuggestion() {
        var r = Recipe(); r.doseGrams = 15; r.ratio = 16   // total 240
        r.pours = [Pour(order: 1, toGrams: 999), Pour(order: 2, toGrams: 999)]
        r.reflowPourWeights()
        #expect(r.pours.last?.toGrams == 240)
        #expect(r.pours.allSatisfy { ($0.toGrams ?? 0) < 999 })
    }

    @Test func carryingPoursIntoTheNextBrewThenChangingRatioReflowsToTheNewTotal() {
        // Models the reported bug end-to-end at the data level: brew N logs a 4-pour breakdown
        // at 1:15 (225g). Brew N+1 seeds from it (pours carried over verbatim, still summing to
        // 225g) and the ratio is bumped to 1:16 (240g) — the breakdown must reflect the new
        // total, not keep showing 225g.
        var brewOne = Recipe(); brewOne.doseGrams = 15; brewOne.ratio = 15
        brewOne.pourCount = 4
        brewOne.reflowPourCount(to: 4)
        brewOne.reflowPourWeights()
        #expect(brewOne.pours.last?.toGrams == 225)

        var brewTwo = brewOne   // seeded exactly like `Bean.seedRecipe(for:)` does
        brewTwo.ratio = 16
        #expect(brewTwo.effectiveWaterGrams == 240)
        // Before a reflow, the carried-over rows are stale (this is the bug, at the data level).
        #expect(brewTwo.pours.last?.toGrams == 225)
        brewTwo.reflowPourWeights()
        #expect(brewTwo.pours.last?.toGrams == 240)
    }

    // MARK: - The last pour is a live view of total water

    @Test func lastSuggestedTargetLandsExactlyOnTotalEvenWhenNotOnTheFiveGramGrid() {
        // 223g isn't a multiple of 5 — the last row must still show it exactly, since it *is*
        // total water, not a rounded suggestion. Interior pours still round to a practical grid.
        var r = Recipe(); r.doseGrams = 15
        r.setTotalWater(223)
        let t = r.suggestedCumulativeTargets(count: 4)
        // `total` here is dose × a derived ratio, so it round-trips to ~223 with float noise —
        // an exact `==` would be testing floating-point rounding, not the reflow logic.
        #expect(abs(t.last! - 223) < 0.0001)
        #expect(t.dropLast().allSatisfy { $0.truncatingRemainder(dividingBy: 5) == 0 })
    }

    @Test func editingLastPourThenReflowingRoundTripsTheExactTypedValue() {
        // Models the live last-row edit end-to-end: type an exact total via `setTotalWater` (what
        // the last pour's field now does), then the reflow that edit triggers — the last row must
        // come back to exactly what was typed, not get rounded away by its own reflow.
        var r = Recipe(); r.doseGrams = 15; r.ratio = 15
        r.reflowPourCount(to: 4)
        r.reflowPourWeights()
        r.setTotalWater(223)
        r.reflowPourWeights()
        #expect(abs(r.pours.last!.toGrams! - 223) < 0.0001)
        #expect(r.ratio == 223.0 / 15.0)
    }

    @Test func carryingPoursIntoTheNextBrewThenChangingPourCountReflowsRowCountAndWeights() {
        var brewOne = Recipe(); brewOne.doseGrams = 15; brewOne.ratio = 15
        brewOne.pourCount = 4
        brewOne.reflowPourCount(to: 4)
        brewOne.reflowPourWeights()

        var brewTwo = brewOne
        brewTwo.pourCount = 5
        brewTwo.reflowPourCount(to: 5)
        brewTwo.reflowPourWeights()
        #expect(brewTwo.pours.count == 5)
        #expect(brewTwo.pours.map(\.order) == [1, 2, 3, 4, 5])
        #expect(brewTwo.pours.last?.toGrams == 225)
        #expect(brewTwo.pours.map { $0.toGrams ?? 0 } == brewTwo.pours.map { $0.toGrams ?? 0 }.sorted())
    }
}
