import Foundation

@MainActor
@Observable
final class FishingMapModel {
    var marineAreas: [MarineArea] = []
    var accessSites: [AccessSite] = []
    var piers: [FishingPier] = []
    var statusMessage = "Loading…"
    var isLoading = true
    var selectedSiteID: AccessSite.ID?

    /// Curated seasonal guidance (bundled, offline). See `Fishery.swift`.
    var guide: FisheryGuide?

    /// Launch → containing marine area (by point-in-polygon). Absent for inland/lake
    /// launches, which have no marine area and therefore a neutral rating.
    private(set) var siteAreaName: [AccessSite.ID: String] = [:]

    /// Pier → containing marine area, same point-in-polygon index as launches so pier
    /// markers and heat zones don't re-scan every polygon on each render.
    private(set) var pierAreaName: [FishingPier.ID: String] = [:]

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

    /// Resolved guidance for a launch (uses the precomputed area index for its marine
    /// lookup), otherwise the freshwater table for its county.
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

    /// True when the pier sits inside a marine area (vs. a lake/river pier).
    func isMarine(_ pier: FishingPier) -> Bool {
        pierAreaName[pier.id] != nil
    }

    /// Resolved guidance for a pier (precomputed area index, else freshwater by
    /// county) — the same chain as launches.
    func fishery(for pier: FishingPier) -> AreaFishery? {
        if let area = pierAreaName[pier.id], let marine = guide?.area(named: area) {
            return marine
        }
        return guide?.freshwater?.fishery(county: pier.countyName)
    }

    /// A pier's current-month rating, resolved the same way as launches so piers are
    /// color-coded too (marine by polygon, else freshwater by county).
    func rating(for pier: FishingPier, month: Int) -> FishingRating? {
        fishery(for: pier)?.rating(inMonth: month)
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
            // Independent layers — fetch concurrently.
            async let marineData = client.data(from: MapScope.marineAreasURL)
            async let siteData = client.data(from: MapScope.accessSitesURL)
            marineAreas = MapScope.filter(marineAreas: try WDFWLayerLoader.marineAreas(from: await marineData))
            accessSites = MapScope.filter(accessSites: try WDFWLayerLoader.accessSites(from: await siteData))
            indexSitesToAreas()
            statusMessage = "Washington · \(accessSites.count) access sites · live WDFW data"
        } catch {
            do {
                try loadFromBundle(bundle: bundle)
            } catch {
                // Both the live fetch and the bundled sample failed — say so rather
                // than stranding the "Loading…" placeholder.
                statusMessage = "Couldn't load WDFW data — check your connection"
            }
        }
        // Piers are a live-only enhancement; absence is non-fatal.
        if let pierData = try? await client.data(from: MapScope.piersURL),
           let loaded = try? WDFWLayerLoader.piers(from: pierData) {
            piers = loaded
            indexPiersToAreas()
        }
        isLoading = false
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

    /// Match every pier to the marine area whose polygon contains it (first wins).
    private func indexPiersToAreas() {
        var map: [FishingPier.ID: String] = [:]
        for pier in piers {
            if let area = marineAreas.first(where: { $0.contains(pier.coordinate) }) {
                map[pier.id] = area.areaName
            }
        }
        pierAreaName = map
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
