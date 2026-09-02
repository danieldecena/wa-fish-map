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

    private static func mpa(name: String, type: String, wac: String = "220-330-180") -> ProtectedArea {
        ProtectedArea(name: name, type: type, wac: wac, detailURL: nil, polygon: square)
    }

    private static let prohibition = "Fishing or shellfishing may be prohibited or limited here."

    /// The four prohibitive types keep the approved wording.
    @Test(arguments: ["Marine Preserve", "Conservation Area", "Octopus Preserve", "Urchin and Cucumber"])
    func prohibitiveTypesClaimARestriction(type: String) {
        #expect(Self.mpa(name: "Golden Gardens", type: type).restrictionSentence == Self.prohibition)
    }

    /// WDFW asks; it prohibits nothing. Claiming otherwise is the overreach the
    /// "Not this app" boundary forbids.
    @Test func aVoluntaryAreaClaimsNoProhibition() {
        let line = Self.mpa(name: "Sund Rock", type: "Voluntary").detailLine
        #expect(line.contains("voluntarily avoid"))
        #expect(!line.contains("prohibited"))
        #expect(!line.contains("limited"))
    }

    /// A biotoxin closure is a different authority for a different reason.
    @Test func aHealthClosureIsNotPresentedAsAFishingRule() {
        let line = Self.mpa(name: "Liberty Bay", type: "Health Closure").detailLine
        #expect(line.contains("public-health closure"))
        #expect(line.contains("not a fishing rule"))
        #expect(!line.contains("prohibited"))
    }

    /// WDFW adds types. A type this build has never seen must not inherit a
    /// prohibition claim by default.
    @Test(arguments: ["Kelp Reserve", "", "MARINE PRESERVE"])
    func anUnrecognisedTypeAssertsNoRule(type: String) {
        let line = Self.mpa(name: "Somewhere New", type: type).detailLine
        #expect(line.contains("Check WDFW for what applies here."))
        #expect(!line.contains("prohibited"))
        #expect(!line.contains("voluntarily"))
    }

    /// Finding 1: an empty WDFW WAC field must not ship "Marine Preserve — . Fishing…".
    @Test func anEmptyCitationDropsCleanlyFromTheSentence() {
        let line = Self.mpa(name: "Golden Gardens", type: "Marine Preserve", wac: "").detailLine
        #expect(line == "Marine Preserve. \(Self.prohibition)")
        #expect(!line.contains("— ."))
        #expect(!line.contains(" . "))
    }

    @Test func aCitationIsRenderedWhenPresent() {
        #expect(Self.mpa(name: "Golden Gardens", type: "Marine Preserve").detailLine
                == "Marine Preserve — WAC 220-330-180. \(Self.prohibition)")
    }

    /// Finding 2: "Marine Area 12" collides with the app's own marine-area concept,
    /// so the headline leads with the type and the name moves into the detail line.
    @Test func aGenericNameLeadsWithTheTypeInstead() {
        let generic = Self.mpa(name: "Marine Area 12", type: "Octopus Preserve")
        #expect(generic.hasGenericName)
        #expect(generic.headline == "Inside an Octopus Preserve")
        #expect(generic.detailLine.hasPrefix("Marine Area 12 — WAC"))
        #expect(Self.mpa(name: "Marine Area 12", type: "Urchin and Cucumber").headline
                == "Inside an Urchin and Cucumber")
        #expect(Self.mpa(name: "Marine Area 12", type: "Conservation Area").headline
                == "Inside a Conservation Area")
    }

    @Test func aPlaceNamedAreaKeepsItsOwnName() {
        let named = Self.mpa(name: "Golden Gardens", type: "Marine Preserve")
        #expect(!named.hasGenericName)
        #expect(named.headline == "Inside Golden Gardens")
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

    /// The silent-failure case: layer 4 is unreachable, so `protectedAreas` is
    /// empty for a reason the UI must not read as "checked, nothing here".
    struct FailingMPAClient: HTTPGet {
        var siteData: Data
        func data(from url: URL) async throws -> Data {
            if url.absoluteString.contains("/4/query") { throw WDFWLayerError.badHTTPStatus(500) }
            if url.absoluteString.contains("/0/query") { return siteData }
            return Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
        }
    }

    private static let oneSite = """
    {"type":"FeatureCollection","features":[
    {"type":"Feature","geometry":{"type":"Point","coordinates":[-122.00,47.65]},
     "properties":{"FacilityName":"Elsewhere","CountyName":"King","Launch":1,"Directions":""}}]}
    """

    @Test @MainActor func anMPAFetchFailureReportsUnavailableRatherThanClear() async throws {
        let model = FishingMapModel()
        await model.load(client: FailingMPAClient(siteData: Data(Self.oneSite.utf8)), bundle: .main)
        let site = try #require(model.accessSites.first)
        #expect(!model.protectedAreasLoaded)
        #expect(model.protectedAreaCheck(for: site) == .unavailable)
    }

    /// A truncated layer 4 is the same defect wearing a 200: the guard's throw was
    /// swallowed too, so a partial layer read as a complete one.
    struct TruncatedMPAClient: HTTPGet {
        var siteData: Data
        func data(from url: URL) async throws -> Data {
            if url.absoluteString.contains("/4/query") {
                return Data(#"{"type":"FeatureCollection","exceededTransferLimit":true,"features":[]}"#.utf8)
            }
            if url.absoluteString.contains("/0/query") { return siteData }
            return Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
        }
    }

    @Test @MainActor func aTruncatedMPALayerAlsoReportsUnavailable() async throws {
        let model = FishingMapModel()
        await model.load(client: TruncatedMPAClient(siteData: Data(Self.oneSite.utf8)), bundle: .main)
        let site = try #require(model.accessSites.first)
        #expect(model.protectedAreaCheck(for: site) == .unavailable)
    }

    /// The known-good half: a layer that loads and simply has nothing at this site
    /// is `clear`, not `unavailable`.
    @Test @MainActor func aLoadedLayerWithNoMatchIsClearNotUnavailable() async throws {
        let empty = #"{"type":"FeatureCollection","features":[]}"#
        let model = FishingMapModel()
        await model.load(
            client: StubClient(marineData: Data(empty.utf8),
                               siteData: Data(Self.oneSite.utf8),
                               mpaData: Data(empty.utf8)),
            bundle: .main
        )
        let site = try #require(model.accessSites.first)
        #expect(model.protectedAreasLoaded)
        #expect(model.protectedAreaCheck(for: site) == .clear)
    }
}
