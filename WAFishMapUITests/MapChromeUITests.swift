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

    /// On is either the selected trait or a switch-style value of "1",
    /// depending on how SwiftUI exposes a button-style toggle. Accepting both
    /// is not loose: a plain `Button` reports neither, before or after a tap,
    /// which is the defect.
    private static func isOn(_ e: XCUIElement) -> Bool {
        e.isSelected || (e.value as? String) == "1"
    }

    private func assertReportsState(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let app = launch()
        dismissSheet(app)
        let toggle = element(app, id)
        guard toggle.waitForExistence(timeout: 30) else {
            XCTFail("\(id) never appeared. On screen: \(Self.labels(app))", file: file, line: line)
            return
        }
        XCTAssertFalse(Self.isOn(toggle), "\(id) reads on before any tap.", file: file, line: line)
        for _ in 0..<20 where !toggle.isHittable {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        toggle.tap()
        for _ in 0..<20 where !Self.isOn(toggle) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(Self.isOn(toggle),
                      "\(id) still reads off after a tap (selected: \(toggle.isSelected), value: \(String(describing: toggle.value))).",
                      file: file, line: line)
        // Kept so the on-state can be looked at, not just asserted: the
        // contrast test assumes a white label on a filled capsule.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(id)-on"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testRiversToggleReportsItsState() {
        assertReportsState("riversToggle")
    }

    func testHeatToggleReportsItsState() {
        assertReportsState("heatToggle")
    }
}
