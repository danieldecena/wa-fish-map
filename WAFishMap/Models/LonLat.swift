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

    /// One outer boundary and the holes cut out of it — ready for
    /// `MKPolygon(coordinates:count:interiorPolygons:)`.
    struct RingGroup {
        let outer: [LonLat]
        var holes: [[LonLat]]
    }

    /// Groups a geometry's rings into outer boundaries and the holes cut from
    /// them, so a hole can be rendered as an actual cutout instead of an opaque
    /// fill. Uses the same even-odd rule as `rings(_:contains:)` to classify
    /// each ring: a ring is a hole if one of its own vertices lies inside an
    /// odd number of the OTHER rings in the set; otherwise it's an outer. Each
    /// hole attaches to the smallest (by area) outer ring whose boundary
    /// contains it — the right choice when outers are nested, and the only
    /// choice when they aren't. Containment via `contains(_:)` is unaffected by
    /// this grouping; it stays flat across all rings.
    static func groupRings(_ rings: [[LonLat]]) -> [RingGroup] {
        guard !rings.isEmpty else { return [] }

        func isHole(_ index: Int) -> Bool {
            guard let vertex = rings[index].first else { return false }
            var containingCount = 0
            for (otherIndex, other) in rings.enumerated() where otherIndex != index {
                if polygon(other, contains: vertex) { containingCount += 1 }
            }
            return containingCount % 2 == 1
        }

        let outerIndices = rings.indices.filter { !isHole($0) }
        var groups = outerIndices.map { RingGroup(outer: rings[$0], holes: []) }

        for holeIndex in rings.indices where isHole(holeIndex) {
            guard let vertex = rings[holeIndex].first else { continue }
            let candidates = outerIndices.enumerated()
                .filter { polygon(rings[$0.element], contains: vertex) }
            guard let smallest = candidates.min(by: { area(rings[$0.element]) < area(rings[$1.element]) })
            else {
                // No outer claims it — shouldn't happen for well-formed WDFW
                // data, but surfacing it as its own outer beats silently
                // dropping the ring.
                groups.append(RingGroup(outer: rings[holeIndex], holes: []))
                continue
            }
            groups[smallest.offset].holes.append(rings[holeIndex])
        }

        return groups
    }

    /// Shoelace polygon area (unsigned). Only used to compare ring sizes when
    /// attaching a hole to the smallest enclosing outer — never rendered or reported.
    private static func area(_ ring: [LonLat]) -> Double {
        guard ring.count >= 3 else { return 0 }
        var sum = 0.0
        var j = ring.count - 1
        for i in 0..<ring.count {
            sum += (ring[j].longitude + ring[i].longitude) * (ring[j].latitude - ring[i].latitude)
            j = i
        }
        return abs(sum) / 2
    }
}
