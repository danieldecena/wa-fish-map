import XCTest

/// Every screen that shows seasonal guidance must carry the disclaimer and a WDFW
/// link (CLAUDE.md). The three detail sheets share `GuidanceFooter`, so one sheet
/// dropping it is a single deleted line that no unit test notices; this runs each
/// sheet for real and reads what is on screen.
@MainActor
final class GuidanceOnEverySheetUITests: XCTestCase {
    private static let linkLabel = "Verify seasons & limits at WDFW"

    private func launch(detail: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingDetail", detail]
        app.launch()
        return app
    }

    private static func labels(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// The footer sits at the bottom of a long sheet that opens at the medium
    /// detent, so it is scrolled to rather than assumed visible.
    private func assertFooter(sheetID: String, detail: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let app = launch(detail: detail)
        let sheet = element(app, sheetID)
        guard sheet.waitForExistence(timeout: 120) else {
            XCTFail("\(sheetID) never came up, so nothing below proves anything. On screen: \(Self.labels(app))",
                    file: file, line: line)
            return
        }

        let footer = element(app, "guidanceFooter")
        for _ in 0..<12 where !(footer.exists && footer.isHittable) {
            sheet.swipeUp()
        }
        XCTAssertTrue(footer.exists, "No guidance footer on \(sheetID). On screen: \(Self.labels(app))",
                      file: file, line: line)

        let link = footer.descendants(matching: .any).matching(identifier: "wdfwLink").firstMatch
        XCTAssertTrue(link.exists, "No WDFW link on \(sheetID). On screen: \(Self.labels(app))",
                      file: file, line: line)
        XCTAssertEqual(link.label, Self.linkLabel, file: file, line: line)

        let disclaimer = footer.descendants(matching: .any).matching(identifier: "guidanceDisclaimer").firstMatch
        XCTAssertTrue(disclaimer.exists, "No disclaimer on \(sheetID). On screen: \(Self.labels(app))",
                      file: file, line: line)
        XCTAssertFalse(disclaimer.label.isEmpty, "Empty disclaimer on \(sheetID)", file: file, line: line)
    }

    func testSiteSheetCarriesDisclaimerAndWDFWLink() {
        assertFooter(sheetID: "siteDetailSheet", detail: "site")
    }

    func testPierSheetCarriesDisclaimerAndWDFWLink() {
        assertFooter(sheetID: "pierDetailSheet", detail: "pier")
    }

    func testRiverSheetCarriesDisclaimerAndWDFWLink() {
        assertFooter(sheetID: "riverDetailSheet", detail: "river")
    }

    func testInfoPopoverCarriesWDFWLink() {
        let app = launch(detail: "site")
        let button = element(app, "guidanceInfoButton")
        guard button.waitForExistence(timeout: 120) else {
            XCTFail("Info button never appeared. On screen: \(Self.labels(app))")
            return
        }
        // The launch opens the site sheet, which covers the status bar on a phone.
        let sheet = element(app, "siteDetailSheet")
        if sheet.waitForExistence(timeout: 30) {
            sheet.swipeDown(velocity: .fast)
            // The dismiss is animated; tapping mid-animation lands on the sheet,
            // not the button underneath it, and the popover never opens.
            _ = sheet.waitForNonExistence(timeout: 10)
        }
        for _ in 0..<20 where !button.isHittable {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(button.isHittable, "guidanceInfoButton never became hittable. On screen: \(Self.labels(app))")
        button.tap()

        let link = element(app, "wdfwLink")
        XCTAssertTrue(link.waitForExistence(timeout: 10),
                      "Popover has no WDFW link. On screen: \(Self.labels(app)). Tree: \(app.debugDescription)")
        XCTAssertEqual(link.label, Self.linkLabel)
    }
}
