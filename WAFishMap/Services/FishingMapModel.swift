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
    /// A river for the view to open on launch. Set only under a UI test, because
    /// the river selection is view state the model cannot reach directly.
    var initialRiverName: String?

    /// Curated seasonal guidance (bundled, offline), resolved for `planYear`. See
    /// `Fishery.swift`. Every existing call site keeps reading this unchanged.
    var guide: FisheryGuide?
    /// The season-risk-resolved guide before year-parity stamping. Kept so a
    /// plan-year change is one `resolvingYear` pass over this base, not a
    /// re-parse of the bundle.
    private var baseGuide: FisheryGuide?
    /// The year `guide` is currently resolved for, so `setPlanYear` can skip
    /// recomputing when the year hasn't actually changed (e.g. a new `Date()`
    /// every render, same calendar year).
    private var planYear: Int?
    /// Bundled river geometry. Not a live layer — see `River`.
    var rivers: [River] = []
    /// Each river's own flow history, bundled. Keyed by river name.
    var riverStats: [String: RiverFlowStats] = [:]
    /// Latest USGS reading per gauge. Empty until the live fetch lands, and
    /// empty is *unknown*, never zero — an absent river stays neutral.
    var riverFlows: [String: RiverFlow] = [:]

    /// Bundled WDFW lake facts. Not a live layer — see `Lake`.
    var lakes: [Lake] = []
    /// Inland launch → the one WDFW lake it sits on. Precomputed like
    /// `siteWaterbody`: matching scans every lake.
    private(set) var siteLake: [AccessSite.ID: Lake] = [:]

    func lake(for site: AccessSite) -> Lake? {
        siteLake[site.id]
    }

    /// Launch → marine area (point-in-polygon, else within the shore snap). Absent for inland/lake
    /// launches, which have no marine area and therefore a neutral rating.
    private(set) var siteAreaName: [AccessSite.ID: String] = [:]

    /// Inland launch → the waterbody it sits on (curated list, else nearest river).
    /// Precomputed: resolving scans river geometry, too slow for every pin render.
    private(set) var siteWaterbody: [AccessSite.ID: String] = [:]
    private(set) var pierWaterbody: [FishingPier.ID: String] = [:]

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

    /// Same rule for the two live-only layers. False means the fetch failed or
    /// never ran, so an empty `piers` or a missing flow reading is unknown, not none.
    private(set) var piersLoaded = false
    private(set) var riverFlowsLoaded = false

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
            waterbody: siteWaterbody[site.id]
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
            waterbody: pierWaterbody[pier.id]
        )
    }

    /// A pier's current-month rating, resolved the same way as launches so piers are
    /// color-coded too (marine by polygon, else freshwater by county).
    func rating(for pier: FishingPier, month: Int, species: String? = nil) -> FishingRating? {
        fishery(for: pier)?.rating(inMonth: month, species: species)
    }

    func closurePlausible(for site: AccessSite, month: Int, species: String? = nil) -> Bool {
        fishery(for: site)?.closurePlausible(inMonth: month, species: species) ?? false
    }

    func closurePlausible(for pier: FishingPier, month: Int, species: String? = nil) -> Bool {
        fishery(for: pier)?.closurePlausible(inMonth: month, species: species) ?? false
    }

    enum Resource: String {
        case marineAreas = "marine-areas.sample"
        case accessSites = "access-sites.sample"
        case piers = "piers.sample"
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
        loadRiverStats(bundle: bundle)
        loadLakes(bundle: bundle)
        indexSitesToAreas()
        indexWaterbodies()
        statusMessage = "Washington · offline sample"
    }

    func load(client: HTTPGet = URLSessionHTTPGet(), bundle: Bundle = .main) async {
        // Under a UI test the network is not a dependency worth having: the run
        // asserts what the sheet renders, not that WDFW is up. The fixture also
        // fixes which site is selected, so the sheet is on screen without a tap.
        if UITestSeam.isActive {
            do {
                try loadFromBundle(bundle: bundle)
                // Piers come only from the network in real use, so the bundled
                // sample is loaded here and nowhere else: the offline fallback a
                // user sees stays exactly as it was.
                piers = try WDFWLayerLoader.piers(from: Self.data(.piers, in: bundle))
                indexPiersToAreas()
                indexWaterbodies()
                switch UITestSeam.detail ?? .site {
                case .site: selectedSiteID = accessSites.first?.id
                case .pier: selectedSiteID = piers.first?.id
                case .river: initialRiverName = rivers.first?.name
                }
            } catch {
                statusMessage = "Couldn't load WDFW data — check your connection"
            }
            return
        }
        loadGuide(bundle: bundle)
        loadRivers(bundle: bundle)
        loadRiverStats(bundle: bundle)
        loadLakes(bundle: bundle)
        do {
            // Independent layers — fetch concurrently.
            async let marineData = client.data(from: MapScope.marineAreasURL)
            async let siteData = client.data(from: MapScope.accessSitesURL)
            let liveAreas = MapScope.filter(marineAreas: try WDFWLayerLoader.marineAreas(from: await marineData))
            let liveSites = MapScope.filter(accessSites: try WDFWLayerLoader.accessSites(from: await siteData))
            // An empty layer used to render as "0 access sites · live WDFW data".
            // It takes the same fallback as a failed fetch instead.
            guard !liveAreas.isEmpty, !liveSites.isEmpty else { throw WDFWLayerError.emptyLayer }
            marineAreas = liveAreas
            accessSites = liveSites
            indexSitesToAreas()
            indexWaterbodies()
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
        // Piers are a live-only enhancement; absence is non-fatal. This fetch
        // (`async let`) starts before the MPA fetch below rather than after it —
        // the two layers don't depend on each other, only the indexing below
        // needs the MPA result first. The MPA fetch itself is sequential `await`,
        // not concurrent with this one.
        async let pierFetch = try? await client.data(from: MapScope.piersURL)
        // Marine Protected Areas are a live-only overlay; a failure is non-fatal
        // for the load but is not silent — `protectedAreasLoaded` stays false and
        // the sheet says the check could not run.
        do {
            let mpaData = try await client.data(from: MapScope.protectedAreasURL)
            let loaded = try WDFWLayerLoader.protectedAreas(from: mpaData)
            // Washington has 44 MPAs; an empty layer is a failed read, and
            // reading it as "clear" would clear every site in the state.
            guard !loaded.isEmpty else { throw WDFWLayerError.emptyLayer }
            protectedAreas = loaded
            indexSitesToProtectedAreas()
            protectedAreasLoaded = true
        } catch {
            protectedAreas = []
            siteProtectedArea = [:]
            pierProtectedArea = [:]
            protectedAreasLoaded = false
        }
        if let pierData = await pierFetch,
           let loaded = try? WDFWLayerLoader.piers(from: pierData), !loaded.isEmpty {
            piers = loaded
            piersLoaded = true
            indexPiersToAreas()
            indexWaterbodies()
            // Piers load after the MPA layer, so their MPA index is built here.
            // Indexing inside the MPA block would always see zero piers.
            indexPiersToProtectedAreas()
        }
        // River flow is a live-only enhancement; a USGS outage leaves every
        // river neutral rather than taking the map down.
        if let flowData = try? await client.data(from: USGSFlowLoader.url),
           let loaded = try? USGSFlowLoader.flows(from: flowData), !loaded.isEmpty {
            riverFlows = loaded
            riverFlowsLoaded = true
        }
        // Piers load after the headline status is set, so a failure is appended
        // here rather than dropped.
        if !piersLoaded && !accessSites.isEmpty {
            statusMessage += " · piers unavailable"
        }
        isLoading = false
    }

    /// Match every launch to its marine area: containing polygon first, else the
    /// shore snap (`MarineArea.matching`).
    func indexSitesToAreas() {
        var map: [AccessSite.ID: String] = [:]
        for site in accessSites {
            if let area = marineArea(at: site.coordinate, facility: site.facilityName) {
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

    /// Match every pier to its marine area: containing polygon first, else the
    /// shore snap (`MarineArea.matching`).
    private func indexPiersToAreas() {
        var map: [FishingPier.ID: String] = [:]
        for pier in piers {
            if let area = marineArea(at: pier.coordinate, facility: pier.name) {
                map[pier.id] = area.areaName
            }
        }
        pierAreaName = map
    }

    /// Containment always wins; the shore snap does not. A river-mouth or slough
    /// ramp just outside a polygon (Palix River 10 m, Hat Slough 39 m) keeps its
    /// river or lake rows rather than being snapped into the marine area.
    private func marineArea(at point: LonLat, facility: String) -> MarineArea? {
        if let inside = marineAreas.first(where: { $0.contains(point) }) { return inside }
        let freshwater = guide?.freshwater
        if let waterbody = freshwater?.waterbody(forFacility: facility, at: point, rivers: rivers),
           freshwater?.byWaterbody?[waterbody]?.isEmpty == false {
            return nil
        }
        return MarineArea.matching(point, in: marineAreas)
    }

    /// Must run after the guide, rivers and marine-area indexes are in place.
    func indexWaterbodies() {
        let freshwater = guide?.freshwater
        var sites: [AccessSite.ID: String] = [:]
        for site in accessSites where siteAreaName[site.id] == nil {
            sites[site.id] = freshwater?.waterbody(forFacility: site.facilityName, at: site.coordinate, rivers: rivers)
        }
        siteWaterbody = sites
        var piersMap: [FishingPier.ID: String] = [:]
        for pier in piers where pierAreaName[pier.id] == nil {
            piersMap[pier.id] = freshwater?.waterbody(forFacility: pier.name, at: pier.coordinate, rivers: rivers)
        }
        pierWaterbody = piersMap

        var lakeMap: [AccessSite.ID: Lake] = [:]
        for site in accessSites where siteAreaName[site.id] == nil {
            lakeMap[site.id] = Lake.match(facilityName: site.facilityName, at: site.coordinate, in: lakes)
        }
        siteLake = lakeMap
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

    private func loadRiverStats(bundle: Bundle) {
        guard riverStats.isEmpty,
              let url = bundle.url(forResource: "river_stats", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? RiverFlowStatsLoader.stats(from: data) else { return }
        riverStats = loaded
    }

    private func loadLakes(bundle: Bundle) {
        guard lakes.isEmpty,
              let url = bundle.url(forResource: "lakes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? LakeLoader.lakes(from: data) else { return }
        lakes = loaded
    }

    /// The live reading for a river, found through the gauge its bundled
    /// history names. Nil means no gauge, or no reading today — both render
    /// neutral, and neither is a zero.
    func flow(forRiver name: String) -> RiverFlow? {
        guard let gauge = riverStats[name]?.gauge else { return nil }
        return riverFlows[gauge]
    }

    /// Flow rating per river id for a given calendar day. The day is injected;
    /// nothing in this path reads the clock.
    func riverRatings(month: Int, day: Int) -> [String: FishingRating] {
        var ratings: [String: FishingRating] = [:]
        for (name, stats) in riverStats {
            guard let discharge = riverFlows[stats.gauge]?.discharge,
                  let rating = stats.rating(discharge: discharge, month: month, day: day)
            else { continue }
            ratings[name] = rating
        }
        return ratings
    }

    /// Loads the guide, stamped for `planYear` if the view has already set one.
    /// This layer never reads the clock; the view calls `setPlanYear` before
    /// `load`, because `load` publishes the guide ahead of its network awaits and
    /// pins render against it while those are still in flight.
    private func loadGuide(bundle: Bundle) {
        guard baseGuide == nil,
              let url = bundle.url(forResource: "fisheries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? FisheryLoader.guide(from: data) else { return }
        baseGuide = loaded
        guide = planYear.map(loaded.resolvingYear) ?? loaded
    }

    /// Record the plan year and re-stamp `guide` for it. A no-op when the year
    /// hasn't changed. Before the guide loads it only records the year, which
    /// `loadGuide` then applies.
    func setPlanYear(_ year: Int) {
        guard year != planYear else { return }
        planYear = year
        guard let baseGuide else { return }
        guide = baseGuide.resolvingYear(year)
    }

    private static func data(_ resource: Resource, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource.rawValue, withExtension: "geojson") else {
            throw WDFWLayerError.missingBundleResource(resource.rawValue)
        }
        return try Data(contentsOf: url)
    }
}
