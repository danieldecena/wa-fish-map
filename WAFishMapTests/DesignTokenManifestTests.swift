import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// Prints every design token as this device resolves it, for the Figma
/// library diff (scripts/figma_ds_diff.py). The assertions keep the manifest
/// honest: a token that failed to resolve must fail the run, not print a zero.
///
/// SwiftUI `Font` cannot be read back, so the type roles are restated here as
/// UIKit text styles. Keep this table in step with `DS.TypeScale`.
struct DesignTokenManifestTests {

    static func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
        // An extended-sRGB component outside 0...1 cannot be written as sRGB hex; fail rather than clamp.
        #expect([r, g, b].allSatisfy { (0...1).contains($0) }, "out of sRGB gamut: \(r), \(g), \(b)")
        let c = { (v: CGFloat) in String(format: "%02x", Int((v * 255).rounded())) }
        return "#" + c(r) + c(g) + c(b)
    }

    static func alpha(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
        return (Double(a) * 1000).rounded() / 1000
    }

    static let colors: [(String, Color)] = [
        ("rating.slow", DS.Rating.slow), ("rating.fair", DS.Rating.fair),
        ("rating.good", DS.Rating.good), ("rating.prime", DS.Rating.prime),
        ("rating.unrated", DS.Rating.unrated), ("overlay.density", DS.Overlay.density),
        ("chrome.riversOn", DS.Chrome.riversOn), ("chrome.heatOn", DS.Chrome.heatOn),
        ("surface.advisory", DS.Surface.advisory), ("surface.speciesRow", DS.Surface.speciesRow),
        ("ink.fineprint", DS.Ink.fineprint),
    ]

    static let radii: [(String, CGFloat)] = [
        ("surface.chromeRadius", DS.Surface.chromeRadius),
        ("surface.advisoryRadius", DS.Surface.advisoryRadius),
        ("surface.speciesRowRadius", DS.Surface.speciesRowRadius),
    ]

    static let type: [(String, UIFont.TextStyle, String)] = [
        ("sectionTitle", .headline, "semibold"), ("itemTitle", .subheadline, "semibold"),
        ("supporting", .subheadline, "regular"), ("control", .caption2, "semibold"),
        ("legend", .caption2, "regular"), ("mapLabel", .caption2, "semibold"),
        ("meta", .caption1, "regular"), ("fineprint", .caption2, "regular"),
        ("clusterCount", .caption2, "bold"), ("badge", .caption1, "bold"),
        ("tideValue", .subheadline, "regular"),
    ]

    @Test func printsManifest() throws {
        let large = UITraitCollection(preferredContentSizeCategory: .large)
        var colorOut: [String: [String: Any]] = [:]
        for (name, color) in Self.colors {
            colorOut[name] = [
                "light": Self.hex(color, .light), "dark": Self.hex(color, .dark),
                "lightAlpha": Self.alpha(color, .light), "darkAlpha": Self.alpha(color, .dark),
            ]
        }
        var typeOut: [String: [String: Any]] = [:]
        for (role, style, weight) in Self.type {
            let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: large).pointSize
            #expect(size > 0, "\(role) resolved to no size")
            typeOut[role] = ["size": Double(size), "weight": weight]
        }
        let manifest: [String: Any] = [
            "colors": colorOut,
            "radii": Dictionary(uniqueKeysWithValues: Self.radii.map { ($0.0, Double($0.1)) }),
            "type": typeOut,
        ]
        #expect(colorOut.count == Self.colors.count)
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        print("DSMANIFEST " + String(decoding: data, as: UTF8.self))
    }
}
