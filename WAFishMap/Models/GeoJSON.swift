struct GeoJSONFeatureCollection<Props: Decodable>: Decodable {
    let features: [GeoJSONFeature<Props>]
}

struct GeoJSONFeature<Props: Decodable>: Decodable {
    /// Optional on purpose. ArcGIS can emit `"geometry": null`, and a non-optional
    /// here fails the whole FeatureCollection decode on one bad feature, which the
    /// loader then reports as "offline". Geometry-less features fall out of the
    /// existing `compactMap` instead.
    let geometry: GeoJSONGeometry?
    let properties: Props
}

enum GeoJSONGeometry: Decodable {
    case point(longitude: Double, latitude: Double)
    case polygon(rings: [[[Double]]])
    case other(String)

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Point":
            let pair = try container.decode([Double].self, forKey: .coordinates)
            guard pair.count >= 2 else {
                self = .other(type)
                return
            }
            self = .point(longitude: pair[0], latitude: pair[1])
        case "Polygon":
            let rings = try container.decode([[[Double]]].self, forKey: .coordinates)
            self = .polygon(rings: rings)
        default:
            self = .other(type)
        }
    }
}
