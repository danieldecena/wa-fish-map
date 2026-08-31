import Foundation

enum MapScope {
    /// Fallback camera used only until the live statewide data loads and the map
    /// auto-fits to it (see `FishingMapView`). Roughly centered on Washington.
    static let cameraCenter = LonLat(longitude: -120.7, latitude: 47.4)
    static let cameraSpanDegrees: Double = 6.0

    private static let mapServer = "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/FP_Projects/MajorFishingArea/MapServer"

    /// All 17 marine-area polygons statewide.
    static var marineAreasURL: URL {
        var components = URLComponents(string: "\(mapServer)/6/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "outFields", value: "AreaName,AreaTitle,WAC"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "maxAllowableOffset", value: "0.002"),
        ]
        return components.url!
    }

    /// All statewide water-access launches, with the richer facility fields.
    static var accessSitesURL: URL {
        var components = URLComponents(string: "\(mapServer)/0/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "Launch=1"),
            URLQueryItem(
                name: "outFields",
                value: "FacilityName,CountyName,Launch,LaunchType,Restrooms,Directions,OpenDates,Camping,PublicNotes,ADAParking,ADARestroom,ADADock,ADABoatLaunch"
            ),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
        ]
        return components.url!
    }

    /// Statewide: keep every marine area.
    static func filter(marineAreas: [MarineArea]) -> [MarineArea] {
        marineAreas
    }

    /// Statewide: keep every site that actually has a launch.
    static func filter(accessSites: [AccessSite]) -> [AccessSite] {
        accessSites.filter(\.hasLaunch)
    }
}
