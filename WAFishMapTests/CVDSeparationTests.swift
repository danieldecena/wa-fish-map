import MapKit
import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// Adjacent rating stops must stay apart for a reader with deuteranopia or
/// protanopia.
///
/// `RampLightnessTests` asserts lightness on the colours as drawn. This applies
/// the Machado et al. 2009 severity-1.0 simulation (in linear RGB) to the
/// resolved tokens first, so it asks what a dichromat sees. The numbers are
/// exact; `scripts/cvd_check.py` does the same transform over screenshots and
/// is the thing to look at.
///
/// A pair fails when it is close in lightness AND close in CIELAB distance.
/// Either alone is enough to tell two stops apart.
struct CVDSeparationTests {

    typealias RGB = (r: Double, g: Double, b: Double)

    static let deuteranopia: [[Double]] = [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ]
    static let protanopia: [[Double]] = [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ]
    static let deficiencies: [(name: String, matrix: [[Double]])] = [
        ("deuteranopia", deuteranopia), ("protanopia", protanopia),
    ]

    /// RampLightnessTests' floor, and the ΔE76 below which two colours still
    /// read as one for this purpose. Calibrated by the controls below: the
    /// equiluminant red/green pair must fail it, blue/yellow must pass.
    static let minimumDeltaLStar = 12.0
    static let minimumDeltaE = 30.0

    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func delinear(_ c: Double) -> Double {
        let v = min(1, max(0, c))
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }

    static func simulate(_ c: RGB, _ m: [[Double]]) -> RGB {
        let lin = [linear(c.r), linear(c.g), linear(c.b)]
        let out = m.map { row in zip(row, lin).reduce(0) { $0 + $1.0 * $1.1 } }
        return (delinear(out[0]), delinear(out[1]), delinear(out[2]))
    }

    static func lab(_ c: RGB) -> (l: Double, a: Double, b: Double) {
        let r = linear(c.r), g = linear(c.g), b = linear(c.b)
        let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
        return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
    }

    static func deltaE(_ a: RGB, _ b: RGB) -> Double {
        let (p, q) = (lab(a), lab(b))
        return sqrt(pow(p.l - q.l, 2) + pow(p.a - q.a, 2) + pow(p.b - q.b, 2))
    }

    static func hueGap(_ a: RGB, _ b: RGB) -> Double {
        let (p, q) = (lab(a), lab(b))
        let d = abs(atan2(p.b, p.a) - atan2(q.b, q.a)) * 180 / .pi
        return min(d, 360 - d)
    }

    static func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    static let red: RGB = (1, 0, 0), green: RGB = (0, 1, 0)
    static let blue: RGB = (0, 0, 1), yellow: RGB = (1, 1, 0)

    // MARK: Controls — the detector has to fire on bad input and pass good.

