import SwiftUI

/// Density wash for the heat overlay, and the thermal ramp the ratings sit on.
enum ColorRamp {
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
    /// A thermal ramp, cold to hot: blue → amber → orange → red. Stated as four
    /// explicit stops rather than sampled off a continuous function — sampling a
    /// blue-to-red line runs through magenta, which reads as a different scale
    /// rather than as heat.
    var color: Color {
        switch self {
        case .poor: Color(red: 0.00, green: 0.45, blue: 1.00)
        case .fair: Color(red: 1.00, green: 0.78, blue: 0.00)
        case .good: Color(red: 1.00, green: 0.45, blue: 0.00)
        case .excellent: Color(red: 0.94, green: 0.11, blue: 0.05)
        }
    }
}

/// A site rendered at range: colour and position only, no glyph or balloon.
struct RatingDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .stroke(.white, lineWidth: 1.5)
            .frame(width: 11, height: 11)
    }
}
