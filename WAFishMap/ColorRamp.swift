import SwiftUI

/// Cold (blue) → hot (red) through purple midtones.
///
/// Drives the marker rating and its legend from one function, so the two cannot
/// drift apart, and avoids the red/green pairing the rating palette used to rely
/// on. The heat overlay deliberately does NOT use this ramp — see `density`.
enum ColorRamp {
    /// `intensity` runs 0 (cold) → 1 (hot).
    static func color(_ intensity: Double) -> Color {
        Color(red: intensity, green: 0.1, blue: 1 - intensity)
    }

    /// Density wash for the heat overlay, varying in weight rather than hue.
    /// The markers own the cold→hot hues; giving the overlay the same ones made
    /// red pins disappear into red zones.
    static func density(_ intensity: Double) -> Color {
        Color(red: 0.16, green: 0.13, blue: 0.22).opacity(0.05 + 0.10 * intensity)
    }

    /// Metres of radius for a heat zone. A fixed radius made every zone the same
    /// disc, so intensity was invisible and the overlapping edges read as rings.
    static func densityRadius(_ intensity: Double) -> Double {
        5000 + 9000 * intensity
    }
}

extension FishingRating {
    /// Slow → blue, Prime → red. Sampled unevenly on purpose: even quarters put
    /// Good and Prime adjacent in the reddest stretch, where a dense cluster of
    /// pins reads as one colour. Pulling Good back toward magenta leaves Prime
    /// alone at pure red.
    var color: Color {
        switch self {
        case .poor: ColorRamp.color(0)
        case .fair: ColorRamp.color(0.28)
        case .good: ColorRamp.color(0.58)
        case .excellent: ColorRamp.color(1)
        }
    }
}
