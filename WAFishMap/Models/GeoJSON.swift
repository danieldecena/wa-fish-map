struct GeoJSONFeatureCollection<Props: Decodable>: Decodable {
    let features: [GeoJSONFeature<Props>]

    /// ArcGIS sets this when the response hit the server's transfer limit and is
    /// missing features. Emitted both at the top level and under `properties`,
    /// depending on server version — accept either.
    let exceededTransferLimit: Bool?
    private let properties: CollectionProperties?

    var isTruncated: Bool {
        exceededTransferLimit == true || properties?.exceededTransferLimit == true
    }

    private struct CollectionProperties: Decodable {
        let exceededTransferLimit: Bool?
    }
}

struct GeoJSONFeature<Props: Decodable>: Decodable {
    let geometry: GeoJSONGeometry
    let properties: Props
}

enum GeoJSONGeometry: Decodable {
    case point(longitude: Double, latitude: Double)
    case polygon(rings: [[[Double]]])
    case multiPolygon(polygons: [[[[Double]]]])
    case lineString(coordinates: [[Double]])
    case multiLineString(lines: [[[Double]]])
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
        case "MultiPolygon":
            let polygons = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            self = .multiPolygon(polygons: polygons)
        case "LineString":
            let line = try container.decode([[Double]].self, forKey: .coordinates)
            self = .lineString(coordinates: line)
        case "MultiLineString":
            let lines = try container.decode([[[Double]]].self, forKey: .coordinates)
            self = .multiLineString(lines: lines)
        default:
            self = .other(type)
        }
    }
}
