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
        Color(red: 0.16, green: 0.13, blue: 0.22).opacity(0.07 + 0.18 * intensity)
    }
}

extension FishingRating {
    /// Slow → blue, Prime → red, sampled off the shared ramp at even steps.
    var color: Color {
        ColorRamp.color(Double(rawValue) / Double(FishingRating.excellent.rawValue))
    }
}
