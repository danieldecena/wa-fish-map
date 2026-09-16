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

    /// One gauge, two rivers with its name: only the run the gauge sits on is
    /// coloured, and colours are keyed by feature id, not name.
    @Test @MainActor func aSplitRiverColoursOnlyTheRunItsGaugeSitsOn() {
        let model = FishingMapModel()
        let line = [[LonLat(longitude: -122.3, latitude: 47.4), LonLat(longitude: -122.2, latitude: 47.4)]]
        let gauged = River(name: "Green River", streamOrder: 5, lengthKm: 90, lines: line,
                           id: "Green River@-122.300,47.400", gauged: true)
        let other = River(name: "Green River", streamOrder: 4, lengthKm: 40, lines: line,
                          id: "Green River@-122.600,46.400")
        model.rivers = [gauged, other]
        model.riverStats = ["Green River": RiverFlowStats(
            gauge: "12113000", gaugeName: "GREEN RIVER NEAR AUBURN, WA", hasTemp: false,
            beginYear: 1937, endYear: 2026, percentiles: ["p10", "p25", "p50", "p75", "p90"],
            months: ["9": [[1000, 2000, 3000, 4000, 5000]]])]
        model.riverFlows = ["12113000": RiverFlow(gauge: "12113000", gaugeName: "GREEN RIVER NEAR AUBURN, WA",
                                                  discharge: 3000, dischargeAt: nil,
                                                  waterTempC: nil, waterTempAt: nil)]
        let ratings = model.riverRatings(month: 9, day: 1)
        #expect(Set(ratings.keys) == [gauged.id])
        #expect(model.stats(for: other) == nil)
        #expect(model.flow(for: other) == nil)
        #expect(model.flow(for: gauged)?.discharge == 3000)
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

    @Test @MainActor func theShoreSnapLeavesARiverMouthRampOnItsRiver() throws {
        let model = FishingMapModel()
        // A marine area whose east edge is at -122.50, and a river ending at it.
        model.marineAreas = [MarineArea(areaName: "13", areaTitle: "13", wac: "", coordinates: [
            LonLat(longitude: -122.6, latitude: 47.3), LonLat(longitude: -122.5, latitude: 47.3),
            LonLat(longitude: -122.5, latitude: 47.4), LonLat(longitude: -122.6, latitude: 47.4),
        ])]
        model.rivers = [River(name: "Mouth River", streamOrder: 4, lengthKm: 5,
                              lines: [[LonLat(longitude: -122.50, latitude: 47.35),
                                       LonLat(longitude: -122.45, latitude: 47.35)]])]
        let row = SpeciesSeason(species: "Cutthroat Trout", bestMonths: [9], note: "river row")
        model.guide = FisheryGuide(updated: "t", disclaimer: "d", wdfwURL: "https://wdfw.wa.gov",
                                   areas: [], freshwater: FreshwaterGuide(species: [], byWaterbody: ["Mouth River": [row]]),
                                   seasonRisk: [])
        // Both 30 m east of the polygon; only the first sits on the river.
        let riverMouth = AccessSite(facilityName: "Mouth Ramp", countyName: "Mason", hasLaunch: true,
                                    launchSurface: .gravel, hasRestrooms: false, directions: "",
                                    coordinate: LonLat(longitude: -122.4996, latitude: 47.35))
        let saltShore = AccessSite(facilityName: "Salt Ramp", countyName: "Mason", hasLaunch: true,
                                   launchSurface: .gravel, hasRestrooms: false, directions: "",
                                   coordinate: LonLat(longitude: -122.4996, latitude: 47.31))
        model.accessSites = [riverMouth, saltShore]
        model.indexSitesToAreas()
        model.indexWaterbodies()
        #expect(model.areaName(for: riverMouth) == nil)
        #expect(model.fishery(for: riverMouth)?.species.first?.note == "river row")
        #expect(model.areaName(for: saltShore) == "13")
    }

    @Test @MainActor func aLakeLaunchIsIndexedToItsLake() {
        let model = FishingMapModel()
        model.lakes = [LakeTests.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)]
        let site = AccessSite(facilityName: "Lake Dolloff", countyName: "King", hasLaunch: true,
                              launchSurface: .concrete, hasRestrooms: false, directions: "",
                              coordinate: LonLat(longitude: -122.284561, latitude: 47.323529))
        model.accessSites = [site]
        model.indexWaterbodies()
        #expect(model.lake(for: site)?.name == "Lake Dolloff")
    }

    /// Pin and sheet read the same `fishery(for:)`, so a trout-only lake drops
    /// bass from both the colour and the list.
    @Test @MainActor func aLakeLaunchIsRatedOnlyOnSpeciesItsLakeLists() throws {
        let model = FishingMapModel()
        let trout = SpeciesSeason(species: "Rainbow Trout", bestMonths: [4], goodMonths: [9])
        let bass = SpeciesSeason(species: "Largemouth Bass", bestMonths: [9])
        model.guide = FisheryGuide(updated: "t", disclaimer: "d", wdfwURL: "https://wdfw.wa.gov",
                                   areas: [], freshwater: FreshwaterGuide(species: [trout, bass]),
                                   seasonRisk: [])
        let dolloff = LakeTests.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)
        model.lakes = [Lake(name: dolloff.name, county: "King", longitude: dolloff.longitude,
                            latitude: dolloff.latitude, acres: 21.0, elevationFeet: nil, management: nil,
                            shorelineAccess: nil, boatRamp: nil, websiteURL: nil, species: ["Rainbow Trout"])]
        let onLake = AccessSite(facilityName: "Lake Dolloff", countyName: "King", hasLaunch: true,
                                launchSurface: .concrete, hasRestrooms: false, directions: "",
                                coordinate: LonLat(longitude: -122.284561, latitude: 47.323529))
        let offLake = AccessSite(facilityName: "Dry Ramp", countyName: "King", hasLaunch: true,
                                 launchSurface: .concrete, hasRestrooms: false, directions: "",
                                 coordinate: LonLat(longitude: -122.0, latitude: 47.0))
        model.accessSites = [onLake, offLake]
        model.indexWaterbodies()
        try #require(model.lake(for: onLake) != nil)
        #expect(model.fishery(for: onLake)?.species.map(\.species) == ["Rainbow Trout"])
        #expect(model.rating(for: onLake, month: 9) == .good)
        #expect(model.rating(for: onLake, month: 9, species: "Largemouth Bass") == nil)
        #expect(model.fishery(for: offLake)?.species.map(\.species) == ["Rainbow Trout", "Largemouth Bass"])
        #expect(model.rating(for: offLake, month: 9) == .excellent)
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

