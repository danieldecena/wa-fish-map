import Foundation
import Testing
@testable import WAFishMap

struct TidePredictionTests {
    private static let pacific: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        Self.pacific.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private let seattle = TideStation(
        id: "9447130", name: "Seattle",
        coordinate: LonLat(longitude: -122.3393, latitude: 47.6026)
    )
    private let neah = TideStation(
        id: "9443090", name: "Neah Bay",
        coordinate: LonLat(longitude: -124.602, latitude: 48.370)
    )
    private let westport = TideStation(
        id: "9441100", name: "Westport",
        coordinate: LonLat(longitude: -124.105, latitude: 46.904)
    )

    @Test func nearestStationPicksClosest() {
        let stations = [seattle, neah, westport]
        let shilshole = LonLat(longitude: -122.403, latitude: 47.681)
        #expect(TideStation.nearest(to: shilshole, in: stations)?.id == "9447130")
        let laPush = LonLat(longitude: -124.635, latitude: 47.904)
        #expect(TideStation.nearest(to: laPush, in: stations)?.id == "9443090")
    }

    @Test func nearestStationNilWhenEmpty() {
        #expect(TideStation.nearest(to: LonLat(longitude: -122.3, latitude: 47.6), in: []) == nil)
    }

    @Test func decodeHiloPredictions() throws {
        let json = """
        { "predictions" : [
        {"t":"2026-08-31 01:34", "v":"1.754", "type":"L"},
        {"t":"2026-08-31 07:36", "v":"9.985", "type":"H"},
        {"t":"2026-08-31 13:30", "v":"2.841", "type":"L"},
        {"t":"2026-08-31 19:41", "v":"11.477", "type":"H"}
        ]}
        """.data(using: .utf8)!
        let table = try NOAATideLoader.decodePredictions(
            json, station: seattle, calendar: Self.pacific
        )
        #expect(table.extremes.count == 4)
        #expect(table.extremes[0].kind == .low)
        #expect(table.extremes[1].kind == .high)
        #expect(abs(table.extremes[1].heightFeet - 9.985) < 0.001)
        #expect(table.extremes[0].time == date(2026, 8, 31, 1, 34))
        #expect(table.station.id == "9447130")
    }

    @Test func decodeNOAAErrorJSON() {
        let json = """
        {"error": {"message":" The station is not a valid station or there is system error."}}
        """.data(using: .utf8)!
        #expect(throws: NOAATideError.self) {
            try NOAATideLoader.decodePredictions(json, station: seattle, calendar: Self.pacific)
        }
    }

    @Test func nextExtremeAfterPlanTime() throws {
        let json = """
        { "predictions" : [
        {"t":"2026-08-31 01:34", "v":"1.754", "type":"L"},
        {"t":"2026-08-31 07:36", "v":"9.985", "type":"H"},
        {"t":"2026-08-31 13:30", "v":"2.841", "type":"L"},
        {"t":"2026-08-31 19:41", "v":"11.477", "type":"H"}
        ]}
        """.data(using: .utf8)!
        let table = try NOAATideLoader.decodePredictions(
            json, station: seattle, calendar: Self.pacific
        )
        #expect(table.indexOfNext(after: date(2026, 8, 31, 12, 1)) == 2)
        #expect(table.indexOfNext(after: date(2026, 8, 31, 0, 0)) == 0)
        #expect(table.indexOfNext(after: date(2026, 8, 31, 22, 0)) == nil)
    }

    @Test func predictionsURLCarriesHiloAndAppName() {
        let url = NOAATideLoader.predictionsURL(
            stationID: "9447130", day: date(2026, 8, 31, 12, 0), calendar: Self.pacific
        )
        let s = url.absoluteString
        #expect(s.contains("station=9447130"))
        #expect(s.contains("interval=hilo"))
        #expect(s.contains("product=predictions"))
        #expect(s.contains("begin_date=20260831"))
        #expect(s.contains("end_date=20260831"))
        #expect(s.contains("application=WAFishMap"))
        #expect(s.contains("units=english"))
        #expect(s.contains("datum=MLLW"))
    }

    @Test func fetchUsesClientThenDecodes() async throws {
        let json = """
        { "predictions" : [
        {"t":"2026-08-31 07:36", "v":"9.985", "type":"H"}
        ]}
        """.data(using: .utf8)!
        struct Stub: HTTPGet {
            let payload: Data
            func data(from url: URL) async throws -> Data {
                #expect(url.absoluteString.contains("9447130"))
                return payload
            }
        }
        let table = try await NOAATideLoader.fetch(
            station: seattle, day: date(2026, 8, 31, 12, 0),
            client: Stub(payload: json), calendar: Self.pacific
        )
        #expect(table.extremes.count == 1)
        #expect(table.extremes[0].kind == .high)
    }

    @Test func shippedCatalogIncludesSeattleAndColumbiaMouth() throws {
        let bundle = try #require(FixtureBundle.loader)
        let stations = try NOAATideLoader.loadStations(from: bundle)
        #expect(stations.count >= 160)
        #expect(stations.contains { $0.id == "9447130" })
        #expect(stations.contains { $0.id == "9439040" })
        let bostonHarbor = LonLat(longitude: -122.9055, latitude: 47.1397)
        let nearest = try #require(TideStation.nearest(to: bostonHarbor, in: stations))
        #expect(nearest.id == "9446800") // Dofflemeyer Point, Boston Hbr.
    }
}
