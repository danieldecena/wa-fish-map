import Foundation
import Testing
@testable import WAFishMap

@Suite("Marine Protected Areas")
struct ProtectedAreaTests {
    /// A unit square around Golden Gardens.
    private static let square = [
        LonLat(longitude: -122.40, latitude: 47.60),
        LonLat(longitude: -122.30, latitude: 47.60),
        LonLat(longitude: -122.30, latitude: 47.70),
        LonLat(longitude: -122.40, latitude: 47.70),
    ]

    private static func mpa(polygon: [LonLat] = square) -> ProtectedArea {
        ProtectedArea(name: "Golden Gardens", type: "Marine Preserve",
                      wac: "WAC 220-302-060", detailURL: nil, polygon: polygon)
    }

    @Test func aPointInsideAProtectedAreaIsFlagged() {
        let mpa = Self.mpa()
        #expect(mpa.contains(LonLat(longitude: -122.35, latitude: 47.65)))
        #expect(!mpa.contains(LonLat(longitude: -122.00, latitude: 47.65)))
    }

    @Test func aBareCitationIsRenderedAsAWAC() {
        // Live layer 4 stores "220-330-180"; already-prefixed values pass through.
        #expect(ProtectedArea(name: "x", type: "t", wac: "220-330-180",
                              detailURL: nil, polygon: Self.square).wacCitation == "WAC 220-330-180")
        #expect(ProtectedArea(name: "x", type: "t", wac: "WAC 220-302-060",
                              detailURL: nil, polygon: Self.square).wacCitation == "WAC 220-302-060")
        #expect(ProtectedArea(name: "x", type: "t", wac: "",
                              detailURL: nil, polygon: Self.square).wacCitation.isEmpty)
    }

    @Test func idIsTheName() {
        #expect(Self.mpa().id == "Golden Gardens")
    }

    @Test func aDegeneratePolygonContainsNothing() {
        let sliver = Self.mpa(polygon: Array(Self.square.prefix(2)))
        #expect(!sliver.contains(LonLat(longitude: -122.35, latitude: 47.65)))
    }

    @Test func decodesLayer4GeoJSON() throws {
        let json = """
        {"type":"FeatureCollection","features":[{"type":"Feature",
        "geometry":{"type":"Polygon","coordinates":[[[-122.40,47.60],[-122.30,47.60],
        [-122.30,47.70],[-122.40,47.70],[-122.40,47.60]]]},
        "properties":{"MPA_Name":"Golden Gardens","TypeOfMPA":"Marine Preserve",
        "WAC":"WAC 220-302-060","DetailedInfoURL":"https://wdfw.wa.gov/mpa"}}]}
        """
        let areas = try WDFWLayerLoader.protectedAreas(from: Data(json.utf8))
        #expect(areas.count == 1)
        let mpa = try #require(areas.first)
        #expect(mpa.name == "Golden Gardens")
        #expect(mpa.type == "Marine Preserve")
        #expect(mpa.wac == "WAC 220-302-060")
        #expect(mpa.detailURL?.absoluteString == "https://wdfw.wa.gov/mpa")
        // The closing vertex is dropped, as for marine areas.
        #expect(mpa.polygon.count == 4)
        #expect(mpa.contains(LonLat(longitude: -122.35, latitude: 47.65)))
    }

    @Test func aTruncatedLayerIsRejectedRatherThanShownAsComplete() {
        let json = #"{"type":"FeatureCollection","exceededTransferLimit":true,"features":[]}"#
        #expect(throws: WDFWLayerError.truncatedResponse) {
            try WDFWLayerLoader.protectedAreas(from: Data(json.utf8))
        }
    }

    @Test func theLayer4QueryAsksForTheMPAFields() {
        let url = MapScope.protectedAreasURL.absoluteString
        #expect(url.contains("/MapServer/4/query"))
        #expect(url.contains("MPA_Name"))
        #expect(url.contains("TypeOfMPA"))
        #expect(url.contains("DetailedInfoURL"))
    }

    /// End-to-end through `load`: a stub server serves layer 4 alongside the
    /// layers the app already fetches, and a site inside the polygon resolves.
    struct StubClient: HTTPGet {
        var marineData: Data
        var siteData: Data
        var mpaData: Data
        func data(from url: URL) async throws -> Data {
            if url.absoluteString.contains("/6/query") { return marineData }
            if url.absoluteString.contains("/4/query") { return mpaData }
            if url.absoluteString.contains("/0/query") { return siteData }
            throw WDFWLayerError.badHTTPStatus(404)
        }
    }

    @Test @MainActor func aSiteInsideAnMPAResolvesToIt() async throws {
        let sites = """
        {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"Point","coordinates":[-122.35,47.65]},
         "properties":{"FacilityName":"Golden Gardens Ramp","CountyName":"King","Launch":1,"Directions":""}},
        {"type":"Feature","geometry":{"type":"Point","coordinates":[-122.00,47.65]},
         "properties":{"FacilityName":"Elsewhere","CountyName":"King","Launch":1,"Directions":""}}]}
        """
        let mpas = """
        {"type":"FeatureCollection","features":[{"type":"Feature",
        "geometry":{"type":"Polygon","coordinates":[[[-122.40,47.60],[-122.30,47.60],
        [-122.30,47.70],[-122.40,47.70],[-122.40,47.60]]]},
        "properties":{"MPA_Name":"Golden Gardens","TypeOfMPA":"Marine Preserve",
        "WAC":"WAC 220-302-060","DetailedInfoURL":"https://wdfw.wa.gov/mpa"}}]}
        """
        let empty = #"{"type":"FeatureCollection","features":[]}"#
        let model = FishingMapModel()
        await model.load(
            client: StubClient(marineData: Data(empty.utf8),
                               siteData: Data(sites.utf8),
                               mpaData: Data(mpas.utf8)),
            bundle: .main
        )
        #expect(model.protectedAreas.count == 1)
        let inside = try #require(model.accessSites.first { $0.facilityName == "Golden Gardens Ramp" })
        let outside = try #require(model.accessSites.first { $0.facilityName == "Elsewhere" })
        #expect(model.protectedArea(for: inside)?.name == "Golden Gardens")
        #expect(model.protectedArea(for: inside)?.wac == "WAC 220-302-060")
        #expect(model.protectedArea(for: outside) == nil)
    }
}
