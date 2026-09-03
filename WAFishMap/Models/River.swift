import CoreLocation

/// A named Washington river, bundled as geometry rather than fetched. WDFW's
/// MapServer has no hydrography layer, so this comes from the USGS NHD via
/// `scripts/build_rivers.py` — see that script for why the FTYPE filter matters.
///
/// A river is a *line*, so nothing here is a containment test: `MarineArea` earns
/// a point its colour by containing it, and no polygon can answer what a river
/// hundreds of miles long is worth today.
struct River: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    /// Strahler order, highest of the river's segments. Drives line weight only.
    let streamOrder: Int
    let lengthKm: Double
    /// NHD splits a river into runs, so a river is many lines, not one.
    let lines: [[LonLat]]

    var mapLines: [[CLLocationCoordinate2D]] {
        lines.map { $0.map(\.clLocationCoordinate) }
    }

    /// Points, not metres: `MKPolylineRenderer.lineWidth` is a screen width, so a
    /// mainstem stays visibly heavier than a tributary at every zoom.
    var lineWidth: CGFloat {
        switch streamOrder {
        case ...3: 1.0
        case 4...5: 1.8
        default: 2.8
        }
    }

    struct Properties: Decodable {
        let name: String
        let streamOrder: Int
        let lengthKm: Double
    }

    init(name: String, streamOrder: Int, lengthKm: Double, lines: [[LonLat]]) {
        self.name = name
        self.streamOrder = streamOrder
        self.lengthKm = lengthKm
        self.lines = lines
    }

    init?(feature: GeoJSONFeature<Properties>) {
        let raw: [[[Double]]]
        switch feature.geometry {
        case .multiLineString(let lines): raw = lines
        case .lineString(let line): raw = [line]
        default: return nil
        }
        let parsed: [[LonLat]] = raw.compactMap { line in
            let points: [LonLat] = line.compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return LonLat(longitude: pair[0], latitude: pair[1])
            }
            return points.count >= 2 ? points : nil
        }
        guard !parsed.isEmpty else { return nil }
        name = feature.properties.name
        streamOrder = feature.properties.streamOrder
        lengthKm = feature.properties.lengthKm
        lines = parsed
    }
}
