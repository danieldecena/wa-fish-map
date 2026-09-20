import MapKit
import SwiftUI

/// A species' whole year as twelve cells, tinted by that month's rating.
///
/// Replaces "Best months: Jun, Jul, Aug". That sentence loses the shape of a
/// season: "Jun, Jul, Aug" and "Mar, Jul, Nov" read identically as text and are
/// completely different fisheries, one a single run and one three scattered
/// windows. The shape is the information.
///
/// The strip starts at the current month rather than at January. A season
/// spanning November to February splits into two disconnected blobs at
/// opposite ends of a fixed Jan-Dec strip, which is the most misleading case
/// it could have. Every card rotates by the same amount, so species stay
/// comparable to each other on one sheet.
struct SeasonRibbon: View {
    let season: SpeciesSeason
    let month: Int

    var body: some View {
        let cells = Self.cells(for: season, current: month)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 2) {
                ForEach(cells, id: \.month) { cell in
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cell.rating.color.opacity(cell.isCurrent ? 1 : 0.75))
                        // Risk is a shape, not a shade. Colour is already
                        // spent on the rating, and a second colour meaning
                        // would collide with it.
                        if cell.isRisk {
                            Image(systemName: "questionmark")
                                .font(.system(size: 7, weight: .bold))
                                // Same ink rule as the map glyph, for the same
                                // reason: this was white, and white on the
                                // Fair stop measures 1.51:1.
                                .foregroundStyle(Color(uiColor: SiteMarkerView.glyphTint(
                                    on: UIColor(cell.rating.color))))
                        }
                    }
                    .frame(height: cell.isCurrent ? 16 : 11)
                    .overlay {
                        if cell.isCurrent {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(.primary, lineWidth: 1.5)
                        }
                    }
                }
            }
            Text(Self.caption(cells))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Season for \(season.species)")
        .accessibilityValue(Self.spoken(cells))
    }

    struct Cell: Equatable {
        let month: Int
        let rating: FishingRating
        let isCurrent: Bool
        let isRisk: Bool
    }

    /// Twelve cells starting at `current` and wrapping through the year.
    static func cells(for season: SpeciesSeason, current: Int) -> [Cell] {
        (0..<12).map { offset in
            let m = (current - 1 + offset) % 12 + 1
            return Cell(month: m,
                        rating: season.rating(inMonth: m),
                        isCurrent: offset == 0,
                        isRisk: season.riskMonths.contains(m))
        }
    }

    static let initials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    /// Names the ends so the strip is not an unlabelled row of blocks. The
    /// rotation means the first cell is always now, which is the one a reader
    /// needs anchored.
    static func caption(_ cells: [Cell]) -> String {
        guard let first = cells.first, let last = cells.last else { return "" }
        return "Now (\(initials[first.month - 1])) through \(initials[last.month - 1]) next year"
    }

    /// VoiceOver gets the runs in words. Twelve tinted rectangles convey
    /// nothing otherwise, and the peak months are the whole point.
    static func spoken(_ cells: [Cell]) -> String {
        let peak = cells.filter { $0.rating == .excellent }.map { initials[$0.month - 1] }
        let now = cells.first.map { "now rated \($0.rating.label)" } ?? ""
        guard !peak.isEmpty else { return "\(now); no peak months" }
        return "\(now); peaks in \(peak.joined(separator: ", "))"
    }
}
