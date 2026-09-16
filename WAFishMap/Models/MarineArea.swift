import CoreLocation

struct MarineArea: Identifiable, Equatable, Sendable {
    var id: String { areaName }
    let areaName: String
    let areaTitle: String
    let wac: String
    /// Every ring of the source geometry: a WDFW Polygon packs the outer
    /// boundary plus every island, disjoint part, and hole into one feature, and
    /// a MultiPolygon's rings flatten in here too — `contains(_:)` treats all of
    /// them alike under the even-odd rule, so which part a ring came from
    /// doesn't matter.
    let rings: [[LonLat]]
    /// `rings` grouped into outer boundaries and their holes, computed once at
    /// init. Ring geometry never changes with the rating colour, so overlay
    /// rebuilds triggered by a month/species change reuse this instead of
    /// re-running the hole/area classification (up to 286 rings) on every
    /// colour change, on the main thread, inside `updateUIView`.
    let ringGroups: [LonLat.RingGroup]
    /// One box per ring, parallel to `rings`, for the shore snap.
    let ringBounds: [LonLat.Bounds]

    /// The largest ring by vertex count. Stands in wherever a single ring is
    /// needed (the label centroid below, and any caller predating multi-ring
    /// areas) — ties keep the first ring, matching the old "outer ring only"
    /// behaviour for a simple single-ring Polygon.
    var coordinates: [LonLat] {
        var best = rings.first ?? []
        for ring in rings.dropFirst() where ring.count > best.count { best = ring }
        return best
    }

    var mapCoordinates: [CLLocationCoordinate2D] {
        coordinates.map(\.clLocationCoordinate)
    }

    /// Rough centroid (average of the largest ring's vertices) — used to place the area label.
    var center: CLLocationCoordinate2D {
        let coords = coordinates
        guard !coords.isEmpty else { return CLLocationCoordinate2D() }
        let n = Double(coords.count)
        return CLLocationCoordinate2D(
            latitude: coords.map(\.latitude).reduce(0, +) / n,
            longitude: coords.map(\.longitude).reduce(0, +) / n
        )
    }

    /// Even-odd point-in-polygon test across every ring. Used to match a launch
    /// (a bare point with no area code) to the marine area it sits in.
    func contains(_ point: LonLat) -> Bool {
        LonLat.rings(rings, contains: point)
    }

    /// How far outside its polygon a saltwater point may sit and still belong to
    /// it. WDFW draws each area to the shoreline and records a pier or ramp at
    /// its landward end, so on 2026-09-16 29 of 63 live piers sat outside every
    /// area (28 within 1 m of an edge) and read as freshwater, as did launches
    /// like Boston Harbor (30 m) and Point No Point (65 m). The nearest genuine
    /// lake launch was 639 m from salt water. Same tolerance as river matching.
    static let shoreSnapMeters: Double = 150

    /// Metres from `point` to this area's nearest edge, or nil when no ring comes
    /// within `meters`.
    func edgeDistanceMeters(to point: LonLat, within meters: Double) -> Double? {
        var best = Double.infinity
        for (ring, bounds) in zip(rings, ringBounds) where ring.count >= 2 && bounds.contains(point, slackMeters: meters) {
            var j = ring.count - 1
            for i in 0..<ring.count {
                best = min(best, LonLat.distanceMeters(from: point, toSegment: ring[j], ring[i]))
                j = i
            }
        }
        return best <= meters ? best : nil
    }

    /// The area containing `point` (first wins, as before), else the nearest area
    /// whose edge lies within `shoreSnapMeters`. Inland points match nothing and
    /// stay freshwater.
    static func matching(_ point: LonLat, in areas: [MarineArea]) -> MarineArea? {
        if let inside = areas.first(where: { $0.contains(point) }) { return inside }
        var best: (area: MarineArea, distance: Double)?
        for area in areas {
            guard let d = area.edgeDistanceMeters(to: point, within: shoreSnapMeters) else { continue }
            if best == nil || d < best!.distance { best = (area, d) }
        }
        return best?.area
    }

    struct Properties: Decodable {
        let areaName: String
        let areaTitle: String
        let wac: String?

        enum CodingKeys: String, CodingKey {
            case areaName = "AreaName"
            case areaTitle = "AreaTitle"
            case wac = "WAC"
        }
    }

    /// Single-ring convenience — kept for callers (and tests) predating
    /// multi-ring areas.
    init(areaName: String, areaTitle: String, wac: String, coordinates: [LonLat]) {
        self.init(areaName: areaName, areaTitle: areaTitle, wac: wac, rings: [coordinates])
    }

    init(areaName: String, areaTitle: String, wac: String, rings: [[LonLat]]) {
        self.areaName = areaName
        self.areaTitle = areaTitle
        self.wac = wac
        self.rings = rings
        self.ringGroups = LonLat.groupRings(rings)
        self.ringBounds = rings.map(LonLat.Bounds.init)
    }

    init?(feature: GeoJSONFeature<Properties>) {
        let rawRings: [[[Double]]]
        switch feature.geometry {
        case .polygon(let rings): rawRings = rings
        case .multiPolygon(let polygons): rawRings = polygons.flatMap { $0 }
        default: return nil
        }
        let parsedRings: [[LonLat]] = rawRings.compactMap { ring in
            let raw: [LonLat] = ring.compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return LonLat(longitude: pair[0], latitude: pair[1])
            }
            let coords = LonLat.droppingClosingVertex(raw)
            return coords.count >= 3 ? coords : nil
        }
        guard !parsedRings.isEmpty else { return nil }
        areaName = feature.properties.areaName
        areaTitle = feature.properties.areaTitle
        wac = feature.properties.wac ?? ""
        rings = parsedRings
        ringGroups = LonLat.groupRings(parsedRings)
        ringBounds = parsedRings.map(LonLat.Bounds.init)
    }
}
