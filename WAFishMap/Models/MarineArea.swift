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

    /// Ray-casting point-in-polygon test against the outer ring. Used to match a
    /// launch (a bare point with no area code) to the marine area it sits in.
    func contains(_ point: LonLat) -> Bool {
        guard coordinates.count >= 3 else { return false }
        var inside = false
        var j = coordinates.count - 1
        for i in 0..<coordinates.count {
            let a = coordinates[i], b = coordinates[j]
            if (a.latitude > point.latitude) != (b.latitude > point.latitude) {
                let xCross = a.longitude
                    + (point.latitude - a.latitude) / (b.latitude - a.latitude)
                    * (b.longitude - a.longitude)
                if point.longitude < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
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
