import Foundation

/// Wind and precipitation for the hour being planned.
///
/// Unlike the buoy readings, this is a *forecast* — a model's opinion about a
/// future hour, not something an instrument measured. The view says so, and the
/// hour it applies to is carried here rather than assumed to be "now", because
/// the whole point is that the user is planning a trip for a date they picked.
struct PlanWeather: Equatable, Sendable {
    let hour: Date
    let windSpeedMph: Double
    let windDirectionDegrees: Double
    let precipitationChance: Double
    let temperatureFahrenheit: Double

    /// "NE", "SSW" — sixteen points, the resolution an angler actually uses.
    var windCompassPoint: String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let step = 360.0 / Double(points.count)
        let normalized = windDirectionDegrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        let index = Int((positive / step).rounded()) % points.count
        return points[index]
    }
}

/// The subset of an hourly forecast this app reads. Declared as a protocol so
/// the hour-selection rule can be tested without constructing WeatherKit's own
/// `HourWeather`, which has no public initializer.
protocol ForecastHour {
    var date: Date { get }
}

enum PlanWeatherSelection {
    static let hourLength: TimeInterval = 3600

    /// The forecast hour covering `date`: the hour that starts at or before it and
    /// has not ended, so a 6:45 PM plan reads the 6 PM hour rather than the 7 PM one.
    ///
    /// Returns nil when no hour covers the plan, on either side. A forecast that
    /// does not reach the requested time must say nothing rather than substitute
    /// its closest guess, which would silently answer a different question. The
    /// "has not ended" half is what stops a plan days past the forecast from
    /// reading the forecast's last hour.
    static func hour<H: ForecastHour>(covering date: Date, in hours: [H]) -> H? {
        hours.filter { $0.date <= date && date < $0.date.addingTimeInterval(hourLength) }
            .max { $0.date < $1.date }
    }
}

/// A forecast held for reuse, with the moment it was fetched. A forecast for a
/// fixed future hour is revised as that hour approaches, so a copy kept for the
/// life of the process would keep showing an answer WeatherKit has since changed.
struct CachedPlanWeather: Sendable {
    static let maxAge: TimeInterval = 3600

    let weather: PlanWeather
    let fetchedAt: Date

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) < Self.maxAge
    }
}
