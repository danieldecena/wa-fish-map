import Foundation

/// Sunrise and sunset for a calendar date at a place, from the NOAA solar equations
/// (accurate to a minute or two — plenty for a light hint). Pure math, no network;
/// the view injects the date, this never reads the clock.
struct SolarTimes: Equatable, Sendable {
    let sunrise: Date
    let sunset: Date

    /// Nil only when the sun never rises or sets there that day (polar latitudes) —
    /// unreachable for Washington, but the math's domain demands the guard. Callers
    /// fall back to the coarse hour buckets.
    static func compute(on date: Date, at coordinate: LonLat, calendar: Calendar = .current) -> SolarTimes? {
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let latRad = coordinate.latitude * .pi / 180

        // Fractional year (radians), then the NOAA equation-of-time (minutes) and
        // solar declination (radians) series.
        let gamma = 2 * .pi / 365 * (dayOfYear - 1)
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918
            - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        // Hour angle for a zenith of 90.833° (atmospheric refraction + solar radius).
        let zenith = 90.833 * Double.pi / 180
        let cosHourAngle = cos(zenith) / (cos(latRad) * cos(decl)) - tan(latRad) * tan(decl)
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return nil }
        let hourAngleDegrees = acos(cosHourAngle) * 180 / .pi

        // Minutes after UTC midnight of the local calendar date.
        let sunriseMinutes = 720 - 4 * (coordinate.longitude + hourAngleDegrees) - eqTime
        let sunsetMinutes = 720 - 4 * (coordinate.longitude - hourAngleDegrees) - eqTime

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let utcMidnight = utcCalendar.date(from: components) else { return nil }
        return SolarTimes(
            sunrise: utcMidnight.addingTimeInterval(sunriseMinutes * 60),
            sunset: utcMidnight.addingTimeInterval(sunsetMinutes * 60)
        )
    }
}
