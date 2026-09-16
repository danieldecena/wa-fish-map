import Foundation

/// A WDFW lowland lake, bundled from `scripts/build_lakes.py`. WDFW publishes
/// lakes as points, not outlines, so a launch is linked to a lake by distance
/// scaled to the lake's acreage, never by containment.
struct Lake: Decodable, Identifiable, Equatable, Sendable {
    var id: String { "\(name)|\(longitude)|\(latitude)" }
    let name: String
    let county: String
    let longitude: Double
    let latitude: Double
    let acres: Double?
    let elevationFeet: Int?
    let management: String?
    let shorelineAccess: String?
    let boatRamp: String?
    let websiteURL: String?
    /// WDFW's per-species lake lists, in WDFW layer order.
    let species: [String]

    var coordinate: LonLat { LonLat(longitude: longitude, latitude: latitude) }

    /// Radius of a circle with this lake's area. A long lake is wider than this
    /// along its axis, so its far shore misses; a miss is the safe failure.
    var radiusMeters: Double? {
        guard let acres, acres > 0 else { return nil }
        return (acres * 4046.86 / .pi).squareRoot()
    }

    static let reachFactor = 1.5
    /// Ramps sit on the shore, and WDFW's point is not always the lake's centre.
    static let reachPaddingMeters = 400.0

    /// The one lake a launch sits on, or nil. Two lakes in reach is nil rather
    /// than the nearer one: showing the wrong lake's facts is worse than none.
    static func match(facilityName: String, at point: LonLat, in lakes: [Lake]) -> Lake? {
        let inReach = lakes.filter { lake in
            guard let radius = lake.radiusMeters else { return false }
            return distanceMeters(point, lake.coordinate) <= reachFactor * radius + reachPaddingMeters
        }
        guard inReach.count == 1, let lake = inReach.first,
              namesAgree(facility: facilityName, lake: lake.name) else { return nil }
        return lake
    }

    static let ignoredWords: Set<String> = [
        "lake", "lakes", "pond", "ponds", "reservoir", "the",
        "upper", "lower", "north", "south", "east", "west", "of",
    ]

    /// A launch named for a lake must name *this* lake. Distance alone matched
    /// Lyle Lake's launch to Herman Lake. Loose on purpose: Steel/Steele,
    /// Saint/St. and Tim/Tims are one lake each.
    static func namesAgree(facility: String, lake: String) -> Bool {
        guard facility.range(of: #"\b(lake|lakes|pond|ponds|reservoir)\b"#,
                             options: [.regularExpression, .caseInsensitive]) != nil else { return true }
        let facilityTokens = tokens(facility)
        let lakeTokens = tokens(lake)
        // "North Lake" is all ignored words; compare it whole instead.
        if facilityTokens.isEmpty || lakeTokens.isEmpty {
            return words(facility) == words(lake)
        }
        return facilityTokens.contains { a in
            lakeTokens.contains { b in a == b || (a.count >= 3 && b.count >= 3 && withinOneEdit(a, b)) }
        }
    }

    private static func words(_ name: String) -> [String] {
        name.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "saint", with: "st")
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }

    private static func tokens(_ name: String) -> Set<String> {
        Set(words(name)
            .filter { !ignoredWords.contains($0) }
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 })
    }

    private static func withinOneEdit(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        if x == y { return true }
        if abs(x.count - y.count) > 1 { return false }
        if x.count == y.count { return zip(x, y).filter { $0 != $1 }.count == 1 }
        let (short, long) = x.count < y.count ? (x, y) : (y, x)
        return long.indices.contains { Array(long[..<$0] + long[($0 + 1)...]) == short }
    }

    /// Great-circle metres. Launch-to-lake distances run to kilometres, where the
    /// equirectangular shortcut `River` uses would start to drift.
    static func distanceMeters(_ a: LonLat, _ b: LonLat) -> Double {
        let r = 6_371_000.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, h.squareRoot()))
    }
}
