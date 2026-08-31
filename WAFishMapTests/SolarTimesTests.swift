import Foundation
import Testing
@testable import WAFishMap

struct SolarTimesTests {
    private static let seattle = LonLat(longitude: -122.3321, latitude: 47.6062)

    private static let pacific: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        Self.pacific.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // Reference times from the NOAA solar calculator for Seattle.

    @Test func summerSolsticeSeattleMatchesNOAA() throws {
        let solar = try #require(
            SolarTimes.compute(on: date(2026, 6, 21, 12, 0), at: Self.seattle, calendar: Self.pacific)
        )
        #expect(abs(solar.sunrise.timeIntervalSince(date(2026, 6, 21, 5, 11))) < 6 * 60)
        #expect(abs(solar.sunset.timeIntervalSince(date(2026, 6, 21, 21, 11))) < 6 * 60)
    }

    @Test func winterSolsticeSeattleMatchesNOAA() throws {
        let solar = try #require(
            SolarTimes.compute(on: date(2026, 12, 21, 12, 0), at: Self.seattle, calendar: Self.pacific)
        )
        #expect(abs(solar.sunrise.timeIntervalSince(date(2026, 12, 21, 7, 55))) < 6 * 60)
        #expect(abs(solar.sunset.timeIntervalSince(date(2026, 12, 21, 16, 20))) < 6 * 60)
    }

    @Test func polarNightHasNoSunTimes() {
        let arctic = LonLat(longitude: 0, latitude: 85)
        #expect(SolarTimes.compute(on: date(2026, 12, 21, 12, 0), at: arctic, calendar: Self.pacific) == nil)
    }

    @Test func classifiesAgainstRealSunTimes() throws {
        let solar = try #require(
            SolarTimes.compute(on: date(2026, 6, 21, 12, 0), at: Self.seattle, calendar: Self.pacific)
        )
        #expect(TimeOfDay(date: solar.sunrise.addingTimeInterval(30 * 60), solar: solar) == .dawn)
        #expect(TimeOfDay(date: date(2026, 6, 21, 13, 0), solar: solar) == .day)
        #expect(TimeOfDay(date: solar.sunset.addingTimeInterval(-30 * 60), solar: solar) == .dusk)
        #expect(TimeOfDay(date: date(2026, 6, 21, 23, 30), solar: solar) == .night)
    }

    @Test func winterEarlyMorningIsNightNotDawn() throws {
        let solar = try #require(
            SolarTimes.compute(on: date(2026, 12, 21, 5, 30), at: Self.seattle, calendar: Self.pacific)
        )
        // The fixed hour buckets called 5:30 AM dawn year-round; in December the sun
        // is 2.5 hours away and this is night.
        #expect(TimeOfDay(date: date(2026, 12, 21, 5, 30), solar: solar) == .night)
    }
}
