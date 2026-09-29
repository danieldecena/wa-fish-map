import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// The badge's label must be readable, which the ramp colour alone cannot
/// guarantee.
///
/// `RatingBadge` drew its label *in* the rating colour on a 20% wash of that
/// same colour. Both sides of the contrast ratio therefore moved together, so
/// a light stop like Fair produced light-on-lighter and landed near 1.7:1.
/// Colour that encodes a value cannot also be the colour that carries the text.
///
/// Measured against the background the label is actually drawn on: the wash
/// composited over the sheet's surface, not the wash in isolation.
struct RatingBadgeContrastTests {

    static func components(_ color: Color, _ style: UIUserInterfaceStyle) -> (Double, Double, Double) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func luminance(_ rgb: (Double, Double, Double)) -> Double {
        0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    }

    /// Source-over compositing of `top` at `alpha` onto `bottom`.
    static func composite(_ top: (Double, Double, Double), alpha: Double,
                          over bottom: (Double, Double, Double)) -> (Double, Double, Double) {
        (top.0 * alpha + bottom.0 * (1 - alpha),
         top.1 * alpha + bottom.1 * (1 - alpha),
         top.2 * alpha + bottom.2 * (1 - alpha))
    }

    static func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// All five states the badge can render, including the nil "No data" case.
    static let states: [(name: String, rating: FishingRating?)] = [
        ("Slow", .poor), ("Fair", .fair), ("Good", .good), ("Prime", .excellent), ("No data", nil),
    ]

    /// The wash `RatingBadge` puts behind its label.
    static let washOpacity = 0.2

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func everyBadgeLabelIsReadableOnItsOwnBackground(style: UIUserInterfaceStyle) {
        let surface = Self.components(Color(uiColor: .systemBackground), style)
        for state in Self.states {
            let ramp = Self.components(state.rating?.color ?? DS.Rating.unrated, style)
            let label = Self.components(RatingBadge.labelColor(for: state.rating), style)
            let drawn = Self.composite(ramp, alpha: Self.washOpacity, over: surface)
            let contrast = Self.ratio(label, drawn)
            #expect(contrast >= 4.5,
                    "\(state.name) label is \(String(format: "%.2f", contrast)):1 in \(style == .light ? "light" : "dark"); needs 4.5:1.")
        }
    }
}
