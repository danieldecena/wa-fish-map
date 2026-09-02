import XCTest

/// Retires the "proven by tests and by reading the diff, not by observation"
/// caveat on the verify badge: this run puts the badge on a real screen and
/// asserts it is there.
///
/// Under `-uiTesting` the app loads the bundled fixture (Boston Harbor, marine
/// area 13) and preselects the first site, so the sheet is up without a
/// synthesised tap — injected taps were unreliable for a whole session, which is
/// why this observation had never been made.
final class VerifyBadgeUITests: XCTestCase {
    private func launch(month: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-planMonth", month]
        app.launch()
        return app
    }

    /// Waiting for the sheet before querying the badge is not politeness: a cold
    /// first launch took 193s, so a query that starts its own clock at launch
    /// expires while the map is still loading and reports an absent badge.
    private func waitForSheet(_ app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        let sheet = app.descendants(matching: .any)["siteDetailSheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 120),
                      "The detail sheet never came up, so nothing below proves anything.",
                      file: file, line: line)
    }

    private func badgeCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(identifier: "verifyBadge").count
    }

    /// July flags exactly two of area 13's in-season species — Crab Snaring
    /// (shore) and Dungeness Crab.
    func testVerifyBadgeAppearsOnEverySeasonCappedSpecies() {
        let app = launch(month: "7")
        waitForSheet(app)

        XCTAssertEqual(badgeCount(app), 2,
                       "Expected a badge on each of July's two flagged species.")
    }

    /// The control. Every month in area 13 flags *something*, so an absence test
    /// is impossible here — but the count is not: March flags exactly one
    /// species (Resident Chinook), so a badge that rendered unconditionally, or
    /// on a fixed species, fails this while passing the test above.
    func testTheBadgeCountFollowsTheMonthBeingPlanned() {
        let app = launch(month: "3")
        waitForSheet(app)

        XCTAssertEqual(badgeCount(app), 1,
                       "Expected exactly one badge for March's single flagged species.")
    }
}
