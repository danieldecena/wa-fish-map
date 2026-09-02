import CoreLocation

struct MarineArea: Identifiable, Equatable, Sendable {
    var id: String { areaName }
    let areaName: String
    let areaTitle: String
    let wac: String
    let coordinates: [LonLat]

    var mapCoordinates: [CLLocationCoordinate2D] {
        coordinates.map(\.clLocationCoordinate)
    }

    /// Rough centroid (average of outer-ring vertices) — used to place the area label.
    var center: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else { return CLLocationCoordinate2D() }
        let n = Double(coordinates.count)
        return CLLocationCoordinate2D(
            latitude: coordinates.map(\.latitude).reduce(0, +) / n,
            longitude: coordinates.map(\.longitude).reduce(0, +) / n
        )
    }

    /// Ray-casting point-in-polygon test against the outer ring. Used to match a
    /// launch (a bare point with no area code) to the marine area it sits in.
    func contains(_ point: LonLat) -> Bool {
        LonLat.polygon(coordinates, contains: point)
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

    init(areaName: String, areaTitle: String, wac: String, coordinates: [LonLat]) {
        self.areaName = areaName
        self.areaTitle = areaTitle
        self.wac = wac
        self.coordinates = coordinates
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard case .polygon(let rings) = feature.geometry,
              let outer = rings.first else { return nil }
        let raw: [LonLat] = outer.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return LonLat(longitude: pair[0], latitude: pair[1])
        }
        let coords = LonLat.droppingClosingVertex(raw)
        guard coords.count >= 3 else { return nil }
        areaName = feature.properties.areaName
        areaTitle = feature.properties.areaTitle
        wac = feature.properties.wac ?? ""
        coordinates = coords
    }
}
