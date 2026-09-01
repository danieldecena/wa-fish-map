import CoreLocation
import Foundation

struct TideStation: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let coordinate: LonLat

    static func nearest(to point: LonLat, in stations: [TideStation]) -> TideStation? {
        stations.min { a, b in
            a.coordinate.distance(to: point) < b.coordinate.distance(to: point)
        }
    }
}

extension TideStation: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        coordinate = LonLat(
            longitude: try c.decode(Double.self, forKey: .lng),
            latitude: try c.decode(Double.self, forKey: .lat)
        )
    }
}

struct TideExtreme: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case high, low
        var label: String { self == .high ? "High" : "Low" }
    }

    let time: Date
    let heightFeet: Double
    let kind: Kind
}

struct TideTable: Equatable, Sendable {
    let station: TideStation
    let extremes: [TideExtreme]

    /// First extreme strictly after `date`, for highlighting the next turn.
    func indexOfNext(after date: Date) -> Int? {
        extremes.firstIndex { $0.time > date }
    }

    var noaaURL: URL {
        URL(string: "https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=\(station.id)")!
    }
}

extension LonLat {
    func distance(to other: LonLat) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
