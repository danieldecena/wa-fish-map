import CoreLocation

struct LonLat: Equatable, Hashable, Sendable {
    var longitude: Double
    var latitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func droppingClosingVertex(_ coords: [LonLat]) -> [LonLat] {
        guard coords.count >= 2, coords.first == coords.last else { return coords }
        return Array(coords.dropLast())
    }
}
