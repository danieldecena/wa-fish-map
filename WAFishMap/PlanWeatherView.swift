import SwiftUI
import WeatherKit
import CoreLocation
import OSLog

extension HourWeather: ForecastHour {}

/// Wind and precipitation for the hour the user is planning, from WeatherKit.
///
/// Shown for every site, not just marine ones: wind matters on a lake as much as
/// in the Sound, and rain matters on a riverbank.
struct PlanWeatherView: View {
    let coordinate: LonLat
    let planDate: Date

    @State private var weather: PlanWeather?
    @State private var failed = false
    @State private var outOfRange = false
    @State private var attribution: WeatherAttribution?

    @Environment(\.colorScheme) private var colorScheme

    /// One fetch per place-and-hour per `CachedPlanWeather.maxAge`. The sheet is
    /// rebuilt on every tap, so without this reopening the same site spends
    /// another call against the 500k/month quota; with no age at all it showed a
    /// forecast WeatherKit had since revised.
    @MainActor private static var cache: [String: CachedPlanWeather] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wind & rain").font(.headline)
                .accessibilityIdentifier("planWeatherSection")
            content
        }
        .task(id: hourKey) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let weather {
            HStack {
                Label("Wind", systemImage: "wind").font(.subheadline)
                Spacer()
                Text("\(weather.windCompassPoint) \(Int(weather.windSpeedMph.rounded())) mph")
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                Label("Rain", systemImage: "cloud.rain").font(.subheadline)
                Spacer()
                Text("\(Int((weather.precipitationChance * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                Label("Air", systemImage: "thermometer.medium").font(.subheadline)
                Spacer()
                Text("\(Int(weather.temperatureFahrenheit.rounded())) °F")
                    .font(.subheadline.monospacedDigit())
            }
            Text("Forecast for \(Self.hourLabel.string(from: weather.hour)), not an observation.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            attributionMark
        } else if outOfRange {
            // The forecast does not reach the chosen date. Saying which is the
            // point — falling back to the nearest available hour would answer a
            // question the user did not ask.
            Text("The forecast doesn't reach that date yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if failed {
            Text("Wind and rain unavailable right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ProgressView()
        }
    }

    /// Apple requires attribution for any published use of WeatherKit, and the
    /// mark and legal link come from the service rather than being hardcoded, so
    /// they follow whatever Apple serves. Drawn only alongside a real reading:
    /// attributing data that failed to load would be a claim about nothing.
    ///
    /// App Review rejected 1.0 (6) under 5.2.5 (2026-09-21) because a 12pt faded
    /// mark with only a chevron for the legal link did not read as attribution.
    /// The mark is now full contrast and the legal source is a labelled link.
    @ViewBuilder private var attributionMark: some View {
        if let attribution {
            HStack(spacing: 12) {
                Link(destination: attribution.legalPageURL) {
                    AsyncImage(
                        url: colorScheme == .dark
                            ? attribution.combinedMarkDarkURL
                            : attribution.combinedMarkLightURL
                    ) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(attribution.serviceName).font(.caption)
                    }
                    .frame(height: 20)
                }
                .accessibilityIdentifier("weatherAttribution")
                .accessibilityLabel("Weather data by \(attribution.serviceName). Opens legal attribution.")
                Link("Other data sources", destination: attribution.legalPageURL)
                    .font(.caption)
                    .accessibilityIdentifier("weatherLegalLink")
            }
        }
    }

    /// Refetch when the plan moves to a different hour or a different place.
    private var hourKey: String {
        let hour = Calendar.current.dateInterval(of: .hour, for: planDate)?.start ?? planDate
        return "\(coordinate.longitude),\(coordinate.latitude),\(hour.timeIntervalSince1970)"
    }

    private static let hourLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h a"
        return f
    }()

    /// Every failure renders the same one string, so without this a JWT refusal
    /// and a dropped network are indistinguishable after the fact.
    private static let log = Logger(subsystem: "com.danieldecena.WAFishMap", category: "weather")

    private func load() async {
        // Captured once. `hourKey` and `planDate` read the view's current values,
        // so after an await they can already belong to the next hour; the fetch
        // must be filed under the place and hour it was asked for.
        let key = hourKey
        let plan = planDate
        failed = false
        outOfRange = false
        if let hit = Self.cache[key], hit.isFresh(at: Date()) {
            weather = hit.weather
            await loadAttribution()
            return
        }
        weather = nil
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let forecast = try await WeatherService.shared.weather(for: location, including: .hourly)
            // A superseded task (the user moved the plan or the site) must not
            // write its answer over the newer one.
            guard !Task.isCancelled else { return }
            guard let hour = PlanWeatherSelection.hour(covering: plan, in: Array(forecast)) else {
                outOfRange = true
                return
            }
            let reading = PlanWeather(
                hour: hour.date,
                windSpeedMph: hour.wind.speed.converted(to: .milesPerHour).value,
                windDirectionDegrees: hour.wind.direction.converted(to: .degrees).value,
                precipitationChance: hour.precipitationChance,
                temperatureFahrenheit: hour.temperature.converted(to: .fahrenheit).value
            )
            weather = reading
            Self.cache[key] = CachedPlanWeather(weather: reading, fetchedAt: Date())
            await loadAttribution()
        } catch {
            // Cancellation is not a failure; the task that replaced this one
            // owns the section now.
            guard !Task.isCancelled else { return }
            failed = true
            Self.log.error("WeatherKit hourly fetch failed: \(error, privacy: .public)")
        }
    }

    /// Attribution failing must not blank a good reading, so it is fetched apart
    /// from the forecast and its failure only costs the mark.
    private func loadAttribution() async {
        guard attribution == nil else { return }
        do {
            attribution = try await WeatherService.shared.attribution
        } catch {
            Self.log.error("WeatherKit attribution fetch failed: \(error, privacy: .public)")
        }
    }
}
