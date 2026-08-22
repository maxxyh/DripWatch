import Foundation
import Testing
@testable import DripWatch

/// Exercises the per-method seeding/pending logic on standalone model objects (no
/// ModelContainer needed — these paths only touch stored properties and the `brews` array).
struct BeanSeedTests {

    @Test func sampleModeRequiresTheExplicitLaunchArgumentValue() {
        #expect(SampleData.isRequested(arguments: ["DripWatch", "-seedSampleData", "1"]))
        #expect(!SampleData.isRequested(arguments: ["DripWatch", "-seedSampleData", "0"]))
        #expect(!SampleData.isRequested(arguments: ["DripWatch", "-seedSampleData"]))
        #expect(!SampleData.isRequested(arguments: ["DripWatch"]))
    }

    @Test func seedFallsBackToLastBrewThenPending() {
        let bean = Bean(name: "Test")

        // Nothing yet → a fresh pourover starts from sensible defaults (not blank), while
        // espresso still starts empty.
        let fresh = bean.seedRecipe(for: .pourover)
        #expect(fresh.waterTempC == 92)
        #expect(fresh.bloomTimeSec == 30)
        #expect(fresh.ratio == 15)
        #expect(fresh.pourCount == 3)
        // Drawdown is intentionally left blank — a "see how it goes" number, not planned.
        #expect(fresh.totalDrawdownSec == nil)
        #expect(bean.seedRecipe(for: .espresso).isEmpty)

        // A logged brew becomes the seed.
        var r = Recipe(); r.waterTempC = 90
        let brew = Brew(brewedAt: .now, method: .pourover, recipe: r)
        brew.bean = bean
        bean.brews = [brew]
        #expect(bean.seedRecipe(for: .pourover).waterTempC == 90)

        // A pending "next brew" draft overrides the last brew.
        var plan = Recipe(); plan.waterTempC = 94
        bean.setPendingNextRecipe(plan, for: .pourover)
        #expect(bean.seedRecipe(for: .pourover).waterTempC == 94)
    }

    @Test func pendingPlansAreIndependentPerMethod() {
        let bean = Bean(name: "Test")

        var esp = Recipe(); esp.yieldGrams = 40
        bean.setPendingNextRecipe(esp, for: .espresso)

        #expect(bean.pendingNextRecipe(for: .espresso)?.yieldGrams == 40)
        #expect(bean.pendingNextRecipe(for: .pourover) == nil)
        // No pourover pending/last → pourover falls back to its defaults (temp seeded).
        #expect(bean.seedRecipe(for: .pourover).waterTempC == 92)
    }

    @Test func softDeletedBrewsAreExcludedFromTimeline() {
        let bean = Bean(name: "Test")
        let brew = Brew(brewedAt: .now, method: .pourover)
        brew.bean = bean
        bean.brews = [brew]
        #expect(bean.brewCount == 1)

        brew.deletedAt = .now
        #expect(bean.brewCount == 0)
        #expect(bean.lastBrew(for: .pourover) == nil)
    }

    @Test func purchaseValueUsesExactCentsAndLocaleSafeInput() {
        let bean = Bean(name: "Test")
        bean.priceSGDCents = 3_650
        bean.bagSizeGrams = 250
        #expect(bean.priceSGD == 36.5)
        #expect(bean.pricePerGramSGD == 0.146)

        bean.bagSizeGrams = nil
        #expect(bean.pricePerGramSGD == nil)

        let singapore = Locale(identifier: "en_SG")
        #expect(PurchaseValue.editingText(1_000, maxFractionDigits: 2, locale: singapore) == "1000")
        #expect(PurchaseValue.positiveNumber("1,000", locale: singapore) == 1_000)
        #expect(PurchaseValue.priceCents("36.50", locale: singapore) == 3_650)
        #expect(PurchaseValue.priceCents("36.501", locale: singapore) == nil)
        #expect(PurchaseValue.priceCents("9999999999.99", locale: singapore) == PurchaseValue.maximumPriceCents)
        #expect(PurchaseValue.priceCents("10000000000.00", locale: singapore) == nil)
        #expect(PurchaseValue.priceCents("999999999999999999999999", locale: singapore) == nil)

        let german = Locale(identifier: "de_DE")
        #expect(PurchaseValue.positiveNumber("1.000,5", locale: german) == 1_000.5)
        #expect(PurchaseValue.priceCents("36,50", locale: german) == 3_650)
        #expect(PurchaseValue.positiveNumber("32..00", locale: singapore) == nil)

        bean.priceSGDCents = PurchaseValue.maximumPriceCents
        bean.bagSizeGrams = .leastNonzeroMagnitude
        #expect(bean.pricePerGramSGD == nil)
    }
}
