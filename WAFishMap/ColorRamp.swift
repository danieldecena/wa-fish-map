import SwiftUI

/// Density wash for the heat overlay, and the thermal ramp the ratings sit on.
enum ColorRamp {
    /// How many bands the density scale is quantised into. Four is enough to
    /// rank a cell without implying a precision the underlying data does not have.
    static let densityBandCount = 4

    /// Which band a rank-based intensity falls in, 0 (coldest) to 3.
    static func densityBand(_ intensity: Double) -> Int {
        let scaled = Int(intensity * Double(densityBandCount))
        return min(max(scaled, 0), densityBandCount - 1)
    }

    /// Fill for a density band. Cells tile without overlapping, so these alphas
    /// are what actually renders — nothing accumulates on top. That is why the
    /// range can be this wide and still leave the basemap readable.
    ///
    /// The coldest band draws nothing. Tinting every cell dimmed the whole map
    /// into a scrim, and a scrim says "something is on top of the map" rather
    /// than "this water is better than that water". Violet because the rating
    /// ramp gave it up when it moved to blue/amber/orange/red, so the overlay
    /// cannot be mistaken for a rating.
    static func densityFill(band: Int) -> Color {
        let alphas = [0.0, 0.15, 0.27, 0.40]
        let clamped = min(max(band, 0), alphas.count - 1)
        return Color(red: 0.42, green: 0.16, blue: 0.62).opacity(alphas[clamped])
    }

    /// Fill for a zone, straight from its intensity.
    static func densityFill(_ intensity: Double) -> Color {
        densityFill(band: densityBand(intensity))
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
