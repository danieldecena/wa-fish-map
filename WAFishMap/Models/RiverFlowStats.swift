import Foundation

/// Each river's own day-of-year flow distribution, bundled from USGS daily
/// statistics by `scripts/build_river_stats.py`.
///
/// This exists because discharge is meaningless across rivers — the Columbia
/// dwarfs everything, so an absolute scale paints the whole state one colour.
/// A reading only means something against the same river's own history for the
/// same week of the year, which is also how anglers actually talk about it.
struct RiverFlowStats: Decodable, Equatable, Sendable {
    let gauge: String
    let gaugeName: String
    let hasTemp: Bool
    let beginYear: Int
    let endYear: Int
    /// Percentile labels, in the order `months` stores them: p10, p25, p50, p75, p90.
    let percentiles: [String]
    /// Keyed by month number as a string ("1"…"12"); each value is that month's
    /// days in order. February carries 29 entries for most gauges and 28 for the
    /// ten whose record is too short for USGS to publish a leap-day statistic —
    /// `percentiles(month:day:)` is where that difference is absorbed.
    let months: [String: [[Double]]]

    var yearsOfRecord: Int { max(0, endYear - beginYear) }

    /// The five percentile values for a calendar day, or nil if the table has
    /// no row for it. Month and day are injected — nothing here reads the clock.
    ///
    /// A day one past the end of a month falls back to the last row it has.
    /// In practice that is only ever February 29: ten of the shorter-record
    /// gauges have no leap-day statistic, and USGS not publishing one is a fact
    /// about the source. Substituting February 28's distribution here keeps the
    /// bundled table a faithful copy and puts the substitution somewhere a
    /// reader can see it, rather than inventing a row in the data file.
    func percentiles(month: Int, day: Int) -> [Double]? {
        guard let days = months[String(month)], !days.isEmpty, day >= 1,
              day <= days.count + 1 else { return nil }
        return days[min(day, days.count) - 1]
    }

    /// Where today's discharge sits in this river's own distribution.
    ///
    /// Deliberately non-monotonic: a river is unfishable when it is bony and
    /// unfishable when it is blowing out, so both tails read the same. And
    /// deliberately capped below `.excellent` — normal flow means conditions
    /// are workable, never that fish are in the river, and Prime is the
    /// seasonal guide's word to spend, not this layer's.
    func rating(discharge: Double, month: Int, day: Int) -> FishingRating? {
        guard let p = percentiles(month: month, day: day), p.count == 5 else { return nil }
        let (p10, p25, p75, p90) = (p[0], p[1], p[3], p[4])
        if discharge < p10 || discharge >= p90 { return .poor }
        if discharge < p25 || discharge >= p75 { return .fair }
        return .good
    }

    /// Plain words for the same position, for the detail sheet.
    func summary(discharge: Double, month: Int, day: Int) -> String? {
        guard let p = percentiles(month: month, day: day), p.count == 5 else { return nil }
        let (p10, p25, p75, p90) = (p[0], p[1], p[3], p[4])
        if discharge < p10 { return "Very low for early this month" }
        if discharge < p25 { return "Low for the time of year" }
        if discharge < p75 { return "Typical for the time of year" }
        if discharge < p90 { return "High for the time of year" }
        return "Very high — likely blown out"
    }
}

/// Decodes the bundled flow history. Static, offline data — no network.
enum RiverFlowStatsLoader {
    struct Payload: Decodable {
        let rivers: [String: RiverFlowStats]
    }

    static func stats(from data: Data) throws -> [String: RiverFlowStats] {
        try JSONDecoder().decode(Payload.self, from: data).rivers
    }
}
