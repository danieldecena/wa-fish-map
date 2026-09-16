import Foundation
import Testing
@testable import WAFishMap

/// The flow band is the whole claim this layer makes, so it is tested at the
/// edges rather than in the middle. A monotonic bug — treating more water as
/// simply better — passes any single-tail test, so both tails are asserted
/// together and by name.
struct RiverFlowBandTests {
    /// p10 1000, p25 2000, p50 3000, p75 4000, p90 5000 for every day of a
    /// two-day month, so a test can name a day without arithmetic.
    private static let stats = RiverFlowStats(
        gauge: "12194000",
        gaugeName: "SKAGIT RIVER NEAR CONCRETE, WA",
        hasTemp: false,
        beginYear: 1925,
        endYear: 2026,
        percentiles: ["p10", "p25", "p50", "p75", "p90"],
        months: ["9": [[1000, 2000, 3000, 4000, 5000],
                       [1000, 2000, 3000, 4000, 5000]]]
    )

    private func rating(_ discharge: Double) -> FishingRating? {
        Self.stats.rating(discharge: discharge, month: 9, day: 1)
    }

    @Test func bothTailsReadTheSameBecauseBothAreUnfishable() {
        #expect(rating(500) == .poor)      // bony
        #expect(rating(9000) == .poor)     // blown out
    }

    @Test func theShouldersAreFairOnEitherSide() {
        #expect(rating(1500) == .fair)
        #expect(rating(4500) == .fair)
    }

    @Test func typicalFlowIsGood() {
        #expect(rating(2500) == .good)
        #expect(rating(3000) == .good)
        #expect(rating(3900) == .good)
    }

    /// Flow says conditions are workable. It never says fish are in the river,
    /// so Prime stays the seasonal guide's word to spend.
    @Test func flowNeverEarnsPrime() {
        for discharge in stride(from: 0.0, through: 10_000, by: 50) {
            #expect(rating(discharge) != .excellent)
        }
    }

    /// Boundaries are half-open upward, so a reading exactly on a percentile
    /// lands in the band above it, not in two bands or neither.
    @Test func exactPercentileValuesLandInOneBand() {
        #expect(rating(1000) == .fair)     // exactly p10
        #expect(rating(2000) == .good)     // exactly p25
        #expect(rating(4000) == .fair)     // exactly p75
        #expect(rating(5000) == .poor)     // exactly p90
    }

    @Test func aDayTheTableDoesNotCoverHasNoRating() {
        // Day 3 is one past this two-day fixture, so it deliberately clamps —
        // that is the leap-day fallback. Day 4 is genuinely out of range.
        #expect(Self.stats.rating(discharge: 3000, month: 9, day: 3) == .good)
        #expect(Self.stats.rating(discharge: 3000, month: 9, day: 4) == nil)
        #expect(Self.stats.rating(discharge: 3000, month: 10, day: 1) == nil)
    }

    @Test func summaryDescribesThePositionInWords() {
        #expect(Self.stats.summary(discharge: 500, month: 9, day: 1)?.contains("Very low") == true)
        #expect(Self.stats.summary(discharge: 3000, month: 9, day: 1)?.contains("Typical") == true)
        #expect(Self.stats.summary(discharge: 9000, month: 9, day: 1)?.contains("blown out") == true)
        #expect(Self.stats.summary(discharge: 3000, month: 10, day: 1) == nil)
    }
}

struct USGSFlowLoaderTests {
    private static func payload(_ value: String, parameter: String = "00060") -> Data {
        """
        {"value":{"timeSeries":[
          {"sourceInfo":{"siteName":"SKAGIT RIVER NEAR CONCRETE, WA","siteCode":[{"value":"12194000"}]},
           "variable":{"variableCode":[{"value":"\(parameter)"}]},
           "values":[{"value":[{"value":"\(value)","dateTime":"2026-09-03T20:30:00.000-07:00"}]}]}
        ]}}
        """.data(using: .utf8)!
    }

    @Test func readsDischargeAndItsTimestamp() throws {
        let flows = try USGSFlowLoader.flows(from: Self.payload("7760"))
        let skagit = try #require(flows["12194000"])
        #expect(skagit.discharge == 7760)
        #expect(skagit.gaugeName == "SKAGIT RIVER NEAR CONCRETE, WA")
        #expect(skagit.dischargeAt != nil, "USGS stamps a numeric offset and fractional seconds")
        #expect(skagit.waterTempC == nil)
    }

