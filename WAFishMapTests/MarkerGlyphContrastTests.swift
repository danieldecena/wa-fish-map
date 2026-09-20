import MapKit
import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// The glyph and the cluster count must be legible on the balloon they sit on.
///
/// `SiteMarkerView.paint` is the only place either tint is set, for pins and
/// clusters alike, so measuring its output measures both. The values are read
/// back off a real `MKMarkerAnnotationView` rather than recomputed, so the test
/// cannot pass against a rule the view does not actually follow.
struct MarkerGlyphContrastTests {

    static func components(_ color: UIColor, _ style: UIUserInterfaceStyle) -> (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    static func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func lum(_ x: (Double, Double, Double)) -> Double {
            0.2126 * linear(x.0) + 0.7152 * linear(x.1) + 0.0722 * linear(x.2)
        }
        let (l1, l2) = (lum(a), lum(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    static let stops: [(name: String, color: Color)] = [
        ("slow", DS.Rating.slow), ("fair", DS.Rating.fair), ("good", DS.Rating.good),
        ("prime", DS.Rating.prime), ("unrated", DS.Rating.unrated),
    ]

    /// Graphical-object threshold. The plan sets 3:1 for the glyph.
    static let minimumContrast = 3.0

    /// Measures what `paint` actually leaves on the view.
    static func measured(stop: Color, style: UIUserInterfaceStyle) -> Double {
        let view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: nil)
        SiteMarkerView.paint(view, tint: UIColor(stop))
        let balloon = view.markerTintColor ?? .clear
        let glyph = view.glyphTintColor ?? .clear
        return ratio(components(glyph, style), components(balloon, style))
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theGlyphIsLegibleOnEveryStop(style: UIUserInterfaceStyle) {
        for stop in Self.stops {
            let c = Self.measured(stop: stop.color, style: style)
            #expect(c >= Self.minimumContrast,
                    "\(stop.name) glyph is \(String(format: "%.2f", c)):1 in \(style == .light ? "light" : "dark"); needs 3:1.")
        }
    }

    /// There is only one balloon state now, so this is the whole surface.
    /// The pale "season may be closed" balloon is gone: it could not carry a
    /// legible glyph and a readable rating at once, so closure became a badge.
    @Test func closureIsCarriedByAShapeAndNotByTheBalloon() {
        let view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: nil)

        SiteMarkerView.paint(view, tint: UIColor(DS.Rating.prime))
        SiteMarkerView.applyClosureBadge(view, closurePlausible: true)
        #expect(view.viewWithTag(SiteMarkerView.closureBadgeTag) != nil)
        #expect(view.markerTintColor == UIColor(DS.Rating.prime),
                "The balloon must keep the rating at full strength in the closure state.")

        // Views are reused across annotations, so the badge has to come off.
        SiteMarkerView.applyClosureBadge(view, closurePlausible: false)
        #expect(view.viewWithTag(SiteMarkerView.closureBadgeTag) == nil)
    }
}
