import Foundation

@MainActor
@Observable
final class FishingMapModel {
    var marineAreas: [MarineArea] = []
    var accessSites: [AccessSite] = []
    var piers: [FishingPier] = []
    var statusMessage = "Loading…"
    var selectedSiteID: AccessSite.ID?

    /// Curated seasonal guidance (bundled, offline). See `Fishery.swift`.
    var guide: FisheryGuide?

    /// Launch → containing marine area (by point-in-polygon). Absent for inland/lake
    /// launches, which have no marine area and therefore a neutral rating.
    private(set) var siteAreaName: [AccessSite.ID: String] = [:]

    var selectedSite: AccessSite? {
        accessSites.first { $0.id == selectedSiteID }
    }

    /// The marine area a launch sits in, if any.
    func areaName(for site: AccessSite) -> String? {
        siteAreaName[site.id]
    }

    /// True when the launch sits inside a marine area (vs. inland freshwater).
    func isMarine(_ site: AccessSite) -> Bool {
        areaName(for: site) != nil
    }

    /// Resolved guidance for a launch: its marine area if it's in one, otherwise the
    /// freshwater table for its county. Nil only when no guidance applies at all.
    func fishery(for site: AccessSite) -> AreaFishery? {
        if let area = areaName(for: site), let marine = guide?.area(named: area) {
            return marine
        }
        return guide?.freshwater?.fishery(county: site.countyName)
    }

    /// The launch's current-month rating, or nil when no guidance applies — the UI
    /// renders that neutral.
    func rating(for site: AccessSite, month: Int) -> FishingRating? {
        fishery(for: site)?.rating(inMonth: month)
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
        loadGuide(bundle: bundle)
        indexSitesToAreas()
        statusMessage = "Washington · offline sample"
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
        loadGuide(bundle: bundle)
        do {
            let marineData = try await client.data(from: MapScope.marineAreasURL)
            let siteData = try await client.data(from: MapScope.accessSitesURL)
            marineAreas = MapScope.filter(marineAreas: try WDFWLayerLoader.marineAreas(from: marineData))
            accessSites = MapScope.filter(accessSites: try WDFWLayerLoader.accessSites(from: siteData))
            indexSitesToAreas()
            statusMessage = "Washington · \(accessSites.count) access sites · live WDFW data"
        } catch {
            try? loadFromBundle(bundle: bundle)
        }
        // Piers are a live-only enhancement; absence is non-fatal.
        if let pierData = try? await client.data(from: MapScope.piersURL),
           let loaded = try? WDFWLayerLoader.piers(from: pierData) {
            piers = loaded
        }
    }

    /// Match every launch to the marine area whose polygon contains it (first wins).
    private func indexSitesToAreas() {
        var map: [AccessSite.ID: String] = [:]
        for site in accessSites {
            if let area = marineAreas.first(where: { $0.contains(site.coordinate) }) {
                map[site.id] = area.areaName
            }
        }
        siteAreaName = map
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
