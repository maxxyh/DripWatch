import Testing
@testable import DripWatch

struct TasteTests {

    @Test func newTasteIsEmpty() {
        #expect(Taste().isEmpty)
    }

    @Test func chipsMakeItNonEmpty() {
        var t = Taste(); t.positives = ["honey"]
        #expect(!t.isEmpty)
    }

    @Test func aFreeTextNoteAloneMakesItNonEmpty() {
        var t = Taste(); t.note = "opened up as it cooled"
        #expect(!t.isEmpty)
    }

    @Test func blankNoteDoesNotCount() {
        var t = Taste(); t.note = ""
        #expect(t.isEmpty)
    }

    @Test func whitespaceOnlyNoteDoesNotCount() {
        var t = Taste(); t.note = "  \n "
        #expect(t.isEmpty)
    }
}
