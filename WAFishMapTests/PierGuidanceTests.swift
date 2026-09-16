import Foundation
import Testing
@testable import WAFishMap

/// Piers were the one marker kind that could answer a safety question with
/// silence: they were never checked against Marine Protected Areas at all, so a
/// pier inside an MPA rendered exactly like one clear of every MPA.
///
/// Driven through `load(client:)` rather than by poking the indexes directly,
/// because the ordering is the part that breaks: piers arrive after the MPA
/// layer, so an index built in the MPA block would always run against an empty
/// pier list and pass every assertion for the wrong reason.
@Suite("Pier guidance")
struct PierGuidanceTests {
    /// A square around Golden Gardens; the pier at `inside` sits within it.
    private static let mpaLayer = """
    {"type":"FeatureCollection","features":[
    {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[
      [-122.40,47.60],[-122.30,47.60],[-122.30,47.70],[-122.40,47.70],[-122.40,47.60]]]},
     "properties":{"MPA_Name":"Golden Gardens","TypeOfMPA":"Marine Preserve","WAC":"220-302-060"}}]}
    """

    private static let empty = #"{"type":"FeatureCollection","features":[]}"#

    private static func pierLayer(lon: Double, lat: Double) -> String {
        """
        {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"Point","coordinates":[\(lon),\(lat)]},
         "properties":{"GeoWeb.dbo.Fish_MapsPiers_V.PierName":"Test Pier",
                       "GeoWeb.dbo.Fish_MapsPiers_V.CountyFIPSName":"King",
                       "GeoWeb.dbo.Fish_MapsPiers_V.WebsiteURL":""}}]}
        """
    }

    struct StubClient: HTTPGet {
        var mpaData: Data
        var pierData: Data
        func data(from url: URL) async throws -> Data {
            let s = url.absoluteString
            if s.contains("/4/query") { return mpaData }
            if s.contains("/1/query") { return pierData }
            return Data(PierGuidanceTests.empty.utf8)
        }
    }

    private static func load(pierAt lon: Double, _ lat: Double,
                             mpa: String = mpaLayer) async -> FishingMapModel {
        let model = await FishingMapModel()
        await model.load(
            client: StubClient(mpaData: Data(mpa.utf8),
                               pierData: Data(pierLayer(lon: lon, lat: lat).utf8)),
            bundle: .main
        )
        return model
    }

    @Test @MainActor func aPierInsideAProtectedAreaIsFlagged() async throws {
        let model = await Self.load(pierAt: -122.35, 47.65)
        let pier = try #require(model.piers.first)

        guard case .inside(let mpa) = model.protectedAreaCheck(for: pier) else {
            Issue.record("A pier inside an MPA was not flagged.")
            return
        }
        #expect(mpa.name == "Golden Gardens")
    }

    /// The known-good input: a pier clear of every MPA must read `.clear`, or the
    /// assertion above cannot be told apart from a check that always flags.
    @Test @MainActor func aPierClearOfEveryProtectedAreaReadsClear() async throws {
        let model = await Self.load(pierAt: -122.00, 47.65)
        let pier = try #require(model.piers.first)

        #expect(model.protectedAreaCheck(for: pier) == .clear)
    }

    /// A check that never ran reads unknown, never clear — the same rule the
    /// launch sheet already follows.
    @Test @MainActor func aPierWhoseMPALayerFailedReadsUnavailable() async throws {
        struct FailingMPAClient: HTTPGet {
            var pierData: Data
            func data(from url: URL) async throws -> Data {
                if url.absoluteString.contains("/4/query") {
                    throw WDFWLayerError.badHTTPStatus(500)
                }
                if url.absoluteString.contains("/1/query") { return pierData }
                return Data(PierGuidanceTests.empty.utf8)
            }
        }
        let model = FishingMapModel()
        await model.load(
            client: FailingMPAClient(pierData: Data(Self.pierLayer(lon: -122.35, lat: 47.65).utf8)),
            bundle: .main
        )
        let pier = try #require(model.piers.first)

        #expect(!model.protectedAreasLoaded)
        #expect(model.protectedAreaCheck(for: pier) == .unavailable)
    }

    /// A pier outside every marine polygon still answers with the freshwater
    /// table rather than rendering neutral.
    @Test @MainActor func aPierOutsideEveryMarinePolygonResolvesFreshwaterGuidance() async throws {
        let model = await Self.load(pierAt: -122.00, 47.65)
        let pier = try #require(model.piers.first)

        #expect(!model.isMarine(pier))
        #expect(model.fishery(for: pier) != nil, "A freshwater pier must not render neutral.")
    }
}
