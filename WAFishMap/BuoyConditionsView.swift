import SwiftUI

/// Wave height and water temperature from the nearest NDBC buoy. Marine sites
/// only, like tides.
///
/// Reports observations, never a forecast: the numbers are what a buoy measured
/// at a stated minute, which is why each carries its own timestamp and the view
/// says how old it is. Depth is deliberately not shown — a buoy's depth says
/// nothing about where the angler is standing.
struct BuoyConditionsView: View {
    let coordinate: LonLat
    let isMarine: Bool
    var client: HTTPGet = URLSessionHTTPGet()
    var bundle: Bundle = .main

    @State private var station: BuoyStation?
    @State private var observation: BuoyObservation?
    @State private var failed = false

    var body: some View {
        if isMarine {
            VStack(alignment: .leading, spacing: 8) {
                // On the header text, not the enclosing VStack: an identifier on a
                // container collapses it into one accessibility element and hides
                // the rows inside from a UI test.
                Text("On the water").font(.headline)
                    .accessibilityIdentifier("buoySection")
                content
            }
            .task(id: siteKey) { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let observation, let station, !observation.isEmpty {
            Label(station.name, systemImage: "dot.radiowaves.up.forward")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let wave = observation.waveHeightMeters {
                reading("Wave height",
                        String(format: "%.1f ft", wave.value * 3.28084),
                        at: wave.observed)
            }
            if let temp = observation.waterTempCelsius {
                reading("Water temp",
                        String(format: "%.0f °F", temp.value * 9 / 5 + 32),
                        at: temp.observed)
            }
            Text("Latest NDBC buoy observation, not a forecast.")
                .font(.caption2)
                .foregroundStyle(DS.Ink.fineprint)
        } else if observation != nil {
            // The station answered and reported neither number. Saying so beats
            // rendering nothing, which reads as "nothing to report".
            Text("The nearest buoy isn't reporting waves or water temperature right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if failed {
            Text("Buoy conditions unavailable right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Link("Check NDBC", destination: URL(string: "https://www.ndbc.noaa.gov")!)
                .font(.caption)
        } else {
            ProgressView()
        }
    }

    private func reading(_ label: String, _ value: String, at observed: Date) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit())
            Text(Self.age.localizedString(for: observed, relativeTo: .now))
                .font(.caption2)
                .foregroundStyle(DS.Ink.fineprint)
                .frame(width: 74, alignment: .trailing)
        }
    }

    /// Keyed on the site, not the station: the iPad detail column keeps this view
    /// alive across sites, and a key that became the station id once loaded
    /// never changed again, so the previous site's reading stayed on screen.
    private var siteKey: String { "\(coordinate.longitude),\(coordinate.latitude)" }

    private static let age: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func load() async {
        guard isMarine else { return }
        station = nil
        observation = nil
        failed = false
        do {
            let stations = try NDBCLoader.loadStations(from: bundle)
            guard let nearest = NDBCLoader.nearest(to: coordinate, in: stations) else {
                failed = true
                return
            }
            station = nearest
            let data = try await client.data(from: NDBCLoader.observationsURL(stationID: nearest.id))
            guard !Task.isCancelled else { return }
            observation = try NDBCLoader.decodeLatest(data, stationID: nearest.id)
        } catch {
            // A fetch superseded by a site change is not a failed read.
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}
