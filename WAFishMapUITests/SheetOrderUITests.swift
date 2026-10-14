import XCTest

/// The detail sheets open at the medium detent, and what fits there is what
/// most people read. "What's biting" is the one section no other app has, so
/// it has to be on that first screen rather than ninth in a scroll (design
/// critique, 2026-10-14).
///
/// Asserted two ways because each alone can pass wrongly: an order check
/// passes on a sheet short enough to need no scrolling, and a hittable check
/// passes on a tall enough screen whatever the order.
@MainActor
final class SheetOrderUITests: XCTestCase {
    private func launch(detail: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingDetail", detail]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private static func labels(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    private func assertBitingLeads(sheetID: String, detail: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let app = launch(detail: detail)
        let sheet = element(app, sheetID)
        guard sheet.waitForExistence(timeout: 120) else {
            XCTFail("\(sheetID) never came up, so nothing below proves anything. On screen: \(Self.labels(app))",
                    file: file, line: line)
            return
        }
        let biting = element(app, "whatsBitingHeading")
        let daylight = element(app, "daylightHeading")
        // Both must exist before their positions mean anything: a missing
        // element's frame is .zero, and zero sits above everything.
        guard biting.waitForExistence(timeout: 10), daylight.exists else {
            XCTFail("Missing heading (biting: \(biting.exists), daylight: \(daylight.exists)). On screen: \(Self.labels(app))",
                    file: file, line: line)
            return
        }
        XCTAssertLessThan(biting.frame.minY, daylight.frame.minY,
                          "What's biting sits below Daylight on \(sheetID).", file: file, line: line)
        XCTAssertTrue(biting.isHittable,
                      "What's biting is off screen at the sheet's opening height on \(sheetID).",
                      file: file, line: line)
    }

    func testSiteSheetLeadsWithWhatsBiting() {
        assertBitingLeads(sheetID: "siteDetailSheet", detail: "site")
    }

    func testPierSheetLeadsWithWhatsBiting() {
        assertBitingLeads(sheetID: "pierDetailSheet", detail: "pier")
    }
}
