import Foundation
import Testing
@testable import WAFishMap

struct FishingMapModelTests {
    @Test @MainActor func loadFromBundleKeepsBostonHarborAndArea13() async throws {
        let model = FishingMapModel()
        try model.loadFromBundle(bundle: .main)
        #expect(model.marineAreas.map(\.areaName) == ["13"])
        // The fixture has an interior ring; only the 4-vertex outer ring survives.
        #expect(model.marineAreas[0].coordinates.count == 4)
        #expect(Set(model.accessSites.map(\.facilityName)) == ["Boston Harbor", "Luhr's Landing"])
        #expect(model.statusMessage == MapScope.summary)
    }

    struct StubClient: HTTPGet {
        var marineData: Data
        var siteData: Data
        func data(from url: URL) async throws -> Data {
            if url.absoluteString.contains("/6/query") { return marineData }
            if url.absoluteString.contains("/0/query") { return siteData }
            // Do not silently serve the wrong fixture if a URL changes shape.
            throw WDFWLayerError.badHTTPStatus(404)
        }
    }

    @Test @MainActor func liveFetchUsesClientThenFiltersToScope() async throws {
        let marine = try #require(Bundle.main.url(forResource: "marine-areas.sample", withExtension: "geojson"))
        let sites = try #require(Bundle.main.url(forResource: "access-sites.sample", withExtension: "geojson"))
        let model = FishingMapModel()
        await model.load(
            client: StubClient(
                marineData: try Data(contentsOf: marine),
                siteData: try Data(contentsOf: sites)
            ),
            bundle: .main
        )
        #expect(model.marineAreas.count == 1)
        #expect(model.accessSites.count == 2)
        #expect(model.statusMessage == MapScope.summary)
    }

    @Test @MainActor func liveFetchFallsBackToBundleOnFailure() async throws {
        struct Boom: HTTPGet {
            func data(from url: URL) async throws -> Data { throw WDFWLayerError.badHTTPStatus(500) }
        }
        let model = FishingMapModel()
        await model.load(client: Boom(), bundle: .main)
        #expect(model.accessSites.map(\.facilityName).contains("Boston Harbor"))
        #expect(model.statusMessage.contains("sample"))
        #expect(model.statusMessage.contains("HTTP 500"))
    }

    /// ArcGIS answers a malformed `where=` with HTTP 200 and an error body, so a
    /// broken query must not be reported as "offline". Verified against the live
    /// service 2026-08-18: `where=BogusField IN ('13')` -> 200 + code 400.
    @Test @MainActor func brokenQueryIsNotReportedAsOffline() async throws {
        struct Rejecting: HTTPGet {
            func data(from url: URL) async throws -> Data {
                Data(#"{"error":{"code":400,"message":"Failed to execute query.","details":[]}}"#.utf8)
            }
        }
        let model = FishingMapModel()
        await model.load(client: Rejecting(), bundle: .main)
        #expect(model.statusMessage.contains("query rejected (400)"))
        #expect(!model.statusMessage.contains("offline"))
        #expect(model.accessSites.map(\.facilityName).contains("Boston Harbor"))
    }

    /// A valid `where=` with no matches returns 200 + an empty FeatureCollection,
    /// which decodes cleanly. Verified 2026-08-18 with `AreaName IN ('999')`.
    @Test @MainActor func emptyFeatureCollectionDoesNotRenderABlankMap() async throws {
        struct Empty: HTTPGet {
            func data(from url: URL) async throws -> Data {
                Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
            }
        }
        let model = FishingMapModel()
        await model.load(client: Empty(), bundle: .main)
        #expect(!model.accessSites.isEmpty)
        #expect(model.statusMessage.contains("no marine areas returned"))
    }

    /// The fallback can fail too. It must not still claim sample data is showing.
    @Test @MainActor func bothPathsFailingReportsUnloadable() async throws {
        struct Boom2: HTTPGet {
            func data(from url: URL) async throws -> Data { throw WDFWLayerError.badHTTPStatus(500) }
        }
        let model = FishingMapModel()
        // A real directory with no geojson in it, so loadFromBundle throws too.
        await model.load(client: Boom2(), bundle: try #require(Bundle(path: NSTemporaryDirectory())))
        #expect(model.accessSites.isEmpty)
        #expect(model.statusMessage == "Could not load WDFW data or the offline sample.")
    }
}
