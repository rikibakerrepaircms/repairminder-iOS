import Testing
@testable import Repair_Minder

struct ResultTileAppearanceTests {
    @Test func partialIsDistinctFromSkip() {
        let partial = ResultTilePresentation.appearance(for: .partial)
        let skip = ResultTilePresentation.appearance(for: .skip)
        #expect(partial.icon != skip.icon)
        #expect(partial.statusWord != skip.statusWord)
        #expect(partial.statusWord == "Partial")
        #expect(skip.statusWord == "Skipped")
    }

    @Test func statusWordsAreStable() {
        #expect(ResultTilePresentation.appearance(for: .pass).statusWord == "Passed")
        #expect(ResultTilePresentation.appearance(for: .fail).statusWord == "Failed")
        #expect(ResultTilePresentation.appearance(for: .error).statusWord == "Error")
    }

    @Test func accessibilityLabelComposesNameAndStatus() {
        #expect(ResultTilePresentation.accessibilityLabel(name: "Camera", status: .pass) == "Camera: Passed")
        #expect(ResultTilePresentation.accessibilityLabel(name: "Wi-Fi", status: .partial) == "Wi-Fi: Partial")
    }
}
