import XCTest

/// Throwaway probe: read the pins' VoiceOver text off a real screen.
///
/// `SiteMarkerView.apply` sets `accessibilityLabel` and the
/// strings are unit-tested, but they had never been observed on screen — a pinch
/// through XCUITest rotates an `MKMapView` instead of zooming it, so the camera
/// never left the statewide framing, where `MapDetailLevel` draws no pins at all.
/// Double-tap is the zoom gesture MapKit does honour from a synthesised event.
///
/// Runs against live WDFW data on purpose. The `-uiTesting` fixture holds three
/// sites, all in Thurston County, so zooming anywhere else finds nothing — which
/// is exactly how the first run of this probe failed.
///
/// Our pins and Apple's basemap labels are the same kind of element
/// (`VKPointFeature`, type `Other`): MapKit reads a marker as
/// "<title>, <the view's accessibilityLabel>" and exposes no value. This probe
/// first queried `map.buttons` and read `value`, which can match nothing, so it
/// could never have passed (`PinSpokenTextUITests`, 2026-10-07). The
/// `summaryShape` check below is what separates our pins from Apple's labels.
@MainActor
final class PinVoiceOverProbe: XCTestCase {
    /// Every `SiteAnnotation.spokenSummary` opens with one of these.
    private static let summaryShape = ["Boat launch", "Shore access", "Fishing pier"]

    /// Walks one snapshot instead of asking each element for its label. An element
    /// from `allElementsBoundByIndex` re-resolves by index when `.label` is read,
    /// and the live map has redrawn by then, so the index is gone (2026-10-09).
    private func pinLabels(in node: any XCUIElementSnapshot) -> [String] {
        (node.identifier == "VKPointFeature" ? [node.label] : []) + node.children.flatMap(pinLabels(in:))
    }

    func testPinsCarryVoiceOverTextOnScreen() throws {
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
        func pins() throws -> [String] {
            pinLabels(in: try map.snapshot())
        }

        let atLaunch = try pins()
        print("PINPROBE launch count=\(atLaunch.count) \(atLaunch)")

        func isOurs(_ label: String) -> Bool {
            Self.summaryShape.contains { label.contains(", \($0)") } || label.contains(" fishing spots, ")
        }

        // Stop on the first of ours, not on a count: the statewide frame already
        // holds plenty of Apple's labels before a single pin is drawn. Step 0 waits
        // without zooming: a frame that opens already drawing pins loses them to a
        // double-tap, which zooms on the centre and past them (2026-10-09).
        var found: [String] = []
        for step in 0...7 {
            if step > 0 { map.doubleTap() }
            for _ in 0..<12 {
                found = try pins()
                if found.contains(where: isOurs) { break }
                usleep(300_000)
            }
            print("PINPROBE step=\(step) count=\(found.count) \(found.prefix(25))")
            if found.contains(where: isOurs) { break }
        }

        XCTAssertFalse(found.isEmpty,
                       "Zoomed in seven times and the map still reports no pins. Tree:\n\(map.debugDescription)")

        let ours = found.filter(isOurs)
        XCTAssertFalse(ours.isEmpty,
                       "Found map labels but none reads like a SiteAnnotation summary, so these are not our pins: \(found)")

        print("PINPROBE ours=\(ours.count) of \(found.count) labelled")
        for label in ours.prefix(25) {
            print("PINPROBE voiceover: \"\(label)\"")
        }
    }
}
