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
    let hasCamping: Bool
    let ada: ADAAccess
    let openDates: String
    let publicNotes: String
    let directions: String
    let coordinate: LonLat

    var mapCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }

    struct ADAAccess: Equatable, Sendable {
        let parking: Bool
        let restroom: Bool
        let dock: Bool
        let boatLaunch: Bool
        var any: Bool { parking || restroom || dock || boatLaunch }
    }

    struct Properties: Decodable {
        let facilityName: String
        let countyName: String
        let launch: Int
        let launchType: Int?
        let restrooms: Int?
        let camping: Int?
        let adaParking: Int?
        let adaRestroom: Int?
        let adaDock: Int?
        let adaBoatLaunch: Int?
        let openDates: String?
        let publicNotes: String?
        let directions: String?

        enum CodingKeys: String, CodingKey {
            case facilityName = "FacilityName"
            case countyName = "CountyName"
            case launch = "Launch"
            case launchType = "LaunchType"
            case restrooms = "Restrooms"
            case camping = "Camping"
            case adaParking = "ADAParking"
            case adaRestroom = "ADARestroom"
            case adaDock = "ADADock"
            case adaBoatLaunch = "ADABoatLaunch"
            case openDates = "OpenDates"
            case publicNotes = "PublicNotes"
            case directions = "Directions"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            facilityName = try c.decode(String.self, forKey: .facilityName)
            countyName = try c.decode(String.self, forKey: .countyName)
            launch = Self.flag(c, .launch) ?? 0
            launchType = Self.flag(c, .launchType)
            restrooms = Self.flag(c, .restrooms)
            camping = Self.flag(c, .camping)
            adaParking = Self.flag(c, .adaParking)
            adaRestroom = Self.flag(c, .adaRestroom)
            adaDock = Self.flag(c, .adaDock)
            adaBoatLaunch = Self.flag(c, .adaBoatLaunch)
            openDates = try? c.decodeIfPresent(String.self, forKey: .openDates)
            publicNotes = try? c.decodeIfPresent(String.self, forKey: .publicNotes)
            directions = try? c.decodeIfPresent(String.self, forKey: .directions)
        }

        /// WDFW flag fields are usually Int (0/1) but can arrive as Bool or a string
        /// like "Yes"/"1". Coerce tolerantly so one odd row can't fail the whole
        /// statewide decode.
        private static func flag(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
            if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b ? 1 : 0 }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                let t = s.trimmingCharacters(in: .whitespaces).lowercased()
                return (t == "1" || t == "yes" || t == "y" || t == "true") ? 1 : 0
            }
            return nil
        }
    }

    init(
        facilityName: String,
        countyName: String,
        hasLaunch: Bool,
        launchSurface: LaunchSurface,
        hasRestrooms: Bool,
        hasCamping: Bool = false,
        ada: ADAAccess = ADAAccess(parking: false, restroom: false, dock: false, boatLaunch: false),
        openDates: String = "",
        publicNotes: String = "",
        directions: String,
        coordinate: LonLat
    ) {
        self.facilityName = facilityName
        self.countyName = countyName
        self.hasLaunch = hasLaunch
        self.launchSurface = launchSurface
        self.hasRestrooms = hasRestrooms
        self.hasCamping = hasCamping
        self.ada = ada
        self.openDates = openDates
        self.publicNotes = publicNotes
        self.directions = directions
        self.coordinate = coordinate
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard case .point(let longitude, let latitude) = feature.geometry else { return nil }
        let props = feature.properties
        facilityName = props.facilityName
        countyName = props.countyName
        hasLaunch = props.launch == 1
        launchSurface = LaunchSurface(wdfwValue: props.launchType)
        hasRestrooms = (props.restrooms ?? 0) == 1
        hasCamping = (props.camping ?? 0) == 1
        ada = ADAAccess(
            parking: (props.adaParking ?? 0) == 1,
            restroom: (props.adaRestroom ?? 0) == 1,
            dock: (props.adaDock ?? 0) == 1,
            boatLaunch: (props.adaBoatLaunch ?? 0) == 1
        )
        openDates = props.openDates ?? ""
        publicNotes = props.publicNotes ?? ""
        directions = props.directions ?? ""
        coordinate = LonLat(longitude: longitude, latitude: latitude)
    }
}
