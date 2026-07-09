import Testing
import CoreGraphics
@testable import DripWatch

struct BagOCRTests {

    /// Builds a line with a normalized bounding box (Vision origin bottom-left).
    private func line(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.05) -> OCRLine {
        OCRLine(text: text, box: CGRect(x: x, y: y, width: w, height: h))
    }

    @Test func columnarLayoutPairsLabelsToValuesByPosition() {
        // A two-column bag: labels on the left, values on the right, aligned per row.
        let lines = [
            line("REGION", x: 0.10, y: 0.60), line("Cau Dat", x: 0.55, y: 0.60),
            line("VARIETY", x: 0.10, y: 0.50), line("Catimor", x: 0.55, y: 0.50),
            line("PROCESS", x: 0.10, y: 0.40), line("Washed", x: 0.55, y: 0.40),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.region == "Cau Dat")
        #expect(bag.varietal == "Catimor")
        #expect(bag.process == "Washed")
    }

    @Test func inlineLabelsParseValueAfterColon() {
        let lines = [
            line("ZONE: huong phung", x: 0.1, y: 0.5, w: 0.6),
            line("PROCESSING: anoxic natural", x: 0.1, y: 0.4, w: 0.6),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.region == "Huong phung")
        #expect(bag.process == "Anoxic natural")
    }

    @Test func nameIsLargestPrintNotAProcessWord() {
        // The process word "WASHED" is printed larger than the coffee's name, but must not win.
        let lines = [
            line("Pure Forest", x: 0.2, y: 0.8, w: 0.5, h: 0.06),
            line("WASHED", x: 0.2, y: 0.3, w: 0.4, h: 0.10),   // bigger, but a process word
            line("1850 masl", x: 0.2, y: 0.2, w: 0.4, h: 0.09), // bigger, but numeric
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.name == "Pure Forest")
    }

    @Test func labellessBlendClassifiedByContent() {
        // The "Lazy Sunday" espresso blend: no field labels, just descriptive lines.
        let lines = [
            line("Lazy Sunday", x: 0.1, y: 0.9, w: 0.6, h: 0.08),
            line("Brazil Catuai varietal, Natural", x: 0.1, y: 0.7, w: 0.7),
            line("Colombia Mix varietal, Washed", x: 0.1, y: 0.6, w: 0.7),
            line("Caramel Nuttiness, Milk Chocolate", x: 0.1, y: 0.3, w: 0.7),
            line("Espresso - Medium roast", x: 0.1, y: 0.2, w: 0.7),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.name == "Lazy Sunday")
        #expect(bag.country?.contains("Brazil") == true)
        #expect(bag.country?.contains("Colombia") == true)
        #expect(bag.varietal?.contains("Catuai") == true)
        #expect(bag.process == "Washed" || bag.process == "Natural")
        #expect(bag.roastLevel == "Medium")
        #expect(bag.roasterNotes?.lowercased().contains("chocolate") == true)
    }

    @Test func learnedTermIsClassified() {
        // A term the user previously filed as a variety is picked up automatically.
        let lines = [
            line("Morning Star", x: 0.1, y: 0.9, w: 0.6, h: 0.08),   // the name (largest print)
            line("Zephyrine", x: 0.1, y: 0.5, w: 0.5),
        ]
        let plain = BagOCR.parse(lines)
        #expect(plain.varietal == nil)
        #expect(plain.unresolved.contains("Zephyrine"))

        let taught = BagOCR.parse(lines, learned: ["zephyrine": .varietal])
        #expect(taught.varietal == "Zephyrine")
        #expect(!taught.unresolved.contains("Zephyrine"))
    }

    @Test func crimsonMultiLineTasteNotes() {
        // Real OCR from the Crimson bag: a "TASTE NOTES:" label with the notes wrapping onto a
        // second line. Previously the whole thing was ignored.
        let lines = [
            line("crimson", x: 0.3, y: 0.90, w: 0.4, h: 0.06),
            line("#2 VIETNAM AMAZING CUP 2021 ARABICA CATEGORY", x: 0.1, y: 0.80, w: 0.8),
            line("ZONE: huong phung, huong hoa, quang tri", x: 0.1, y: 0.70, w: 0.8),
            line("VARIETY: THA1", x: 0.1, y: 0.55, w: 0.4),
            line("PROCESSING: anoxic natural", x: 0.1, y: 0.48, w: 0.5),
            line("TASTE NOTES: pineapple, dried guava, prune,", x: 0.1, y: 0.40, w: 0.8),
            line("dark chocolate aftertaste", x: 0.1, y: 0.36, w: 0.5),
            line("(18:210) 96B", x: 0.1, y: 0.20, w: 0.3),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.name == "crimson")
        #expect(bag.varietal == "THA1")
        #expect(bag.process?.lowercased().contains("anoxic natural") == true)
        #expect(bag.country == "Vietnam")
        let notes = (bag.roasterNotes ?? "").lowercased()
        #expect(notes.contains("pineapple"))
        #expect(notes.contains("dried guava"))
        #expect(notes.contains("prune"))
        #expect(notes.contains("dark chocolate aftertaste"))
    }

