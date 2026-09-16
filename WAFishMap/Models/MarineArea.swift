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

    /// One coordinate array per ring, for the map overlay — a fill per ring so
    /// every disjoint part and island actually draws, not just the largest one.
    var ringsMapCoordinates: [[CLLocationCoordinate2D]] {
        rings.map { $0.map(\.clLocationCoordinate) }
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
    }
}
