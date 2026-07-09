import Testing
@testable import DripWatch

struct NormalizationTests {

    @Test func titleCasesPlainWords() {
        #expect("sugarcane".normalizedTerm == "Sugarcane")
        #expect("juicy grape".normalizedTerm == "Juicy Grape")
        #expect("berries jam".normalizedTerm == "Berries Jam")
        #expect("TROPICAL FRUIT".normalizedTerm == "Tropical Fruit")
        #expect("dark chocolate aftertaste".normalizedTerm == "Dark Chocolate Aftertaste")
    }

    @Test func preservesCodesAndAcronyms() {
        #expect("SL-34".normalizedTerm == "SL-34")
        #expect("THA1".normalizedTerm == "THA1")
        #expect("S795".normalizedTerm == "S795")
        #expect("USDA 762".normalizedTerm == "USDA 762")
    }

    @Test func keepsHyphenatedCasing() {
        #expect("Medium-Light".normalizedTerm == "Medium-Light")
        #expect("medium-dark".normalizedTerm == "Medium-Dark")
    }

    @Test func dedupesNormalizedArray() {
        #expect(["Berries", "berries", "Citrus Juice"].normalizedTerms == ["Berries", "Citrus Juice"])
    }
}