/// A failed or empty live read must render as unavailable, never as a value:
/// "0 access sites", "clear of every MPA", or a silent missing layer.
struct FailedReadTests {
    struct LayerClient: HTTPGet {
        var marine: Data?
        var sites: Data?
        var mpa: Data?
        var piers: Data?
        func data(from url: URL) async throws -> Data {
            let s = url.absoluteString
            let body: Data? = s.contains("/6/query") ? marine : s.contains("/0/query") ? sites
                : s.contains("/4/query") ? mpa : s.contains("/1/query") ? piers : nil
            guard let body else { throw WDFWLayerError.badHTTPStatus(500) }
            return body
        }
    }

    static let empty = Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
    static let oneArea = Data("""
    {"type":"FeatureCollection","features":[{"type":"Feature",
    "geometry":{"type":"Polygon","coordinates":[[[-123.0,47.0],[-122.9,47.0],[-122.9,47.1],[-123.0,47.1],[-123.0,47.0]]]},
    "properties":{"AreaName":"13","AreaTitle":"South Puget Sound","WAC":"x"}}]}
    """.utf8)
    static let oneSite = Data("""
    {"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[-122.00,47.65]},
     "properties":{"FacilityName":"Elsewhere","CountyName":"King","Launch":1,"Directions":""}}]}
    """.utf8)
    static let oneMPA = Data("""
    {"type":"FeatureCollection","features":[{"type":"Feature",
    "geometry":{"type":"Polygon","coordinates":[[[-122.40,47.60],[-122.30,47.60],[-122.30,47.70],[-122.40,47.70],[-122.40,47.60]]]},
    "properties":{"MPA_Name":"Golden Gardens","TypeOfMPA":"Marine Preserve","WAC":"w","DetailedInfoURL":"https://wdfw.wa.gov"}}]}
    """.utf8)
    static let onePier = Data("""
    {"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[-122.35,47.65]},
     "properties":{"GeoWeb.dbo.Fish_MapsPiers_V.PierName":"Test Pier","GeoWeb.dbo.Fish_MapsPiers_V.CountyFIPSName":"King"}}]}
    """.utf8)

