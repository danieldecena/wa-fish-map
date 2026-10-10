import XCTest

/// What assistive tech is actually handed for a pin.
///
/// `SiteMarkerView` set `accessibilityLabel` to the site's name and
/// `accessibilityValue` to its spoken summary, and the strings were unit-tested.
/// Neither test nor reading showed what reaches the screen: MapKit exposes a
/// marker as a single element (`VKPointFeature`) whose label is
/// "<annotation title>, <the view's accessibilityLabel>", and the value is
/// dropped. So every pin read as its name twice and its rating never.
/// Observed on iOS 26.5 and 27.0 simulators, 2026-10-07; swapping the label for
/// a marker string moved only the second half, which is how the composition is
/// known rather than guessed.
///
/// The fixture opens with Boston Harbor selected and its sheet up, and a
/// selected pin was not in the tree at all, so the test taps bare map first.
///
/// Asserts the kind and that a rating phrase is present, not the full sentence:
/// restating `spokenSummary` here would only test that two copies agree.
@MainActor
final class PinSpokenTextUITests: XCTestCase {
    /// Boston Harbor is at 47.1397, -122.9055. Centred a quarter-span south,
    /// which keeps the pin clear of the sheet's medium detent.
    private static let region = "47.1347,-122.9055,0.02"

    func testAPinExposesItsKindAndRatingNotItsNameTwice() {
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
                      "Nothing on the map is labelled Boston Harbor. Map tree:\n\(map.debugDescription)")

        let spoken = pin.label
        print("PINSPOKEN \(spoken)")
        XCTAssertTrue(spoken.contains("Boat launch"),
                      "The pin does not say what kind of site it is: \"\(spoken)\"")
        XCTAssertTrue(spoken.contains("rated ") || spoken.contains("no seasonal guidance")
                        || spoken.contains("closed per WDFW"),
                      "The pin says nothing about its rating: \"\(spoken)\"")
        XCTAssertNotEqual(spoken, "Boston Harbor, Boston Harbor",
                          "The pin reads its name twice.")
    }
}
