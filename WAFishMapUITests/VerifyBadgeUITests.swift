import XCTest

/// Retires the "proven by tests and by reading the diff, not by observation"
/// caveat on the verify badge: this run puts the badge on a real screen and
/// asserts it is there.
///
/// Under `-uiTesting` the app loads the bundled fixture (Boston Harbor, marine
/// area 13) and preselects the first site, so the sheet is up without a
/// synthesised tap — injected taps were unreliable for a whole session, which is
/// why this observation had never been made.
///
/// The assertions deliberately do not hardcode how many species a month flags.
/// A first draft did, and was wrong in both directions, because it reimplemented
/// `inSeason(month:)` in the test and disagreed with the app. A test that
/// restates the rule it is checking cannot catch the rule being wrong.
final class VerifyBadgeUITests: XCTestCase {
    private func launch(month: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-planMonth", month]
        app.launch()
        return app
    }

    /// Waiting for the sheet before querying is not politeness: a cold first
    /// launch took 193s, so a query that starts its clock at launch expires
    /// while the map is still loading and reports an absent badge.
    private func sheet(_ app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) {
        let sheet = app.descendants(matching: .any)["siteDetailSheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 120),
                      "The detail sheet never came up, so nothing below proves anything.",
                      file: file, line: line)
    }

    private func count(_ app: XCUIApplication, _ id: String) -> Int {
        app.descendants(matching: .any).matching(identifier: id).count
    }

    /// The observation this target exists for: the badge is on screen, in a
    /// month where area 13 has flagged species.
    func testVerifyBadgeIsOnScreenForASeasonCappedSpecies() {
        let app = launch(month: "7")
        sheet(app)

        XCTAssertGreaterThan(count(app, "verifyBadge"), 0,
                             "The season-varies badge never appeared for a capped species.")
    }

    /// The buoy section is wired into the marine sheet. Asserts the section is
    /// present, not what it says: the readings come from a live NDBC fetch, so
    /// asserting a number here would make the test fail whenever a buoy is down
    /// — a test of NOAA's uptime, not of this app.
    func testTheBuoySectionIsPresentOnAMarineSite() {
        let app = launch(month: "7")
        sheet(app)

        let section = app.descendants(matching: .any)["buoySection"].firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 30),
                      "The on-the-water section is missing from a marine site sheet.")
    }

    /// The observation the WeatherKit task exists for: a live wind speed on a
    /// real screen. WeatherKit mints a JWT from the provisioning profile, and a
    /// Simulator build is ad-hoc signed with none, so this can only mean
    /// anything on hardware — hence the skip rather than a weaker assertion.
    ///
    /// `-uiTesting` puts the sheet up without a synthesised tap but does not
    /// stub the forecast: `PlanWeatherView` still calls `WeatherService` for
    /// real, at Boston Harbor.
    ///
    /// The footer is the success sentinel, not the wind row: it renders only
    /// when a `PlanWeather` exists, so it separates a real reading from the
    /// spinner in a way that a substring match alone does not.
    func testWindReadsARealValueOnDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("WeatherKit cannot sign a Simulator build. Run scripts/verify_weatherkit_device.sh.")
        #else
        let app = launch(month: "7")
        sheet(app)

        let forecast = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'not an observation'")).firstMatch
        XCTAssertTrue(forecast.waitForExistence(timeout: 60),
                      "The forecast never resolved, so no live reading was observed.")

        let wind = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS ' mph'")).firstMatch
        XCTAssertTrue(wind.exists, "The forecast resolved but no wind speed was drawn.")

        XCTAssertFalse(app.staticTexts["Wind and rain unavailable right now."].exists,
                       "The section reported unavailable — the live fetch failed on device.")
        #endif
    }

    /// The control. Every month in area 13 flags something, so an absence test
    /// is impossible here — but selectivity is still checkable: the badge must
    /// appear on *some* species and not all of them. A badge rendered
    /// unconditionally passes the test above and fails this one.
    func testTheBadgeMarksSomeSpeciesAndNotEveryOne() {
        let app = launch(month: "7")
        sheet(app)

        let badges = count(app, "verifyBadge")
        let cards = count(app, "speciesName")

        XCTAssertGreaterThan(cards, 0, "No species were listed, so this proves nothing.")
        XCTAssertGreaterThan(badges, 0, "No species carried the badge.")
        XCTAssertLessThan(badges, cards,
                          "Every listed species carried the badge — it is not selective.")
    }
}