    @Test(arguments: deficiencies.map(\.name))
    func controlRedGreenCollapses(name: String) {
        let m = Self.deficiencies.first { $0.name == name }!.matrix
        let (r, g) = (Self.simulate(Self.red, m), Self.simulate(Self.green, m))
        #expect(Self.hueGap(Self.red, Self.green) > 90, "unsimulated red/green must differ in hue")
        #expect(Self.hueGap(r, g) < 15,
                "\(name): red/green hue gap \(Self.hueGap(r, g)) after simulation; the simulator is not simulating")
    }

    @Test(arguments: deficiencies.map(\.name))
    func controlBlueYellowSurvives(name: String) {
        let m = Self.deficiencies.first { $0.name == name }!.matrix
        let (b, y) = (Self.simulate(Self.blue, m), Self.simulate(Self.yellow, m))
        #expect(Self.deltaE(b, y) > 40, "\(name): blue/yellow dE \(Self.deltaE(b, y))")
        #expect(Self.hueGap(b, y) > 90, "\(name): blue/yellow hue gap \(Self.hueGap(b, y))")
    }

    /// Pure red/green keeps a real lightness gap under a correct simulation, so
    /// it is the wrong known-bad input for the criterion. A green chosen to
    /// match red's simulated green channel exactly is the one that collapses.
    @Test(arguments: deficiencies.map(\.name))
    func controlCriterionClassifiesTheControls(name: String) {
        let m = Self.deficiencies.first { $0.name == name }!.matrix
        let equiluminantGreen: RGB = (0, Self.delinear(m[1][0] / m[1][1]), 0)
        let (r, g) = (Self.simulate(Self.red, m), Self.simulate(equiluminantGreen, m))
        #expect(Self.hueGap(Self.red, equiluminantGreen) > 90, "unsimulated they must differ in hue")
        #expect(Self.pairFails(r, g), "\(name): equiluminant red/green must fail the criterion")
        let (b, y) = (Self.simulate(Self.blue, m), Self.simulate(Self.yellow, m))
        #expect(!Self.pairFails(b, y), "\(name): blue/yellow must pass the criterion")
    }

    static func pairFails(_ a: RGB, _ b: RGB) -> Bool {
        abs(lab(a).l - lab(b).l) < minimumDeltaLStar && deltaE(a, b) < minimumDeltaE
    }

    // MARK: The ramp

    static let ramp: [(name: String, color: Color)] = [
        ("slow", DS.Rating.slow), ("fair", DS.Rating.fair),
        ("good", DS.Rating.good), ("prime", DS.Rating.prime),
    ]

    /// The glyph ink `SiteMarkerView.paint` leaves on a real balloon, resolved
    /// per appearance. Read off the view so this cannot pass against a rule the
    /// marker does not follow.
    static func ink(_ stop: Color, _ style: UIUserInterfaceStyle) -> RGB {
        let view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: nil)
        SiteMarkerView.paint(view, tint: UIColor(stop))
        return MarkerGlyphContrastTests.components(view.glyphTintColor ?? .clear, style)
    }

    /// A non-colour channel: one marker carries white ink, the other black.
    static func inkSeparates(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Bool {
        abs(lab(ink(a, style)).l - lab(ink(b, style)).l) > 50
    }

    /// Two real markers with the same ink have no channel but colour; two with
    /// opposite ink do. Observed on the views, they pin the channel check.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func controlInkChannelIsReadFromTheRealViews(style: UIUserInterfaceStyle) {
        #expect(Self.inkSeparates(DS.Rating.good, DS.Rating.prime, style), "good/prime must differ in ink")
        #expect(!Self.inkSeparates(DS.Rating.fair, DS.Rating.good, style), "fair/good share ink")
    }

    /// Every adjacent pair is separated by colour as simulated, or by a
    /// non-colour channel on the real views. Prints every measured pair so the
    /// numbers land in the log pass or fail.
    ///
    /// Measured 2026-10-06, iPhone 18 Pro: good->prime fails the colour test
    /// under deuteranopia (dL* 11.1, dE76 19.5 light; 11.1, 21.1 dark) and is
    /// carried by ink. fair->good is the thin one and has no second channel:
    /// dL* 12.71 light / 14.01 dark under deuteranopia, dE76 18.8 / 21.9.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func adjacentStopsSeparateUnderColourBlindness(style: UIUserInterfaceStyle) {
        let look = style == .light ? "light" : "dark"
        for (defName, matrix) in Self.deficiencies {
            let sims = Self.ramp.map { Self.simulate(Self.resolved($0.color, style), matrix) }
            for i in 0..<(Self.ramp.count - 1) {
                let dL = abs(Self.lab(sims[i + 1]).l - Self.lab(sims[i]).l)
                let dE = Self.deltaE(sims[i], sims[i + 1])
                let pair = "\(Self.ramp[i].name)->\(Self.ramp[i + 1].name)"
                let byInk = Self.inkSeparates(Self.ramp[i].color, Self.ramp[i + 1].color, style)
                print("CVD|\(look)|\(defName)|\(pair)|dL=\(String(format: "%.2f", dL))|dE=\(String(format: "%.2f", dE))|ink=\(byInk)")
                #expect(!Self.pairFails(sims[i], sims[i + 1]) || byInk,
                        "\(pair) in \(look) under \(defName): dL* \(String(format: "%.2f", dL)), dE76 \(String(format: "%.2f", dE)), same ink; nothing but colour separates them.")
            }
        }
    }
}
