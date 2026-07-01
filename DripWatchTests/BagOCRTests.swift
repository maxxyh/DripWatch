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
