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
    /// The forecast hour covering `date` — the latest hour at or before it, so a
    /// 6:45 PM plan reads the 6 PM hour rather than the 7 PM one.
    ///
    /// Returns nil when every hour is later than the plan: a forecast that does
    /// not reach the requested time must say nothing rather than substitute its
    /// closest guess, which would silently answer a different question.
    static func hour<H: ForecastHour>(covering date: Date, in hours: [H]) -> H? {
        hours.filter { $0.date <= date }.max { $0.date < $1.date }
    }
}
