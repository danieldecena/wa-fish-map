import Testing
@testable import WAFishMap

/// `-planYear` exists so a UI test that pins `-planMonth` can pin the year too.
/// Without it an odd-year species (Pink Salmon) rates by the simulator clock's
/// year, and the same test flips result on the next New Year.
struct UITestSeamTests {
    @Test func planYearReadsTheValueAfterTheFlag() {
        #expect(UITestSeam.planYear(from: ["-uiTesting", "-planYear", "2025"]) == 2025)
    }

    @Test func planYearIsNilWhenTheFlagIsAbsent() {
        #expect(UITestSeam.planYear(from: ["-uiTesting", "-planMonth", "8"]) == nil)
    }

    /// A missing or non-numeric value reads as unset, the same as `-planMonth`,
    /// so a typo fails on the assertion rather than planning for some other year.
    @Test func planYearIsNilWhenTheValueIsMissingOrNotANumber() {
        #expect(UITestSeam.planYear(from: ["-planYear"]) == nil)
        #expect(UITestSeam.planYear(from: ["-planYear", "twenty"]) == nil)
    }
}
