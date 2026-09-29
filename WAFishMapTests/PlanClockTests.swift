import Foundation
import Testing
@testable import WAFishMap

/// Pins the rule `SiteDetailSheet`, `PierDetailSheet` and `RiverDetailSheet`
/// share with the map: a plan date's month is read in Pacific time, never the
/// device's own zone. A device on Eastern reading `Calendar.current` for a plan
/// date of Mar 31 21:30 Pacific would land in April while the map (already on
/// `Calendar.pacific`) says March — the badge and the pin disagreeing about
/// which month is even being planned for.
struct PlanClockTests {
    private static let pacific: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        Self.pacific.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    @Test func monthIsPacificEvenWhenUTCOrEasternDisagree() {
        let planDate = date(2026, 3, 31, 21, 30)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // Fixture sanity: this instant really does fall in a different month in
        // UTC (and therefore in Eastern too), or the test would prove nothing.
        #expect(utc.component(.month, from: planDate) == 4)

        #expect(PlanClock.month(for: planDate) == 3)
    }

    @Test func dayIsPacificEvenWhenUTCDisagrees() {
        let planDate = date(2026, 3, 31, 21, 30)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(utc.component(.day, from: planDate) == 1)

        #expect(PlanClock.day(for: planDate) == 31)
    }

    /// Drives the odd/even-year species stamp (Pink Salmon), so it needs the same
    /// Pacific-not-device-zone rule as month/day: Dec 31 23:30 Pacific is already
    /// Jan 1 in UTC, a year later.
    @Test func yearIsPacificEvenWhenUTCDisagrees() {
        let planDate = date(2026, 12, 31, 23, 30)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // Fixture sanity: this instant really does fall in the next year in UTC.
        #expect(utc.component(.year, from: planDate) == 2027)

        #expect(PlanClock.year(for: planDate) == 2026)
    }
}

/// The header's one date control replaced two pills, so its label has to carry
/// both halves -- a chip that dropped the time would silently lose the thing
/// the time-of-day rating is computed from.
struct PlanLabelTests {

    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    @Test func theLabelCarriesBothTheDateAndTheTime() {
        let label = FishingMapView.planLabel(Self.date("2026-09-20T14:33:00-07:00"))
        #expect(label.contains("Sep 20"))
        #expect(label.contains("2:33"))
        #expect(label.contains("PM"))
    }

    @Test func theLabelStaysShortEnoughForAChip() {
        for iso in ["2026-01-01T00:05:00-08:00", "2026-12-31T23:59:00-08:00",
                    "2026-09-20T02:33:00-07:00"] {
            let label = FishingMapView.planLabel(Self.date(iso))
            #expect(label.count <= 18, "\(label) is too long for the header chip")
        }
    }

    /// Pacific, like everything else in this app that renders a time. A label
    /// rendered in the device's zone would disagree with the tide table beside
    /// it.
    @Test func theLabelIsRenderedInPacificTime() {
        let midnightUTC = Self.date("2026-09-20T07:00:00Z")
        #expect(FishingMapView.planLabel(midnightUTC).contains("12:00 AM"))
        #expect(FishingMapView.planLabel(midnightUTC).contains("Sep 20"))
    }
}
