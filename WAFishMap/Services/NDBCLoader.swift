import Foundation

enum NDBCError: Error, Equatable {
    case missingBundleResource
    case malformedHeader
    case noRows
}

/// Reads NDBC's `realtime2` fixed-column text feed.
///
/// The columns are addressed by name from the header rather than by index: the
/// feed carries 19 columns today, and a positional parser would start reading
/// the wrong number the day NOAA adds one, without failing.
enum NDBCLoader {
    private static let endpoint = "https://www.ndbc.noaa.gov/data/realtime2"

    static func loadStations(from bundle: Bundle) throws -> [BuoyStation] {
        guard let url = bundle.url(forResource: "ndbc-stations", withExtension: "json") else {
            throw NDBCError.missingBundleResource
        }
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)).stations
    }

    private struct Catalog: Decodable {
        let stations: [BuoyStation]
    }

    static func observationsURL(stationID: String) -> URL {
        URL(string: "\(endpoint)/\(stationID).txt")!
    }

    /// Nearest buoy by great-circle distance, or nil when the catalog is empty.
    static func nearest(to point: LonLat, in stations: [BuoyStation]) -> BuoyStation? {
        stations.min { a, b in
            point.distance(to: a.coordinate) < point.distance(to: b.coordinate)
        }
    }

    /// The newest non-missing value for each field, each with its own timestamp.
    ///
    /// `MM` is NDBC's missing marker and must not be read as zero: a wave height
    /// of 0.0 m is flat calm, which is a claim about the water, while `MM` is the
    /// buoy declining to answer.
    static func decodeLatest(_ data: Data, stationID: String,
                             calendar: Calendar = .current) throws -> BuoyObservation {
        guard let text = String(data: data, encoding: .utf8) else { throw NDBCError.malformedHeader }
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)

        guard let header = lines.first, header.hasPrefix("#") else { throw NDBCError.malformedHeader }
        let columns = header.dropFirst().split(separator: " ").map(String.init)
        guard let waveIndex = columns.firstIndex(of: "WVHT"),
              let tempIndex = columns.firstIndex(of: "WTMP") else { throw NDBCError.malformedHeader }

        lines.removeAll { $0.hasPrefix("#") }
        guard !lines.isEmpty else { throw NDBCError.noRows }

        var wave: BuoyObservation.Reading<Double>?
        var temp: BuoyObservation.Reading<Double>?

        for line in lines {
            if wave != nil && temp != nil { break }
            let f = line.split(separator: " ").map(String.init)
            guard f.count > max(waveIndex, tempIndex), let stamp = timestamp(f, calendar: calendar)
            else { continue }
            if wave == nil, let v = value(f[waveIndex]) {
                wave = .init(value: v, observed: stamp)
            }
            if temp == nil, let v = value(f[tempIndex]) {
                temp = .init(value: v, observed: stamp)
            }
        }
        return BuoyObservation(stationID: stationID, waveHeightMeters: wave, waterTempCelsius: temp)
    }

    /// `MM` — and anything else non-numeric — is absence, not a number.
    private static func value(_ field: String) -> Double? {
        field == "MM" ? nil : Double(field)
    }

    /// The first five fields are year, month, day, hour, minute, in UTC.
    private static func timestamp(_ f: [String], calendar: Calendar) -> Date? {
        guard f.count >= 5,
              let y = Int(f[0]), let mo = Int(f[1]), let d = Int(f[2]),
              let h = Int(f[3]), let mi = Int(f[4]) else { return nil }
        var utc = calendar
        utc.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return utc.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))
    }
}
