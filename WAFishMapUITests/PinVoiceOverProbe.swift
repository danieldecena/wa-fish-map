import XCTest

/// Throwaway probe: read the pins' VoiceOver text off a real screen.
///
/// `SiteMarkerView.apply` sets `accessibilityLabel`/`accessibilityValue` and the
/// strings are unit-tested, but they had never been observed on screen — a pinch
/// through XCUITest rotates an `MKMapView` instead of zooming it, so the camera
/// never left the statewide framing, where `MapDetailLevel` draws no pins at all.
/// Double-tap is the zoom gesture MapKit does honour from a synthesised event.
///
/// Runs against live WDFW data on purpose. The `-uiTesting` fixture holds three
/// sites, all in Thurston County, so zooming anywhere else finds nothing — which
/// is exactly how the first run of this probe failed.
///
/// The negative input is already banked: the same query run over a screen holding
/// 42 basemap POIs (`VKPointFeature`, type `Other`) returned zero, so a non-zero
/// count here is our annotations and not Apple's labels. The `summaryShape` check
/// below holds that line.
@MainActor
final class PinVoiceOverProbe: XCTestCase {
    /// Every `SiteAnnotation.spokenSummary` opens with one of these.
    private static let summaryShape = ["Boat launch", "Shore access", "Fishing pier"]

    private func describe(_ pins: [XCUIElement]) -> [String] {
        pins.map { "\($0.label) :: \(($0.value as? String) ?? "<no value>")" }
    }

    func testPinsCarryVoiceOverTextOnScreen() {
        let app = XCUIApplication()
        app.launch()

        // A fresh install re-prompts for location; unanswered, it sits over the map
        // and every tap below lands on the alert instead.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) { button.tap(); break }
        }

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 60),
                      "no map element in the tree:\n\(app.debugDescription)")

        // Pins are descendants of the map; the chrome is a sibling of it, so this
        // scope excludes Heat / Rivers / Now / recenter / the info button.
        func pins() -> [XCUIElement] { map.buttons.allElementsBoundByIndex }

        print("PINPROBE launch count=\(pins().count) \(describe(pins()))")

        var found: [String] = []
        for step in 1...7 {
            map.doubleTap()
            for _ in 0..<12 where pins().isEmpty {
                usleep(300_000)
            }
            found = describe(pins())
            print("PINPROBE step=\(step) count=\(found.count) \(found.prefix(25))")
            if found.count >= 3 { break }
        }

        XCTAssertFalse(found.isEmpty,
                       "Zoomed in seven times and the map still reports no pins. Tree:\n\(map.debugDescription)")

        let spoken = pins().compactMap { pin -> (String, String)? in
            guard let value = pin.value as? String, !pin.label.isEmpty, !value.isEmpty else { return nil }
            return (pin.label, value)
        }
        XCTAssertFalse(spoken.isEmpty, "Pins exist but none carries both a label and a value: \(found)")

        let ours = spoken.filter { _, value in
            Self.summaryShape.contains { value.hasPrefix($0) } || value.hasSuffix("fishing spots")
                || value.hasPrefix("best rated") || value == "no seasonal guidance"
        }
        XCTAssertFalse(ours.isEmpty,
                       "Found labelled elements but none reads like a SiteAnnotation summary, so these are not our pins: \(spoken)")

        print("PINPROBE ours=\(ours.count) of \(spoken.count) labelled, of \(found.count) total")
        for (label, value) in ours.prefix(25) {
            print("PINPROBE voiceover: \"\(label), \(value)\"")
        }
    }
}
