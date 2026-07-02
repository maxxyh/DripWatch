import Testing
@testable import DripWatch

/// Exercises the per-method seeding/pending logic on standalone model objects (no
/// ModelContainer needed — these paths only touch stored properties and the `brews` array).
struct BeanSeedTests {

    @Test func seedFallsBackToLastBrewThenPending() {
        let bean = Bean(name: "Test")

        // Nothing yet → a fresh pourover starts from sensible defaults (not blank), while
        // espresso still starts empty.
        let fresh = bean.seedRecipe(for: .pourover)
        #expect(fresh.waterTempC == 92)
        #expect(fresh.bloomTimeSec == 30)
        #expect(fresh.totalDrawdownSec == 150)
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
}
