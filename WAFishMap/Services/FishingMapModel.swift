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
            marineAreas: try WDFWLayerLoader.marineAreas(from: Self.data(Resource.marineAreas, in: bundle))
        )
        accessSites = MapScope.filter(
            accessSites: try WDFWLayerLoader.accessSites(from: Self.data(Resource.accessSites, in: bundle))
        )
        statusMessage = MapScope.summary
    }

    private static func data(_ resource: Resource, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource.rawValue, withExtension: "geojson") else {
            throw WDFWLayerError.missingBundleResource(resource.rawValue)
        }
        return try Data(contentsOf: url)
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
        do {
            // Concurrent: the marine query is the slow one and neither depends on the other.
            async let marineData = client.data(from: MapScope.marineAreasURL)
            async let siteData = client.data(from: MapScope.accessSitesURL)

            let areas = MapScope.filter(marineAreas: try await WDFWLayerLoader.marineAreas(from: marineData))
            let sites = MapScope.filter(accessSites: try await WDFWLayerLoader.accessSites(from: siteData))

            // Empty is a distinct outcome from zero. Verified 2026-08-18: a valid
            // `where=` with no matches returns HTTP 200 + `features: []`, which
            // decodes cleanly and would otherwise render a blank map under a
            // success banner.
            guard !areas.isEmpty else { throw WDFWLayerError.emptyResult("marine areas") }
            guard !sites.isEmpty else { throw WDFWLayerError.emptyResult("access sites") }

            marineAreas = areas
            accessSites = sites
            statusMessage = MapScope.summary
        } catch {
            // Name why we fell back. A rejected query, a 500, and a plane are three
            // different things, and only one of them is "offline".
            let reason: String
            switch error {
            case WDFWLayerError.serviceError(let code, _): reason = "query rejected (\(code))"
            case WDFWLayerError.emptyResult(let what):     reason = "no \(what) returned"
            case WDFWLayerError.badHTTPStatus(let code):   reason = "HTTP \(code)"
            default:                                       reason = "offline"
            }
            do {
                try loadFromBundle(bundle: bundle)
                statusMessage = "\(MapScope.summary) (sample — \(reason))"
            } catch {
                // The fallback failed too. Do not claim sample data is on screen.
                marineAreas = []
                accessSites = []
                statusMessage = "Could not load WDFW data or the offline sample."
            }
        }
    }
}