    @Test func verticalColumnarLabelsPairDownward() {
        // Real OCR from the Ijen Lestari bag: labels stacked *above* their values (PRODUCER over
        // "The Dharmawan Family", VARIETIES over "USDA 762, Kartika"), in two side-by-side columns.
        let lines = [
            line("IJEN LESTARI", x: 0.30, y: 0.55, w: 0.40, h: 0.030),
            line("ORIGIN:", x: 0.18, y: 0.37, w: 0.07, h: 0.015),
            line("EAST JAVA, INDONESIA", x: 0.19, y: 0.35, w: 0.20, h: 0.016),
            line("PROCESSING:", x: 0.19, y: 0.31, w: 0.12, h: 0.019),
            line("PRODUCER:", x: 0.51, y: 0.30, w: 0.11, h: 0.013),
            line("CARBONIC MACERATION NATURAL", x: 0.19, y: 0.29, w: 0.29, h: 0.021),
            line("THE DHARMAWAN FAMILY", x: 0.51, y: 0.29, w: 0.22, h: 0.017),
            line("VARIETIES:", x: 0.19, y: 0.26, w: 0.10, h: 0.017),
            line("USDA 762, KARTIKA", x: 0.20, y: 0.24, w: 0.16, h: 0.020),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.farm?.uppercased().contains("DHARMAWAN") == true)
        #expect(bag.varietal?.uppercased().contains("USDA 762") == true)
        #expect(bag.varietal?.uppercased().contains("KARTIKA") == true)
        #expect(bag.process?.lowercased().contains("carbonic maceration") == true)
        #expect(bag.country?.contains("Java") == true)
    }

    @Test func pipeSeparatedLabelsAndNotes() {
        // Alo Coffee: "|"-separated inline labels and notes.
        let lines = [
            line("FILTER", x: 0.15, y: 0.90, w: 0.1),
            line("ALO COFFEE", x: 0.4, y: 0.55, w: 0.4, h: 0.05),
            line("NATURAL ANAEROBIC ETHIOPIA", x: 0.35, y: 0.47, w: 0.5),
            line("MANGO | PURPLE GRAPE | WHITE PEACH", x: 0.35, y: 0.40, w: 0.5),
            line("PRODUCER | TAMIRU TADESSE", x: 0.5, y: 0.18, w: 0.4),
            line("VARIETAL | 74158", x: 0.5, y: 0.15, w: 0.3),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.name == "ALO COFFEE")
        #expect(bag.country?.lowercased() == "ethiopia")
        #expect(bag.farm?.uppercased().contains("TAMIRU TADESSE") == true)
        #expect(bag.varietal == "74158")
        #expect(bag.process?.lowercased().contains("natural anaerobic") == true)
        let notes = (bag.roasterNotes ?? "").lowercased()
        #expect(notes.contains("mango") && notes.contains("purple grape") && notes.contains("white peach"))
    }

    @Test func fincaFarmIsNotMistakenForVariety() {
        // "Finca Varietales" contains "varietal" but is a farm, not a variety label; the notes and
        // farm share a "|". The origin header must not become the name.
        let lines = [
            line("colombia", x: 0.4, y: 0.90, w: 0.3, h: 0.04),
            line("Yenifer Rojas Trujillo", x: 0.3, y: 0.82, w: 0.5, h: 0.03),
            line("Finca Varietales | blackberry, tropical fruits, floral", x: 0.15, y: 0.74, w: 0.7),
        ]
        let bag = BagOCR.parse(lines)
        #expect(bag.name == "Yenifer Rojas Trujillo")
        #expect(bag.country?.lowercased() == "colombia")
        #expect(bag.farm?.contains("Finca Varietales") == true)
        #expect(bag.varietal == nil)
        let notes = (bag.roasterNotes ?? "").lowercased()
        #expect(notes.contains("blackberry") && notes.contains("tropical fruits") && notes.contains("floral"))
    }

    @Test func aValueIsNotClaimedByTwoFields() {
        // One value line on a shared row must be consumed by the first matching label only.
        let lines = [
            line("FARM", x: 0.10, y: 0.50), line("REGION", x: 0.30, y: 0.50),
            line("El Paraiso", x: 0.60, y: 0.50),
        ]
        let bag = BagOCR.parse(lines)
        // Exactly one of farm/region gets it; they don't both.
        #expect((bag.farm == nil) != (bag.region == nil))
    }
}
