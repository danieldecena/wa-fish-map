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

    /// Fill for a density band. Cells tile without overlapping, so these are
    /// exactly what renders — nothing accumulates on top.
    ///
    /// One hue at four opacities, which only works because the map is muted
    /// while the overlay is on. Over the normal basemap a translucent fill takes
    /// its apparent colour from whatever sits beneath it, so one band read pink
    /// over city, brown over forest and violet over water — the same band
    /// looking like three, and different bands looking alike. Shifting hue per
    /// band papered over that and made it garish; draining the ground fixes it.
    ///
    /// The coldest band draws nothing, so the basemap stays clean where there is
    /// nothing to say. The hue itself is `DS.Overlay.density`.
    static func densityFill(band: Int) -> Color {
        let alphas = [0.0, 0.14, 0.26, 0.40]
        let clamped = min(max(band, 0), alphas.count - 1)
        return DS.Overlay.density.opacity(alphas[clamped])
    }

    /// Fill for a zone, straight from its intensity.
    static func densityFill(_ intensity: Double) -> Color {
        densityFill(band: densityBand(intensity))
    }
}

extension FishingRating {
    /// A thermal ramp, cold to hot: blue → yellow → orange → red. Stated as four
    /// explicit stops rather than sampled off a continuous function — sampling a
    /// blue-to-red line runs through magenta, which reads as a different scale
    /// rather than as heat.
    ///
    /// The stops live in `DS.Rating`, anchored on the system colours so they
    /// carry a dark appearance. See that type for why the old literals moved.
    var color: Color {
        switch self {
        case .poor: DS.Rating.slow
        case .fair: DS.Rating.fair
        case .good: DS.Rating.good
        case .excellent: DS.Rating.prime
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

/// Numbered stand-in for several pins in one grid cell. Tap is handled by the map.
struct ClusterMark: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(DS.TypeScale.clusterCount)
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
}
