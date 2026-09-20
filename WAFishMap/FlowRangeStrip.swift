import SwiftUI

/// Today's flow against this river's own range for the date.
///
/// Deliberately a range strip with a marker, not a bar. A filled bar reads as
/// more-is-better, and `RiverFlowStats.flowRating` is non-monotonic on purpose:
/// a river is unfishable bony and unfishable blowing out, so both tails mean
/// the same thing. What a person needs to see is *where in the distribution*
/// the reading sits and how far into which tail, which a bar cannot show and
/// the sentence beside it could only approximate.
///
/// The axis is this river's own percentiles for the day of year. Discharge is
/// meaningless across rivers -- the Columbia dwarfs everything -- so there is
/// no shared scale here and there must not be one.
struct FlowRangeStrip: View {
    let position: Double
    /// Drawn only as a label; the geometry comes from `position`.
    let discharge: Double

    private let height: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                        .frame(height: 8)

                    // p10-p90: the ordinary range for this date.
                    Capsule().fill(.tertiary)
                        .frame(width: w * 0.80, height: 8)
                        .offset(x: w * 0.10)

                    // p25-p75: the middle half.
                    Capsule().fill(.secondary)
                        .frame(width: w * 0.50, height: 8)
                        .offset(x: w * 0.25)

                    // Median.
                    Rectangle().fill(.background)
                        .frame(width: 2, height: 14)
                        .offset(x: w * 0.50 - 1)

                    Circle()
                        .fill(Color.accentColor)
                        .stroke(.background, lineWidth: 2)
                        .frame(width: 14, height: 14)
                        .offset(x: min(max(w * position - 7, 0), w - 14))
                }
                .frame(height: height, alignment: .center)
            }
            .frame(height: height)

            HStack {
                Text("Lower").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("Typical for the date").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("Higher").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flow against this river's normal range for the date")
        .accessibilityValue(Self.spoken(position: position, discharge: discharge))
    }

    /// VoiceOver gets the reading in words, because the strip's whole content
    /// is spatial and a blind reader gets nothing from "a dot at 0.83".
    static func spoken(position: Double, discharge: Double) -> String {
        let cfs = "\(Int(discharge.rounded())) cfs"
        switch position {
        case ..<0.10: return "\(cfs), well below the normal range for the date"
        case ..<0.25: return "\(cfs), below normal for the date"
        case ..<0.75: return "\(cfs), within the normal range for the date"
        case ..<0.90: return "\(cfs), above normal for the date"
        default: return "\(cfs), well above the normal range for the date"
        }
    }
}
