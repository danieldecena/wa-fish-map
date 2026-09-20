import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// The ramp's stops must differ in lightness, not only in hue.
///
/// The four stops sit on a basemap that is already green and orange, and the
/// dark regional frame read as one orange field. Hue alone does not separate
/// them there, and it does nothing at all for a colour-blind reader. L* is the
/// channel that survives both, so it is the one asserted.
///
/// Measured from the resolved colours rather than from Apple's published
/// values, because what matters is what the device draws in each appearance.
struct RampLightnessTests {

    /// Perceptual lightness of a token as it resolves in one appearance.
    static func lStar(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let y = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        return y > 0.008856 ? 116 * pow(y, 1.0 / 3.0) - 16 : 903.3 * y
    }

    /// Cold to hot, which is the order a reader scans them in.
    static let ramp: [(name: String, color: Color)] = [
        ("slow", DS.Rating.slow),
        ("fair", DS.Rating.fair),
        ("good", DS.Rating.good),
        ("prime", DS.Rating.prime),
    ]

    /// Slice 2's gate. Measured 2026-09-20 on iPhone 18 Pro: slow→fair 27.29
    /// light / 27.27 dark, fair→good 14.40 / 15.79, good→prime 13.30 / 13.25.
    /// The gate was watched failing at 14.0, which reds good→prime in both
    /// appearances, before it was trusted at 12.
    static let minimumDeltaLStar = 12.0

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func adjacentStopsSeparateByLightness(style: UIUserInterfaceStyle) {
        let ls = Self.ramp.map { Self.lStar($0.color, style) }
        for i in 0..<(Self.ramp.count - 1) {
            let delta = abs(ls[i + 1] - ls[i])
            #expect(delta >= Self.minimumDeltaLStar,
                    "\(Self.ramp[i].name)→\(Self.ramp[i + 1].name) is ΔL* \(String(format: "%.2f", delta)) in \(style == .light ? "light" : "dark"); stops this close read as one band on the basemap.")
        }
    }
}
