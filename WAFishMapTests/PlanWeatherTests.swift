import Foundation
import Testing
@testable import WAFishMap

/// The hour-selection rule and the compass conversion are the parts that can be
/// wrong quietly. The WeatherKit call itself is not tested here: it needs the
/// network and an entitlement, so asserting a wind speed would test Apple's
/// service rather than this app.
@Suite("Plan weather")
struct PlanWeatherTests {
    private struct Hour: ForecastHour {
        let date: Date
    }

    private static func at(_ hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 2; c.hour = hour; c.minute = minute
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    private static let hours = (0...23).map { Hour(date: at($0)) }

    @Test func aPlanTimeReadsTheHourItFallsInside() {
        let picked = PlanWeatherSelection.hour(covering: Self.at(18, minute: 45), in: Self.hours)
        #expect(picked?.date == Self.at(18), "6:45 PM must read the 6 PM hour, not 7 PM.")
    }

    @Test func anExactHourReadsItself() {
        #expect(PlanWeatherSelection.hour(covering: Self.at(6), in: Self.hours)?.date == Self.at(6))
    }

    /// A forecast that does not reach the plan date says nothing. Substituting
    /// the closest available hour would answer a different question while looking
    /// like an answer to this one.
    @Test func aPlanBeyondTheForecastReturnsNothingRatherThanTheClosestHour() {
        let earlyOnly = [Hour(date: Self.at(1)), Hour(date: Self.at(2))]
        #expect(PlanWeatherSelection.hour(covering: Self.at(0), in: earlyOnly) == nil)
    }

    @Test func anEmptyForecastReturnsNothing() {
        #expect(PlanWeatherSelection.hour(covering: Self.at(12), in: [Hour]()) == nil)
    }

    // MARK: Compass

    private func weather(direction: Double) -> PlanWeather {
        PlanWeather(hour: Self.at(12), windSpeedMph: 10,
                    windDirectionDegrees: direction,
                    precipitationChance: 0, temperatureFahrenheit: 60)
    }

    @Test func theCardinalPointsAreRight() {
        #expect(weather(direction: 0).windCompassPoint == "N")
        #expect(weather(direction: 90).windCompassPoint == "E")
        #expect(weather(direction: 180).windCompassPoint == "S")
        #expect(weather(direction: 270).windCompassPoint == "W")
    }

    @Test func theSixteenthPointsAreRight() {
        #expect(weather(direction: 22.5).windCompassPoint == "NNE")
        #expect(weather(direction: 225).windCompassPoint == "SW")
    }

    /// 350° is nearer to N than to NNW, and must not index past the end of the
    /// table — the wrap is where an off-by-one crashes rather than misreports.
    @Test func theWrapAroundNorthIsHandled() {
        #expect(weather(direction: 350).windCompassPoint == "N")
        #expect(weather(direction: 359.9).windCompassPoint == "N")
        #expect(weather(direction: 360).windCompassPoint == "N")
        #expect(weather(direction: 720).windCompassPoint == "N")
    }
}
