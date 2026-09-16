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
        #expect(model.statusMessage == "Washington · offline sample")
    }

    /// Guards the model layer's half of the odd-year fix: `loadFromBundle` alone
    /// must not resolve Pink Salmon's parity (that would mean the Services layer
    /// read the clock) — only `setPlanYear`, called explicitly here, does.
    @Test @MainActor func loadFromBundleGuideRatesPinkSalmonByExplicitPlanYear() async throws {
        let model = FishingMapModel()
        let bundle = try #require(FixtureBundle.loader)
        try model.loadFromBundle(bundle: bundle)
        model.setPlanYear(2026)
        #expect(model.guide?.area(named: "7")?.rating(inMonth: 8, species: "Pink Salmon") == .poor)
        model.setPlanYear(2025)
        #expect(model.guide?.area(named: "7")?.rating(inMonth: 8, species: "Pink Salmon") == .excellent)
    }

    // `load` publishes the guide before its network awaits finish, so a year set
    // only after `load` returns would leave pins rendering the unstamped guide.
    @Test @MainActor func planYearSetBeforeLoadStampsTheGuideOnArrival() async throws {
        let model = FishingMapModel()
        let bundle = try #require(FixtureBundle.loader)
        model.setPlanYear(2026)
        try model.loadFromBundle(bundle: bundle)
        #expect(model.guide?.area(named: "7")?.rating(inMonth: 8, species: "Pink Salmon") == .poor)
    }

    @Test @MainActor func launchesAreMappedToTheirMarineAreaByPolygon() async throws {
        let model = FishingMapModel()
        let bundle = try #require(FixtureBundle.loader)
        try model.loadFromBundle(bundle: bundle)
        let boston = try #require(model.accessSites.first { $0.facilityName == "Boston Harbor" })
        // Boston Harbor sits inside the Area 13 polygon → mapped + rated.
        #expect(model.areaName(for: boston) == "13")
        #expect(model.rating(for: boston, month: 8) != nil)

        // A launch far outside every marine area is inland → rated via freshwater
        // guidance (by county), not neutral.
        let inland = AccessSite(
            facilityName: "Somewhere Inland", countyName: "Spokane", hasLaunch: true,
            launchSurface: .gravel, hasRestrooms: false, directions: "",
            coordinate: LonLat(longitude: -117.4, latitude: 47.66)
        )
        #expect(model.areaName(for: inland) == nil)
        #expect(!model.isMarine(inland))
        #expect(model.rating(for: inland, month: 8) != nil)
    }

    @Test @MainActor func anInlandLaunchBesideARiverGetsTheRiversRows() throws {
        let model = FishingMapModel()
        let river = River(name: "Test River", streamOrder: 4, lengthKm: 1,
                          lines: [[LonLat(longitude: -117.40, latitude: 47.66),
                                   LonLat(longitude: -117.39, latitude: 47.66)]])
        let row = SpeciesSeason(species: "Redband Trout", bestMonths: [8], note: "river row")
        model.guide = FisheryGuide(updated: "t", disclaimer: "d", wdfwURL: "https://wdfw.wa.gov",
                                   areas: [], freshwater: FreshwaterGuide(species: [], byWaterbody: ["Test River": [row]]),
                                   seasonRisk: [])
        model.rivers = [river]
        let onRiver = AccessSite(facilityName: "River Ramp", countyName: "Spokane", hasLaunch: true,
                                 launchSurface: .gravel, hasRestrooms: false, directions: "",
                                 coordinate: LonLat(longitude: -117.395, latitude: 47.6605))
        let offRiver = AccessSite(facilityName: "Dry Ramp", countyName: "Spokane", hasLaunch: true,
                                  launchSurface: .gravel, hasRestrooms: false, directions: "",
                                  coordinate: LonLat(longitude: -117.395, latitude: 47.67))
        model.accessSites = [onRiver, offRiver]
        model.indexWaterbodies()
        #expect(model.siteWaterbody[onRiver.id] == "Test River")
        #expect(model.siteWaterbody[offRiver.id] == nil)
        #expect(model.fishery(for: onRiver)?.species.first?.note == "river row")
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
        #expect(model.statusMessage.contains("live"))
        #expect(model.statusMessage.contains("2 access sites"))
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

    @Test func truncatedResponseIsRejectedNotPartiallyDecoded() throws {
        // ArcGIS marks a limit-hit response instead of erroring; a partial layer must
        // not decode as if it were complete. Flag appears top-level and under
        // `properties` depending on server version — both must trip the guard.
        let topLevel = Data("""
        {"type":"FeatureCollection","exceededTransferLimit":true,"features":[]}
        """.utf8)
        let nested = Data("""
        {"type":"FeatureCollection","properties":{"exceededTransferLimit":true},"features":[]}
        """.utf8)
        for data in [topLevel, nested] {
            #expect(throws: WDFWLayerError.truncatedResponse) {
                try WDFWLayerLoader.accessSites(from: data)
            }
        }
        // A complete response (no flag) still decodes.
        let complete = Data("""
        {"type":"FeatureCollection","features":[]}
        """.utf8)
        #expect(try WDFWLayerLoader.accessSites(from: complete).isEmpty)
    }

    @Test @MainActor func totalLoadFailureSurfacesInsteadOfStrandingLoading() async throws {
        struct Boom: HTTPGet {
            func data(from url: URL) async throws -> Data { throw WDFWLayerError.badHTTPStatus(500) }
        }
        // A resource-less bundle has no fixtures either — both paths fail.
        let empty = try #require(Bundle(path: NSTemporaryDirectory()))
        let model = FishingMapModel()
        await model.load(client: Boom(), bundle: empty)
        #expect(model.statusMessage != "Loading…")
        #expect(model.statusMessage.contains("Couldn't load"))
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
