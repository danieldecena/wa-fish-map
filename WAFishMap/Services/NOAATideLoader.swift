import Foundation

enum NOAATideError: Error, Equatable {
    case missingBundleResource
    case apiMessage(String)
    case emptyPredictions
    case badTime(String)
}

enum NOAATideLoader {
    private static let endpoint = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"

    static func loadStations(from bundle: Bundle) throws -> [TideStation] {
        guard let url = bundle.url(forResource: "tide-stations", withExtension: "json") else {
            throw NOAATideError.missingBundleResource
        }
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        return catalog.stations
    }

    static func predictionsURL(stationID: String, day: Date, calendar: Calendar) -> URL {
        let ymd = yyyymmdd(day, calendar: calendar)
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "begin_date", value: ymd),
            URLQueryItem(name: "end_date", value: ymd),
            URLQueryItem(name: "station", value: stationID),
            URLQueryItem(name: "product", value: "predictions"),
            URLQueryItem(name: "datum", value: "MLLW"),
            URLQueryItem(name: "time_zone", value: "lst_ldt"),
            URLQueryItem(name: "interval", value: "hilo"),
            URLQueryItem(name: "units", value: "english"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "application", value: "WAFishMap"),
        ]
        return components.url!
    }

    static func decodePredictions(
        _ data: Data, station: TideStation, calendar: Calendar
    ) throws -> TideTable {
        let response = try JSONDecoder().decode(NOAAResponse.self, from: data)
        if let message = response.error?.message {
            throw NOAATideError.apiMessage(message)
        }
        guard let rows = response.predictions, !rows.isEmpty else {
            throw NOAATideError.emptyPredictions
        }
        let extremes: [TideExtreme] = try rows.map { row in
            guard let time = parseTime(row.t, calendar: calendar) else {
                throw NOAATideError.badTime(row.t)
            }
            guard let height = Double(row.v) else {
                throw NOAATideError.apiMessage("bad height \(row.v)")
            }
            let kind: TideExtreme.Kind = row.type.uppercased() == "H" ? .high : .low
            return TideExtreme(time: time, heightFeet: height, kind: kind)
        }
        return TideTable(station: station, extremes: extremes)
    }

    static func fetch(
        station: TideStation,
        day: Date,
        client: HTTPGet,
        calendar: Calendar
    ) async throws -> TideTable {
        let data = try await client.data(from: predictionsURL(
            stationID: station.id, day: day, calendar: calendar
        ))
        return try decodePredictions(data, station: station, calendar: calendar)
    }

    // MARK: - private

    private struct Catalog: Decodable {
        let stations: [TideStation]
    }

    private struct NOAAResponse: Decodable {
        let predictions: [Row]?
        let error: APIError?
        struct Row: Decodable {
            let t: String
            let v: String
            let type: String
        }
        struct APIError: Decodable {
            let message: String
        }
    }

    private static func yyyymmdd(_ day: Date, calendar: Calendar) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    /// NOAA `lst_ldt` timestamps look like "2026-08-31 01:34".
    private static func parseTime(_ raw: String, calendar: Calendar) -> Date? {
        let parts = raw.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" })
        guard parts.count == 5,
              let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]),
              let h = Int(parts[3]), let mi = Int(parts[4]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))
    }
}
