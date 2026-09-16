import Foundation
import Testing
@testable import WAFishMap

/// The fixture is four real rows from station 46088 (New Dungeness), fetched
/// 2026-09-02. It was chosen because the newest row already disagrees with the
/// obvious implementation: it carries a wave height and `MM` for water
/// temperature, with the real temperature one row older. A parser that reads
/// "the latest row" drops the temperature; one that reads MM as a number reports
/// 0 °C water.
@Suite("NDBC buoy readings")
struct NDBCLoaderTests {
    private static let sample = """
    #YY  MM DD hh mm WDIR WSPD GST  WVHT   DPD   APD MWD   PRES  ATMP  WTMP  DEWP  VIS PTDY  TIDE
    #yr  mo dy hr mn degT m/s  m/s     m   sec   sec degT   hPa  degC  degC  degC  nmi  hPa    ft
    2026 09 02 05 50 120  2.0  3.0   0.1    MM   3.3  MM 1008.3  12.5    MM  11.5   MM   MM    MM
    2026 09 02 05 40 140  3.0  3.0   0.1    MM   3.3  MM 1008.5  12.4  11.1  11.4   MM   MM    MM
    2026 09 02 05 30 130  3.0  3.0    MM    MM    MM  MM 1008.5  12.5  11.1  11.5   MM   MM    MM
    2026 09 02 05 20 130  3.0  3.0   0.1    MM   3.5  MM 1008.5  12.3    MM  11.6   MM   MM    MM
    """

    private func parse(_ text: String = sample) throws -> BuoyObservation {
        try NDBCLoader.decodeLatest(Data(text.utf8), stationID: "46088")
    }

    @Test func eachFieldTakesTheNewestRowThatActuallyReportsIt() throws {
        let o = try parse()

        #expect(o.waveHeightMeters?.value == 0.1)
        #expect(o.waterTempCelsius?.value == 11.1)

        // 05:50 UTC for the wave height, 05:40 for the temperature — the point of
        // giving each reading its own timestamp.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let waveMinute = utc.component(.minute, from: try #require(o.waveHeightMeters).observed)
        let tempMinute = utc.component(.minute, from: try #require(o.waterTempCelsius).observed)
        #expect(waveMinute == 50)
        #expect(tempMinute == 40)
    }

    /// `MM` is the buoy declining to answer. Reading it as 0 would report flat
    /// calm water at freezing — a claim, where the feed made none.
    @Test func aStationReportingNothingIsEmptyRatherThanZero() throws {
        let allMissing = """
        #YY  MM DD hh mm WDIR WSPD GST  WVHT   DPD   APD MWD   PRES  ATMP  WTMP  DEWP  VIS PTDY  TIDE
        #yr  mo dy hr mn degT m/s  m/s     m   sec   sec degT   hPa  degC  degC  degC  nmi  hPa    ft
        2026 09 02 05 50 120  2.0  3.0    MM    MM   3.3  MM 1008.3  12.5    MM  11.5   MM   MM    MM
        """
        let o = try parse(allMissing)

        #expect(o.waveHeightMeters == nil)
        #expect(o.waterTempCelsius == nil)
        #expect(o.isEmpty)
    }

    /// The known-good half of the check above: a station that does report must
    /// not read as empty, or `isEmpty` could be stuck true and both tests pass.
    @Test func aReportingStationIsNotEmpty() throws {
        #expect(try !parse().isEmpty)
    }

    /// Columns are addressed by header name, not position. A feed with an extra
    /// column inserted before WVHT must still read the right number.
    @Test func anInsertedColumnDoesNotShiftTheReading() throws {
        let shifted = """
        #YY  MM DD hh mm WDIR WSPD GST NEWCOL  WVHT   DPD   APD MWD   PRES  ATMP  WTMP  DEWP  VIS PTDY  TIDE
        #yr  mo dy hr mn degT m/s  m/s      x     m   sec   sec degT   hPa  degC  degC  degC  nmi  hPa    ft
        2026 09 02 05 50 120  2.0  3.0    9.9   0.1    MM   3.3  MM 1008.3  12.5  11.1  11.5   MM   MM    MM
        """
        let o = try parse(shifted)

        #expect(o.waveHeightMeters?.value == 0.1, "A positional parser would have read 9.9 here.")
        #expect(o.waterTempCelsius?.value == 11.1)
    }

    @Test func aFeedWithNoHeaderIsRejectedRatherThanGuessed() {
        #expect(throws: NDBCError.malformedHeader) {
            try parse("2026 09 02 05 50 120  2.0  3.0   0.1")
        }
    }

    // MARK: Catalog

    @Test func theBundledCatalogLoadsAndCoversWashington() throws {
        let bundle = try #require(FixtureBundle.loader)
        let stations = try NDBCLoader.loadStations(from: bundle)

        #expect(stations.count > 20)
        #expect(stations.allSatisfy { (45.5...49.1).contains($0.lat) })
        #expect(stations.contains { $0.id == "46088" }, "New Dungeness should be in the catalog.")
    }

    @Test func theNearestBuoyToPortAngelesIsInTheStrait() throws {
        let bundle = try #require(FixtureBundle.loader)
        let stations = try NDBCLoader.loadStations(from: bundle)
        let portAngeles = LonLat(longitude: -123.43, latitude: 48.12)

        let nearest = try #require(NDBCLoader.nearest(to: portAngeles, in: stations))
        // Whichever buoy wins, it must be in the Strait, not off the coast.
        #expect(nearest.lon > -124.5)
        #expect(nearest.lat > 47.9)
    }

    @Test func theObservationURLIsTheRealtimeFeedForThatStation() {
        #expect(NDBCLoader.observationsURL(stationID: "46088").absoluteString
                == "https://www.ndbc.noaa.gov/data/realtime2/46088.txt")
    }
}
