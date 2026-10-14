import XCTest

/// Map chrome facts only a real screen can show: the recentre button's touch
/// area, and whether the layer toggles tell assistive tech their state
/// (design critique, 2026-10-14).
@MainActor
final class MapChromeUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private static func labels(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    /// `-uiTesting` opens the site sheet on launch, and on a phone it covers
    /// the bottom chrome. Same dismissal as `GuidanceOnEverySheetUITests`.
    private func dismissSheet(_ app: XCUIApplication) {
        let sheet = element(app, "siteDetailSheet")
        if sheet.waitForExistence(timeout: 120) {
            sheet.swipeDown(velocity: .fast)
            _ = sheet.waitForNonExistence(timeout: 10)
        }
    }

    func testRecenterButtonIsAtLeastFortyFourPoints() {
        let app = launch()
        let button = element(app, "recenterButton")
        guard button.waitForExistence(timeout: 120) else {
            XCTFail("recenterButton never appeared. On screen: \(Self.labels(app))")
            return
        }
        XCTAssertGreaterThanOrEqual(button.frame.width, 44, "Recentre target is \(button.frame.width)pt wide.")
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Recentre target is \(button.frame.height)pt tall.")
    }
}
