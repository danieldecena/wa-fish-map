import SwiftUI

/// High/low tide table for the nearest NOAA station. Marine sites only; inland is empty.
struct TidePredictionsView: View {
    let coordinate: LonLat
    let planDate: Date
    let isMarine: Bool
    var client: HTTPGet = URLSessionHTTPGet()
    var bundle: Bundle = .main
    var calendar: Calendar = {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return c
    }()

    @State private var table: TideTable?
    @State private var failed = false

    var body: some View {
        if isMarine {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tides").font(.headline)
                content
            }
            .task(id: dayKey) { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let table {
            Link(destination: table.noaaURL) {
                Label(table.station.name, systemImage: "water.waves")
                    .font(.caption)
            }
            ForEach(Array(table.extremes.enumerated()), id: \.offset) { index, extreme in
                let isNext = index == table.indexOfNext(after: planDate)
                HStack {
                    Text(extreme.kind.label)
                        .font(.subheadline.weight(isNext ? .semibold : .regular))
                    Spacer()
                    Text(Self.time.string(from: extreme.time))
                        .font(.subheadline.monospacedDigit())
                    Text(String(format: "%.1f ft", extreme.heightFeet))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 56, alignment: .trailing)
                }
                .foregroundStyle(isNext ? .primary : .secondary)
            }
            Text("NOAA predictions at the nearest station. Not a tide book.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else if failed {
            Text("Tides unavailable right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Link("Check NOAA tide predictions",
                 destination: URL(string: "https://tidesandcurrents.noaa.gov")!)
                .font(.caption)
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }

    private var dayKey: String {
        let p = calendar.dateComponents([.year, .month, .day], from: planDate)
        return "\(p.year ?? 0)-\(p.month ?? 0)-\(p.day ?? 0)"
    }

    private func load() async {
        failed = false
        table = nil
        do {
            let stations = try NOAATideLoader.loadStations(from: bundle)
            guard let station = TideStation.nearest(to: coordinate, in: stations) else {
                failed = true
                return
            }
            table = try await NOAATideLoader.fetch(
                station: station, day: planDate, client: client, calendar: calendar
            )
        } catch {
            failed = true
        }
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        f.dateFormat = "h:mm a"
        return f
    }()
}
