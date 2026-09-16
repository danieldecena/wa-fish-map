import SwiftUI

/// Sunrise and sunset for the site's own coordinate on the plan date.
///
/// The species cards say things like "Best time: Morning & evening"; without
/// these two times that advice cannot be acted on. `SolarTimes` was already
/// computed for the Dawn/Midday/Dusk label and then discarded, so this shows
/// data the app was throwing away rather than fetching anything new.
struct DaylightView: View {
    let coordinate: LonLat
    let planDate: Date

    /// Pacific, matching `TidePredictionsView` — the day-of-year the solar
    /// equations key off must be the local day, not the machine's.
    private static let calendar: Calendar = .pacific

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return f
    }()

    var body: some View {
        if let solar = SolarTimes.compute(on: planDate, at: coordinate, calendar: Self.calendar) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daylight").font(DS.TypeScale.sectionTitle)
                row("Sunrise", "sunrise", solar.sunrise)
                row("Sunset", "sunset", solar.sunset)
            }
        }
    }

    private func row(_ label: String, _ symbol: String, _ time: Date) -> some View {
        HStack {
            Label(label, systemImage: symbol)
                .font(DS.TypeScale.supporting)
            Spacer()
            Text(Self.time.string(from: time))
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }
}
