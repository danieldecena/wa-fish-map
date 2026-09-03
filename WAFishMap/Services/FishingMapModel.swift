import Foundation

@MainActor
@Observable
final class FishingMapModel {
    var marineAreas: [MarineArea] = []
    var accessSites: [AccessSite] = []
    var piers: [FishingPier] = []
    var protectedAreas: [ProtectedArea] = []
    var statusMessage = "Loading…"
    var isLoading = true
    var selectedSiteID: AccessSite.ID?

    /// Curated seasonal guidance (bundled, offline). See `Fishery.swift`.
    var guide: FisheryGuide?
    /// Bundled river geometry. Not a live layer — see `River`.
    var rivers: [River] = []

    /// Launch → containing marine area (by point-in-polygon). Absent for inland/lake
    /// launches, which have no marine area and therefore a neutral rating.
    private(set) var siteAreaName: [AccessSite.ID: String] = [:]

    /// Pier → containing marine area, same point-in-polygon index as launches so pier
    /// markers and heat zones don't re-scan every polygon on each render.
    private(set) var pierAreaName: [FishingPier.ID: String] = [:]
    private(set) var pierProtectedArea: [FishingPier.ID: ProtectedArea] = [:]

    /// Site → the Marine Protected Area whose polygon contains it (first match).
    private(set) var siteProtectedArea: [AccessSite.ID: ProtectedArea] = [:]

    /// True once the MPA layer has actually been read. An empty `protectedAreas`
    /// on its own cannot tell "checked, nothing here" from "the check never ran",
    /// and the second must never render as the first.
    private(set) var protectedAreasLoaded = false

    /// The Marine Protected Area a site sits inside, if any. Only meaningful once
    /// `protectedAreasLoaded`; callers wanting the three-way answer use
    /// `protectedAreaCheck(for:)`.
    func protectedArea(for site: AccessSite) -> ProtectedArea? {
        siteProtectedArea[site.id]
    }

    /// Inside an MPA, clear of every MPA, or unable to say.
    func protectedAreaCheck(for site: AccessSite) -> ProtectedAreaCheck {
        guard protectedAreasLoaded else { return .unavailable }
        if let mpa = siteProtectedArea[site.id] { return .inside(mpa) }
        return .clear
    }

    /// Inside an MPA, clear of every MPA, or unable to say — piers sit in the
    /// same water as launches, so the same restriction applies to them.
    func protectedAreaCheck(for pier: FishingPier) -> ProtectedAreaCheck {
        guard protectedAreasLoaded else { return .unavailable }
        if let mpa = pierProtectedArea[pier.id] { return .inside(mpa) }
        return .clear
    }

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
        return guide?.freshwater?.fishery(
            county: site.countyName,
            waterbody: guide?.freshwater?.waterbody(forFacility: site.facilityName)
        )
    }

    /// The launch's current-month rating, or nil when no guidance applies — the UI
    /// renders that neutral.
    func rating(for site: AccessSite, month: Int, species: String? = nil) -> FishingRating? {
        fishery(for: site)?.rating(inMonth: month, species: species)
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
        return guide?.freshwater?.fishery(
            county: pier.countyName,
            waterbody: guide?.freshwater?.waterbody(forFacility: pier.name)
        )
    }

    /// A pier's current-month rating, resolved the same way as launches so piers are
    /// color-coded too (marine by polygon, else freshwater by county).
    func rating(for pier: FishingPier, month: Int, species: String? = nil) -> FishingRating? {
        fishery(for: pier)?.rating(inMonth: month, species: species)
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
        loadRivers(bundle: bundle)
        indexSitesToAreas()
        statusMessage = "Washington · offline sample"
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
        // Under a UI test the network is not a dependency worth having: the run
        // asserts what the sheet renders, not that WDFW is up. The fixture also
        // fixes which site is selected, so the sheet is on screen without a tap.
        if UITestSeam.isActive {
            do {
                try loadFromBundle(bundle: bundle)
                selectedSiteID = accessSites.first?.id
            } catch {
                statusMessage = "Couldn't load WDFW data — check your connection"
            }
            return
        }
        loadGuide(bundle: bundle)
        loadRivers(bundle: bundle)
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
        // Marine Protected Areas are a live-only overlay; a failure is non-fatal
        // for the load but is not silent — `protectedAreasLoaded` stays false and
        // the sheet says the check could not run.
        do {
            let mpaData = try await client.data(from: MapScope.protectedAreasURL)
            protectedAreas = try WDFWLayerLoader.protectedAreas(from: mpaData)
            indexSitesToProtectedAreas()
            protectedAreasLoaded = true
        } catch {
            protectedAreas = []
            siteProtectedArea = [:]
            pierProtectedArea = [:]
            protectedAreasLoaded = false
        }
        // Piers are a live-only enhancement; absence is non-fatal.
        if let pierData = try? await client.data(from: MapScope.piersURL),
           let loaded = try? WDFWLayerLoader.piers(from: pierData) {
            piers = loaded
            indexPiersToAreas()
            // Piers load after the MPA layer, so their MPA index is built here.
            // Indexing inside the MPA block would always see zero piers.
            indexPiersToProtectedAreas()
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

    /// Match every site to the Marine Protected Area containing it (first wins).
    private func indexSitesToProtectedAreas() {
        var map: [AccessSite.ID: ProtectedArea] = [:]
        for site in accessSites {
            if let mpa = protectedAreas.first(where: { $0.contains(site.coordinate) }) {
                map[site.id] = mpa
            }
        }
        siteProtectedArea = map
    }

    /// Match every pier to the Marine Protected Area containing it (first wins).
    private func indexPiersToProtectedAreas() {
        var map: [FishingPier.ID: ProtectedArea] = [:]
        for pier in piers {
            if let mpa = protectedAreas.first(where: { $0.contains(pier.coordinate) }) {
                map[pier.id] = mpa
            }
        }
        pierProtectedArea = map
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
    /// Loads the bundled river geometry. Absence is non-fatal, like the guide —
    /// the map still draws every launch, it just draws no rivers.
    private func loadRivers(bundle: Bundle) {
        guard rivers.isEmpty,
              let url = bundle.url(forResource: "rivers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? RiverLoader.rivers(from: data) else { return }
        rivers = loaded
    }

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
