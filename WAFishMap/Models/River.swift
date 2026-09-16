import CoreLocation
import Foundation

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

    /// Metres from a coordinate to the nearest point on this river, or nil if it
    /// has no drawable run. Pure, so tap-to-select is testable without a map.
    ///
    /// Equirectangular rather than great-circle: over the tens of metres a tap
    /// tolerance spans, the error is far below a fingertip, and a river is a few
    /// hundred segments to check on every tap.
    func distanceMeters(to point: LonLat) -> Double? {
        var best = Double.infinity
        for line in lines {
            for index in 0..<(line.count - 1) {
                best = min(best, Self.distance(point, line[index], line[index + 1]))
            }
        }
        return best.isFinite ? best : nil
    }

    /// How close a launch must sit to a river's line to count as on it. Ramps sit
    /// back from NHD's centreline; much wider and a lakeside launch catches the
    /// neighbouring river.
    static let waterbodyMatchMeters: Double = 150

    /// The closest river within `meters` of `point`, or nil. The nearer river wins
    /// at a confluence.
    static func nearest(to point: LonLat, within meters: Double, in rivers: [River]) -> River? {
        var best: (river: River, distance: Double)?
        for river in rivers {
            guard let d = river.distanceMeters(to: point), d <= meters else { continue }
            if best == nil || d < best!.distance { best = (river, d) }
        }
        return best?.river
    }

    private static let metresPerDegree = 111_320.0

    /// Point-to-segment distance, projected flat around the point's latitude.
    private static func distance(_ p: LonLat, _ a: LonLat, _ b: LonLat) -> Double {
        let scale = cos(p.latitude * .pi / 180)
        func project(_ c: LonLat) -> (x: Double, y: Double) {
            ((c.longitude - p.longitude) * scale * metresPerDegree,
             (c.latitude - p.latitude) * metresPerDegree)
        }
        let (ax, ay) = project(a)
        let (bx, by) = project(b)
        let (dx, dy) = (bx - ax, by - ay)
        let lengthSquared = dx * dx + dy * dy
        // A zero-length segment is just its endpoint; the clamp below would
        // divide by zero.
        guard lengthSquared > 0 else { return (ax * ax + ay * ay).squareRoot() }
        let t = min(1, max(0, -(ax * dx + ay * dy) / lengthSquared))
        let (cx, cy) = (ax + t * dx, ay + t * dy)
        return (cx * cx + cy * cy).squareRoot()
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
