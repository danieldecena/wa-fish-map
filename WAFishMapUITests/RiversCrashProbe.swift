import XCTest

/// Throwaway probe: prove the Rivers layer no longer kills the app.
///
/// Shipped 1.0 added one overlay per river reach — 18,287 of them — and
/// `MKMapView.addOverlays` held the main thread past the 10-second scene-update
/// watchdog, so iOS killed the process with `0x8BADF00D` the moment Rivers was
/// tapped on a real iPhone (2026-09-17, crash report `WAFishMap-2026-09-17-142141`).
///
/// Taps by coordinate rather than `tap()`. On this map every chrome control
/// reports `isHittable == false`, because the full-screen `MKMapView` is a later
/// sibling of the chrome and so sits above it for XCUITest's hit test; an earlier
/// run of this probe "passed" without the toggle ever flipping.
@MainActor
final class RiversCrashProbe: XCTestCase {
    func testTappingRiversDoesNotKillTheApp() {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) { button.tap(); break }
        }

        let rivers = app.descendants(matching: .any).matching(identifier: "riversToggle").firstMatch
        XCTAssertTrue(rivers.waitForExistence(timeout: 60),
                      "no Rivers control on screen: \(app.switches.allElementsBoundByIndex.map(\.label))")

        XCTAssertEqual(app.state, .runningForeground, "app was not up before the tap")
        print("RIVERSPROBE frame=\(rivers.frame) hittable=\(rivers.isHittable)")

        // The precondition the first attempt missed. MapKit builds drawables only
        // for overlays intersecting the add rect, so tapping Rivers at the
        // regional span the camera eases to after launch asks it for a fraction
        // of the work. Pulled back to the whole state every river is in rect,
        // which is the case the watchdog killed.
        let map = app.maps.firstMatch
        for _ in 0..<6 {
            map.twoFingerTap()
            usleep(400_000)
        }
        print("RIVERSPROBE zoomed out, state=\(app.state.rawValue)")

        let before = Date()
        rivers.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // The watchdog fires at 10s, so watch well past it. Key on the state, not
        // on a fixed sleep: a kill is what this is looking for.
        for _ in 0..<60 where app.state == .runningForeground {
            usleep(500_000)
        }
        let elapsed = Date().timeIntervalSince(before)
        print("RIVERSPROBE state after=\(app.state.rawValue) elapsed=\(String(format: "%.1f", elapsed))s")

        XCTAssertEqual(app.state, .runningForeground,
                       "The app left the foreground \(String(format: "%.1f", elapsed))s after tapping Rivers — the watchdog kill is back.")

        // The tap landing is not the same as the layer drawing. A river is only
        // selectable once its overlays exist, so opening one is the proof that
        // Rivers actually came on rather than the tap missing again.
        let sheet = app.descendants(matching: .any).matching(identifier: "riverDetailSheet").firstMatch
        var opened = false
        for spot in [CGVector(dx: 0.5, dy: 0.45), CGVector(dx: 0.45, dy: 0.55),
                     CGVector(dx: 0.55, dy: 0.5), CGVector(dx: 0.5, dy: 0.6)] {
            app.maps.firstMatch.coordinate(withNormalizedOffset: spot).tap()
            if sheet.waitForExistence(timeout: 5) { opened = true; break }
        }
        print("RIVERSPROBE riverSheetOpened=\(opened)")
        XCTAssertTrue(opened,
                      "No river was selectable after turning Rivers on, so the layer may never have drawn. On screen: \(app.staticTexts.allElementsBoundByIndex.map(\.label).prefix(20))")
        XCTAssertEqual(app.state, .runningForeground, "app died while opening a river")
    }
}
