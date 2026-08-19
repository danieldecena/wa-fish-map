import Foundation
import Testing
@testable import WAFishMap

struct FishingMapModelTests {
    @Test @MainActor func loadFromBundleKeepsBostonHarborAndArea13() async throws {
        let model = FishingMapModel()
        let bundle = try #require(FixtureBundle.loader)
        try model.loadFromBundle(bundle: bundle)
        #expect(model.marineAreas.map(\.areaName) == ["13"])
        #expect(Set(model.accessSites.map(\.facilityName)) == ["Boston Harbor", "Luhr's Landing"])
        #expect(model.statusMessage == "Thurston County · Marine Area 13")
    }

    struct StubClient: HTTPGet {
        var marineData: Data
        var siteData: Data
        func data(from url: URL) async throws -> Data {
            if url.absoluteString.contains("/6/query") { return marineData }
            return siteData
        }
    }

    @Test @MainActor func liveFetchUsesClientThenFiltersToScope() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let marineURL = try #require(bundle.url(forResource: "marine-areas.sample", withExtension: "geojson"))
        let sitesURL = try #require(bundle.url(forResource: "access-sites.sample", withExtension: "geojson"))
        let model = FishingMapModel()
        await model.load(
            client: StubClient(
                marineData: try Data(contentsOf: marineURL),
                siteData: try Data(contentsOf: sitesURL)
            ),
            bundle: bundle
        )
        #expect(model.marineAreas.count == 1)
        #expect(model.accessSites.count == 2)
        #expect(model.statusMessage == "Thurston County · Marine Area 13")
    }

    @Test @MainActor func liveFetchFallsBackToBundleOnFailure() async throws {
        struct Boom: HTTPGet {
            func data(from url: URL) async throws -> Data { throw WDFWLayerError.badHTTPStatus(500) }
        }
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: Boom(), bundle: bundle)
        #expect(model.accessSites.map(\.facilityName).contains("Boston Harbor"))
        #expect(model.statusMessage.contains("offline"))
    }
}

/// Resolves GeoJSON fixtures when tests run outside a full app bundle (e.g. CI without xcodebuild).
enum FixtureBundle {
    static var loader: Bundle? {
        let candidates = [
            Bundle(for: BundleMarker.self),
            Bundle.main,
        ]
        for bundle in candidates {
            if bundle.url(forResource: "marine-areas.sample", withExtension: "geojson") != nil {
                return bundle
            }
        }
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resources = repoRoot.appendingPathComponent("WAFishMap/Resources", isDirectory: true)
        guard FileManager.default.fileExists(atPath: resources.path) else { return nil }
        return Bundle(path: resources.path) ?? Bundle(path: repoRoot.path)
    }
}

private final class BundleMarker: NSObject {}
