import Foundation
import SwiftData

/// DEBUG-only seed data for verification/screenshots. Sample mode uses an isolated in-memory
/// store with remote sync disabled, so these fixtures can never persist or reach Supabase.
enum SampleData {
    static var isRequested: Bool {
        isRequested(arguments: ProcessInfo.processInfo.arguments)
    }

    static func isRequested(arguments: [String]) -> Bool {
        arguments.indices.contains { index in
            arguments[index] == "-seedSampleData"
                && arguments.indices.contains(index + 1)
                && arguments[index + 1] == "1"
        }
    }

    static func seedIfRequested(_ context: ModelContext) {
        #if DEBUG
        guard isRequested else { return }
        let existing = try? context.fetch(FetchDescriptor<Bean>())
        guard (existing?.isEmpty ?? true) else { return }

        let cal = Calendar.current
        func day(_ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: m, day: d)) ?? .now
        }

        // Voyager — matches the notebook page.
        let voyager = Bean(name: "La Femme d'Argent")
        voyager.roasterName = "Voyager Craft Coffee"
        voyager.country = "Peru"
        voyager.region = "Santa Clara"
        voyager.varietal = "Typica, Caturra, Pache"
        voyager.process = "Washed"
        voyager.roastLevel = "Medium"
        voyager.roastDate = day(5, 6)
        voyager.roasterNotes = "Dates, vanilla, apple"
        voyager.priceSGDCents = 3_650
        voyager.bagSizeGrams = 250
        voyager.myFlavorTags = ["honey", "apple"]
        context.insert(voyager)

        let jMax = "1Zpresso J"

        let b1 = Brew(brewedAt: day(6, 22), method: .pourover, recipe: {
            var r = Recipe()
            r.grind = GrindSetting(grinderName: jMax, major: 3, clickOffset: 0)
            r.waterTempC = 92; r.doseGrams = 15; r.ratio = 16; r.pourCount = 4
            r.totalDrawdownSec = 135
            r.pours = [Pour(order: 1, toGrams: 50, startSec: 0, endSec: 12),
                       Pour(order: 2, toGrams: 150, startSec: 45, endSec: 58),
                       Pour(order: 3, toGrams: 220, startSec: 80, endSec: 92),
                       Pour(order: 4, toGrams: 320, startSec: 105, endSec: 118, style: "centre")]
            return r
        }())
        b1.taste = { var t = Taste(); t.positives = ["honey"]; t.negatives = ["grapefruit", "bitter"]
            t.balance = TasteBalance(acidity: 4, sweetness: 3, bitterness: 3, body: 3); t.rating = 3
            t.note = "sweet up front but the bitterness built up toward the end"; return t }()
        b1.bean = voyager
        context.insert(b1)

        let b2 = Brew(brewedAt: day(6, 23), method: .pourover, recipe: {
            var r = Recipe()
            r.grind = GrindSetting(grinderName: jMax, major: 3, clickOffset: -1)
            r.waterTempC = 89; r.doseGrams = 15; r.ratio = 16; r.pourCount = 4
            r.totalDrawdownSec = 135
            return r
        }())
        b2.taste = { var t = Taste(); t.positives = ["okay aftertaste"]; t.negatives = ["not sweet", "sour/salty"]
            t.balance = TasteBalance(acidity: 5, sweetness: 2, bitterness: 2, body: 2); t.rating = 2; return t }()
        b2.bean = voyager
        context.insert(b2)

        // The pending plan for the next pourover. asPlanSeed drops the measured drawdown — you
        // plan the dials, not the number you sit and watch.
        voyager.pendingNextPourover = {
            var r = b2.recipe.asPlanSeed
            r.grind = GrindSetting(grinderName: jMax, major: 3, clickOffset: 1)   // back finer
            r.waterTempC = 91
            r.notes = "meet in the middle: finer than 23/06, hotter"
            return r
        }()
        b2.nextRecipeDraft = voyager.pendingNextPourover

        // A second bean for the shelf grid, with an espresso brew to show the espresso flow.
        let crimson = Bean(name: "Crimson")
        crimson.roasterName = "96B Café & Roastery"
        crimson.country = "Vietnam"
        crimson.region = "Quang Tri"
        crimson.varietal = "THA1"
        crimson.process = "Anoxic Natural"
        crimson.roasterNotes = "Pineapple, dried guava, prune, dark chocolate"
        crimson.priceSGDCents = 2_800
        crimson.bagSizeGrams = 200
        crimson.myFlavorTags = ["raisin", "dark chocolate"]
        context.insert(crimson)

        let esp = Brew(brewedAt: day(6, 24), method: .espresso, recipe: {
            var r = Recipe()
            r.grind = GrindSetting(grinderName: "Niche Zero", major: 12, clickOffset: 0)
            r.doseGrams = 18; r.yieldGrams = 36; r.shotTimeSec = 28
            // Gaggia Classic Pro manual technique (no PID / no pressure gauge).
            r.preInfusionSec = 6; r.surfWaitSec = 8; r.steamModeSec = 4
            return r
        }())
        esp.taste = { var t = Taste(); t.positives = ["syrupy", "red plum"]; t.negatives = ["slightly sharp"]; t.rating = 4; return t }()
        esp.bean = crimson
        context.insert(esp)
        crimson.pendingNextEspresso = {
            var r = esp.recipe.asPlanSeed   // drops the measured shot time — not a planned dial
            r.grind = GrindSetting(grinderName: "Niche Zero", major: 11, clickOffset: 0)   // finer
            r.surfWaitSec = 11; r.preInfusionSec = 8
            r.notes = "finer, longer surf & pre-infusion to tame the sharpness"
            return r
        }()
        esp.nextRecipeDraft = crimson.pendingNextEspresso

        try? context.save()
        #endif
    }
}
