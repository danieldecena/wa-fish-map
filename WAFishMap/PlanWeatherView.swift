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

    /// One fetch per place-and-hour for the life of the process. The sheet is
    /// rebuilt on every tap, so without this reopening the same site in the same
    /// hour spends another call against the 500k/month quota for an answer that
    /// cannot have changed.
    @MainActor private static var cache: [String: PlanWeather] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wind & rain").font(DS.TypeScale.sectionTitle)
                .accessibilityIdentifier("planWeatherSection")
            content
        }
        .task(id: hourKey) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let weather {
            HStack {
                Label("Wind", systemImage: "wind").font(DS.TypeScale.supporting)
                Spacer()
                Text("\(weather.windCompassPoint) \(Int(weather.windSpeedMph.rounded())) mph")
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                Label("Rain", systemImage: "cloud.rain").font(DS.TypeScale.supporting)
                Spacer()
                Text("\(Int((weather.precipitationChance * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                Label("Air", systemImage: "thermometer.medium").font(DS.TypeScale.supporting)
                Spacer()
                Text("\(Int(weather.temperatureFahrenheit.rounded())) °F")
                    .font(.subheadline.monospacedDigit())
            }
            Text("Forecast for \(Self.hourLabel.string(from: weather.hour)), not an observation.")
                .font(DS.TypeScale.fineprint)
                .foregroundStyle(.tertiary)
            attributionMark
        } else if outOfRange {
            // The forecast does not reach the chosen date. Saying which is the
            // point — falling back to the nearest available hour would answer a
            // question the user did not ask.
            Text("The forecast doesn't reach that date yet.")
                .font(DS.TypeScale.supporting)
                .foregroundStyle(.secondary)
        } else if failed {
            Text("Wind and rain unavailable right now.")
                .font(DS.TypeScale.supporting)
                .foregroundStyle(.secondary)
        } else {
            ProgressView()
        }
    }

    /// Apple requires attribution for any published use of WeatherKit, and the
    /// mark and legal link come from the service rather than being hardcoded, so
    /// they follow whatever Apple serves. Drawn only alongside a real reading:
    /// attributing data that failed to load would be a claim about nothing.
    @ViewBuilder private var attributionMark: some View {
        if let attribution {
            Link(destination: attribution.legalPageURL) {
                HStack(spacing: 4) {
                    AsyncImage(
                        url: colorScheme == .dark
                            ? attribution.combinedMarkDarkURL
                            : attribution.combinedMarkLightURL
                    ) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(attribution.serviceName).font(DS.TypeScale.fineprint)
                    }
                    .frame(height: 12)
                    Image(systemName: "chevron.right").font(DS.TypeScale.fineprint).imageScale(.small)
                }
                .foregroundStyle(.tertiary)
            }
            .accessibilityIdentifier("weatherAttribution")
            .accessibilityLabel("Weather data by \(attribution.serviceName). Opens legal attribution.")
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
        failed = false
        outOfRange = false
        if let hit = Self.cache[hourKey] {
            weather = hit
            await loadAttribution()
            return
        }
        weather = nil
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let forecast = try await WeatherService.shared.weather(for: location, including: .hourly)
            guard let hour = PlanWeatherSelection.hour(covering: planDate, in: Array(forecast)) else {
                outOfRange = true
                return
            }
            weather = PlanWeather(
                hour: hour.date,
                windSpeedMph: hour.wind.speed.converted(to: .milesPerHour).value,
                windDirectionDegrees: hour.wind.direction.converted(to: .degrees).value,
                precipitationChance: hour.precipitationChance,
                temperatureFahrenheit: hour.temperature.converted(to: .fahrenheit).value
            )
            Self.cache[hourKey] = weather
            await loadAttribution()
        } catch {
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
