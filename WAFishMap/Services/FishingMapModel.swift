import Foundation

@MainActor
@Observable
final class FishingMapModel {
    var marineAreas: [MarineArea] = []
    var accessSites: [AccessSite] = []
    var statusMessage = "Loading…"
    var selectedSiteID: AccessSite.ID?

    var selectedSite: AccessSite? {
        accessSites.first { $0.id == selectedSiteID }
    }

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
        statusMessage = "Thurston County · Marine Area 13"
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
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

    private static func data(_ resource: Resource, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource.rawValue, withExtension: "geojson") else {
            throw WDFWLayerError.missingBundleResource(resource.rawValue)
        }
        return try Data(contentsOf: url)
    }
}
