import CoreLocation

enum LaunchSurface: Int, Equatable, Sendable {
    case unknown = 0
    case concrete = 1
    case gravel = 2
    case hand = 3
    case unimproved = 4

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .concrete: "Concrete"
        case .gravel: "Gravel"
        case .hand: "Hand"
        case .unimproved: "Unimproved"
        }
    }

    init(wdfwValue: Int?) {
        self = LaunchSurface(rawValue: wdfwValue ?? 0) ?? .unknown
    }
}

struct AccessSite: Identifiable, Equatable, Sendable {
    var id: String { "\(facilityName)|\(coordinate.longitude)|\(coordinate.latitude)" }
    let facilityName: String
    let countyName: String
    let hasLaunch: Bool
    let launchSurface: LaunchSurface
    let hasRestrooms: Bool
    let directions: String
    let coordinate: LonLat

    var mapCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }

    struct Properties: Decodable {
        let facilityName: String
        let countyName: String
        let launch: Int
        let launchType: Int?
        let restrooms: Int?
        let directions: String?

        enum CodingKeys: String, CodingKey {
            case facilityName = "FacilityName"
            case countyName = "CountyName"
            case launch = "Launch"
            case launchType = "LaunchType"
            case restrooms = "Restrooms"
            case directions = "Directions"
        }
    }

    init(
        facilityName: String,
        countyName: String,
        hasLaunch: Bool,
        launchSurface: LaunchSurface,
        hasRestrooms: Bool,
        directions: String,
        coordinate: LonLat
    ) {
        self.facilityName = facilityName
        self.countyName = countyName
        self.hasLaunch = hasLaunch
        self.launchSurface = launchSurface
        self.hasRestrooms = hasRestrooms
        self.directions = directions
        self.coordinate = coordinate
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard case .point(let longitude, let latitude)? = feature.geometry else { return nil }
        let props = feature.properties
        facilityName = props.facilityName
        countyName = props.countyName
        hasLaunch = props.launch == 1
        launchSurface = LaunchSurface(wdfwValue: props.launchType)
        hasRestrooms = (props.restrooms ?? 0) == 1
        directions = props.directions ?? ""
        coordinate = LonLat(longitude: longitude, latitude: latitude)
    }
}
