import Foundation

@MainActor
@Observable
final class FishingMapModel {
    var marineAreas: [MarineArea] = []
    var accessSites: [AccessSite] = []
    var statusMessage = "Loading…"
    var selectedSiteID: AccessSite.ID?

    /// Curated seasonal guidance (bundled, offline). See `Fishery.swift`.
    var guide: FisheryGuide?

    var selectedSite: AccessSite? {
        accessSites.first { $0.id == selectedSiteID }
    }

    /// The single marine area this build is scoped to.
    var areaName: String { MapScope.marineAreaNames.sorted().first ?? "13" }

    /// Curated guidance for the scoped area, if loaded.
    var fishery: AreaFishery? { guide?.area(named: areaName) }

    enum Resource: String {
        case marineAreas = "marine-areas.sample"
        case accessSites = "access-sites.sample"
    }

    func loadFromBundle(bundle: Bundle) throws {
        marineAreas = MapScope.filter(
            marineAreas: try WDFWLayerLoader.marineAreas(from: Self.data(.marineAreas, in: bundle))
        )
        accessSites = MapScope.filter(
            accessSites: try WDFWLayerLoader.accessSites(from: Self.data(.accessSites, in: bundle))
        )
        loadGuide(bundle: bundle)
        statusMessage = "Thurston County · Marine Area 13"
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
        loadGuide(bundle: bundle)
        do {
            let marineData = try await client.data(from: MapScope.marineAreasURL)
            let siteData = try await client.data(from: MapScope.accessSitesURL)
            marineAreas = MapScope.filter(marineAreas: try WDFWLayerLoader.marineAreas(from: marineData))
            accessSites = MapScope.filter(accessSites: try WDFWLayerLoader.accessSites(from: siteData))
            statusMessage = "Thurston County · Marine Area 13"
        } catch {
            try? loadFromBundle(bundle: bundle)
            statusMessage = "Thurston County · Marine Area 13 (offline sample)"
        }
    }

    /// Loads the curated guide from the bundle. Absence is non-fatal — the map still
    /// works, ratings just fall back to neutral.
    private func loadGuide(bundle: Bundle) {
        guard guide == nil,
              let url = bundle.url(forResource: "fisheries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? FisheryLoader.guide(from: data) else { return }
        guide = loaded
    }

    private static func data(_ resource: Resource, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource.rawValue, withExtension: "geojson") else {
            throw WDFWLayerError.missingBundleResource(resource.rawValue)
        }
        return try Data(contentsOf: url)
    }
}
