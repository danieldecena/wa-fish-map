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
        weather = nil
        failed = false
        outOfRange = false
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
        } catch {
            failed = true
            Self.log.error("WeatherKit hourly fetch failed: \(error, privacy: .public)")
        }
    }
}
