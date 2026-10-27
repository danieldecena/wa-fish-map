import XCTest

/// A touch on the edge of a pin's 44pt target, outside the drawn balloon,
/// selects the pin.
///
/// This is the half of the tap-target claim that geometry cannot show, and it
/// proves less than it sounds. Measured on the iOS 27 simulator
/// (2026-10-14, re-measured 2026-10-18), a lone pin is selected by a tap out
/// to about 50pt to either side and 54pt above its centre, and only 25pt below
/// it: MapKit's own touch slop, not the 44pt `MarkerMetrics.hitRect`.
///
/// The rect is not consulted at all. Each of these left the reach identical
/// and this test green: `minimumTapTarget` at 1pt, at 140pt, and
/// `point(inside:)` returning `false` for every touch. So a control tap "just
/// outside" the target cannot be built, and no simulator UI test can go red on
/// a wrong target size. This guards that a pin stays selectable from its edge
/// in all four directions, not that the rect is what makes it so. Whether
/// hardware honours `hitRect` is not observed.
@MainActor
final class MarkerEdgeTapUITests: XCTestCase {
    /// Same fixture as `PinSpokenTextUITests`: Boston Harbor, clear of the
    /// sheet's medium detent.
    private static let region = "47.1347,-122.9055,0.02"

    /// A point inside the 44pt target and outside the drawn balloon, which is
    /// about 22 x 31pt at the 0.8 scale.
    private static let inside: CGFloat = 19

    private func launchWithPinDeselected() -> (XCUIApplication, XCUIElement, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingRegion", Self.region]
        app.launch()

        let sheet = app.descendants(matching: .any)["siteDetailSheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 120),
                      "The fixture's sheet never came up, so the map is not loaded.")

        let map = app.maps.firstMatch
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)).tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10),
                      "A tap on bare map did not deselect the pin.")

        let pin = map.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Boston Harbor")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 30),
                      "Nothing on the map is labelled Boston Harbor.")
        return (app, pin, sheet)
    }

    private func tap(_ pin: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let centre = pin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centre.withOffset(CGVector(dx: dx, dy: dy)).tap()
    }

    func testAPinIsSelectableFromTheEdgeOfItsTarget() {
        let (app, pin, sheet) = launchWithPinDeselected()
        print("MARKEREDGE frame=\(pin.frame)")

        for (name, dx, dy) in [("right", Self.inside, 0.0), ("left", -Self.inside, 0.0),
                               ("above", 0.0, -Self.inside), ("below", 0.0, Self.inside)] {
            tap(pin, dx: dx, dy: dy)
            XCTAssertTrue(sheet.waitForExistence(timeout: 10),
                          "A tap \(Self.inside)pt \(name) of the pin's centre, inside the 44pt target, did not select it. Pin frame: \(pin.frame)")
            // Deselect for the next edge.
            let map = app.maps.firstMatch
            map.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)).tap()
            XCTAssertTrue(sheet.waitForNonExistence(timeout: 10), "Could not deselect after the \(name) tap.")
        }
    }
}
