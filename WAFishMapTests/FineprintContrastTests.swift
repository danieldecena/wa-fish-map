import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// Fine print must be readable on the sheet's surfaces.
///
/// The label colours are translucent greys, so the alpha matters: reading only
/// RGB measures a colour that is never drawn. Each ink is composited over the
/// surface before the ratio is taken.
///
/// The floor is 3.0:1, not 4.5:1, on purpose. `secondaryLabel` itself sits
/// near 3.5:1 in light appearance, and fine print darker than the secondary
/// text above it would invert the hierarchy. Raising all secondary text is a
/// separate decision (design critique, 2026-10-14, Deferred).
struct FineprintContrastTests {
    typealias Contrast = RatingBadgeContrastTests

    static let floor = 3.0

    /// The sheet is a material over the map, which no test can resolve. Both
    /// system backgrounds bracket it.
    static let surfaces: [(name: String, color: UIColor)] = [
        ("systemBackground", .systemBackground),
        ("secondarySystemBackground", .secondarySystemBackground),
    ]

    static func ratio(_ ink: UIColor, on surface: UIColor, _ style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ink.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ground = Contrast.components(Color(uiColor: surface), style)
        let drawn = Contrast.composite((Double(r), Double(g), Double(b)), alpha: Double(a), over: ground)
        return Contrast.ratio(drawn, ground)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func fineprintClearsTheFloor(style: UIUserInterfaceStyle) {
        for surface in Self.surfaces {
            let measured = Self.ratio(UIColor(DS.Ink.fineprint), on: surface.color, style)
            #expect(measured >= Self.floor,
                    "Fine print is \(String(format: "%.2f", measured)):1 on \(surface.name) in \(style == .light ? "light" : "dark"); needs \(Self.floor):1.")
        }
    }

    /// The control. Tertiary is what the fine print used to be; if this
    /// passes the floor, the check above cannot tell old from new.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func tertiaryFallsBelowTheFloor(style: UIUserInterfaceStyle) {
        let measured = Self.ratio(.tertiaryLabel, on: .systemBackground, style)
        #expect(measured < Self.floor,
                "Tertiary measured \(String(format: "%.2f", measured)):1, so the floor no longer separates it.")
    }
}
