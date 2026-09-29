import MapKit
import Testing
import UIKit
@testable import WAFishMap

/// A pin drawn small must still be tappable at full size.
///
/// `MarkerMetrics.transform` scales the whole annotation view, and a view's
/// touch area scales with it: at 0.8 a ~40pt balloon hits at ~32pt, under
/// Apple's 44pt minimum. The runbook has a matching case from a real session --
/// a tap that "passed" while the popover never opened, because the target was
/// 14pt. Shrinking the drawing is a legibility decision; shrinking the target
/// is a defect that rides along with it.
struct MarkerTapTargetTests {

    /// A representative balloon. MapKit does not publish the size, and an
    /// annotation view outside a map has empty bounds, so it is stated here.
    static let balloon = CGRect(x: 0, y: 0, width: 40, height: 40)

    @Test(arguments: [MarkerMetrics.pin, MarkerMetrics.cluster])
    func theTouchAreaLandsAtLeastFortyFourPointsOnScreen(scale: CGFloat) {
        let rect = MarkerMetrics.hitRect(bounds: Self.balloon, scale: scale)

        // The view is scaled on its way to the screen, so the rect has to be
        // measured after that scaling, not in the view's own coordinates.
        #expect(rect.width * scale >= 44,
                "at scale \(scale) the target is \(rect.width * scale)pt wide on screen")
        #expect(rect.height * scale >= 44,
                "at scale \(scale) the target is \(rect.height * scale)pt tall on screen")
    }

    @Test func theTargetStaysCentredOnTheBalloon() {
        let rect = MarkerMetrics.hitRect(bounds: Self.balloon, scale: MarkerMetrics.pin)
        #expect(abs(rect.midX - Self.balloon.midX) < 0.01)
        #expect(abs(rect.midY - Self.balloon.midY) < 0.01)
    }

    /// The control: growing the target must not swallow the whole map. A touch
    /// well clear of the balloon still has to miss, or pins would steal taps
    /// from each other and from the map itself.
    @Test func aTouchWellClearOfTheBalloonStillMisses() {
        let rect = MarkerMetrics.hitRect(bounds: Self.balloon, scale: MarkerMetrics.pin)
        #expect(!rect.contains(CGPoint(x: Self.balloon.midX + 60, y: Self.balloon.midY)))
        #expect(!rect.contains(CGPoint(x: Self.balloon.midX, y: Self.balloon.midY - 60)))
    }

    /// And the view actually uses it. A correct rect that `point(inside:)`
    /// ignores would pass every assertion above and change nothing on screen.
    ///
    /// Just inside 22pt rather than at it: a 44pt target reaches ±22pt from
    /// centre, and `CGRect.contains` excludes the max edge, so exactly 22pt is
    /// the one point that legitimately misses. Asserting the boundary itself
    /// would be testing CGRect's edge convention, not the tap target.
    @Test func theViewAcceptsATouchAlmostTwentyTwoPointsFromItsCentre() {
        let view = SiteMarkerView(annotation: nil, reuseIdentifier: nil)
        view.bounds = Self.balloon

        // A screen offset is `offset / scale` in the view's own coordinates.
        func screenOffset(_ points: CGFloat) -> CGPoint {
            CGPoint(x: Self.balloon.midX + points / MarkerMetrics.pin, y: Self.balloon.midY)
        }
        #expect(view.point(inside: screenOffset(21.9), with: nil))
        #expect(!view.point(inside: screenOffset(30), with: nil),
                "30pt from centre is outside a 44pt target and must still miss.")
    }
}