    @Test func waterTemperatureConvertsAndKeepsItsOwnTimestamp() throws {
        let flows = try USGSFlowLoader.flows(from: Self.payload("10.0", parameter: "00010"))
        let gauge = try #require(flows["12194000"])
        #expect(gauge.waterTempC == 10.0)
        #expect(gauge.waterTempF == 50.0)
        #expect(gauge.waterTempAt != nil)
        // Temperature arriving does not invent a discharge.
        #expect(gauge.discharge == nil)
    }

    /// USGS marks an offline or ice-affected gauge with a sentinel rather than
    /// omitting it. Taking -999999 as a reading would put the river below its
    /// own p10 and paint it Slow — a fabricated observation, not a missing one.
    @Test func theOfflineSentinelIsRejectedRatherThanReadAsAValue() throws {
        let flows = try USGSFlowLoader.flows(from: Self.payload("-999999"))
        #expect(flows["12194000"]?.discharge == nil)
    }

    /// The control for the test above: a genuinely small reading must survive,
    /// or "rejects the sentinel" could not be told from "rejects everything".
    @Test func anOrdinaryLowReadingIsKept() throws {
        let flows = try USGSFlowLoader.flows(from: Self.payload("3.2"))
        #expect(flows["12194000"]?.discharge == 3.2)
    }

    @Test func theRequestAsksForBothParametersStatewide() {
        let query = USGSFlowLoader.url.absoluteString
        #expect(query.contains("stateCd=wa"))
        #expect(query.contains("00060"))
        #expect(query.contains("00010"))
    }
}

/// A data-quality gate over the shipped table, in the spirit of `RiverTests`.
struct RiverFlowStatsResourceTests {
    private static func bundled() throws -> [String: RiverFlowStats] {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "river_stats", withExtension: "json"))
        return try RiverFlowStatsLoader.stats(from: Data(contentsOf: url))
    }

    @Test func theRiversWorthCheckingHaveFlowHistory() throws {
        let stats = try Self.bundled()
        for river in ["Skagit River", "Snoqualmie River", "Yakima River",
                      "Cowlitz River", "Wenatchee River", "Chehalis River"] {
            #expect(stats[river] != nil, "\(river) has no flow history")
        }
    }

    /// Every gauge covers all twelve months with five percentiles per row.
    @Test func everyTableIsComplete() throws {
        for (name, stats) in try Self.bundled() {
            #expect(stats.months.count == 12, "\(name) is missing months")
            for (month, days) in stats.months {
                #expect(days.allSatisfy { $0.count == 5 },
                        "\(name) month \(month) has a row without five percentiles")
            }
        }
    }

    /// Ten shorter-record gauges have no leap-day statistic, so this asserts the
    /// *behaviour* rather than the row count: February 29 must resolve for every
    /// river, or those rivers would go grey once every four years — a bug that
    /// only ever shows up on a day nobody tests on.
    @Test func februaryTwentyNineResolvesForEveryRiver() throws {
        let stats = try Self.bundled()
        let shortRecords = stats.filter { $0.value.months["2"]?.count == 28 }
        #expect(!shortRecords.isEmpty, "no gauge lacks a Feb 29 row, so this proves nothing")

        for (name, river) in stats {
            #expect(river.percentiles(month: 2, day: 29) != nil,
                    "\(name) cannot answer for Feb 29")
        }
        // The fallback is February 28's row, not an invented one.
        let (name, short) = try #require(shortRecords.first)
        #expect(short.percentiles(month: 2, day: 29) == short.percentiles(month: 2, day: 28),
                "\(name) should fall back to Feb 28")
    }

    /// The control: clamping must not swallow a genuinely out-of-range day, or
    /// "handles Feb 29" could not be told from "accepts any day at all".
    @Test func aDayWellPastTheEndOfAMonthStillHasNoAnswer() throws {
        let stats = try #require(try Self.bundled()["Skagit River"])
        #expect(stats.percentiles(month: 2, day: 31) == nil)
        #expect(stats.percentiles(month: 9, day: 0) == nil)
        #expect(stats.percentiles(month: 13, day: 1) == nil)
    }

    /// Percentiles that are not ascending would make the band logic nonsense.
    @Test func percentilesAscendWithinEveryRow() throws {
        for (name, stats) in try Self.bundled() {
            for (month, days) in stats.months {
                for row in days {
                    #expect(row == row.sorted(),
                            "\(name) month \(month) has a row out of order: \(row)")
                }
            }
        }
    }

    /// A short record makes percentiles mean little; the generator picks the
    /// longest-record gauge per river, and this is what proves it did.
    @Test func everyRiverIsBackedByARealRecord() throws {
        for (name, stats) in try Self.bundled() {
            #expect(stats.yearsOfRecord >= 10, "\(name) has only \(stats.yearsOfRecord) years")
            #expect(!stats.gauge.isEmpty)
        }
    }
}
