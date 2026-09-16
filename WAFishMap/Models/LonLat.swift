import CoreLocation

struct LonLat: Equatable, Hashable, Sendable {
    var longitude: Double
    var latitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Ray-casting point-in-polygon test against an outer ring. Shared by
    /// `MarineArea` and `ProtectedArea` — two copies of this is how they drift.
    static func polygon(_ ring: [LonLat], contains point: LonLat) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
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

    /// Even-odd containment across every ring of a multi-ring geometry: a point
    /// is inside if it lies inside an odd number of rings. That single rule
    /// handles disjoint parts (each ring adds its own "inside") and holes (the
    /// hole ring flips it back out) without needing to know which ring is an
    /// outer boundary and which is a hole. Reuses `polygon(_:contains:)` per
    /// ring rather than a fresh ray-cast.
    static func rings(_ rings: [[LonLat]], contains point: LonLat) -> Bool {
        rings.reduce(false) { result, ring in
            polygon(ring, contains: point) ? !result : result
        }
    }

    static func droppingClosingVertex(_ coords: [LonLat]) -> [LonLat] {
        guard coords.count >= 2, coords.first == coords.last else { return coords }
        return Array(coords.dropLast())
    }
}