    @Test @MainActor func anEmptyAccessSiteLayerNeverReadsAsZeroLiveSites() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: LayerClient(marine: Self.oneArea, sites: Self.empty), bundle: bundle)
        #expect(!model.statusMessage.contains("0 access sites"))
        #expect(model.statusMessage.contains("offline"))
    }

    /// The known-good half: the same client with a real site layer stays live.
    @Test @MainActor func aNonEmptyLayerStaysLive() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: LayerClient(marine: Self.oneArea, sites: Self.oneSite, mpa: Self.oneMPA, piers: Self.onePier),
                         bundle: bundle)
        #expect(model.statusMessage.contains("1 access sites · live"))
        #expect(model.piersLoaded)
        #expect(!model.statusMessage.contains("piers unavailable"))
        #expect(model.protectedAreasLoaded)
    }

    @Test @MainActor func anEmptyMPALayerIsUnavailableNotClear() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: LayerClient(marine: Self.oneArea, sites: Self.oneSite, mpa: Self.empty), bundle: bundle)
        let site = try #require(model.accessSites.first)
        #expect(!model.protectedAreasLoaded)
        #expect(model.protectedAreaCheck(for: site) == .unavailable)
    }

    @Test @MainActor func aFailedPierFetchIsSaidOutLoud() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: LayerClient(marine: Self.oneArea, sites: Self.oneSite, mpa: Self.oneMPA, piers: nil),
                         bundle: bundle)
        #expect(!model.piersLoaded)
        #expect(model.statusMessage.contains("piers unavailable"))
    }

    /// A 200 with no usable series is as empty as a failed fetch; it must not
    /// read as "loaded" and blame every gauge.
    @Test @MainActor func anEmptyUSGSResponseIsNotLoaded() async throws {
        struct EmptyUSGS: HTTPGet {
            let base: LayerClient
            func data(from url: URL) async throws -> Data {
                if url.host?.contains("usgs") == true {
                    return Data(#"{"value":{"timeSeries":[]}}"#.utf8)
                }
                return try await base.data(from: url)
            }
        }
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: EmptyUSGS(base: LayerClient(marine: Self.oneArea, sites: Self.oneSite,
                                                              mpa: Self.oneMPA, piers: Self.onePier)),
                         bundle: bundle)
        #expect(!model.riverFlowsLoaded)
    }

    @Test @MainActor func aFailedUSGSFetchIsRecordedAsNotLoaded() async throws {
        let bundle = try #require(FixtureBundle.loader)
        let model = FishingMapModel()
        await model.load(client: LayerClient(marine: Self.oneArea, sites: Self.oneSite, mpa: Self.oneMPA, piers: Self.onePier),
                         bundle: bundle)
        #expect(!model.riverFlowsLoaded, "LayerClient throws for the USGS URL")
    }
}
