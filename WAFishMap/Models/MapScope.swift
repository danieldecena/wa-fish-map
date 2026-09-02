import Foundation

enum MapScope {
    /// Fallback camera used only until the live statewide data loads and the map
    /// auto-fits to it (see `FishingMapView`). Roughly centered on Washington.
    static let cameraCenter = LonLat(longitude: -120.7, latitude: 47.4)

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

    /// All statewide water-access sites — boat launches AND shore/bank access — with the
    /// richer facility fields.
    static var accessSitesURL: URL {
        var components = URLComponents(string: "\(mapServer)/0/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(
                name: "outFields",
                value: "FacilityName,CountyName,Launch,LaunchType,Restrooms,Directions,OpenDates,Camping,PublicNotes,ADAParking,ADARestroom,ADADock,ADABoatLaunch"
            ),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
        ]
        return components.url!
    }

    /// All statewide public fishing piers (layer 1, a joined view — needs `outFields=*`).
    static var piersURL: URL {
        var components = URLComponents(string: "\(mapServer)/1/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "outFields", value: "*"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
        ]
        return components.url!
    }

    /// All 44 Marine Protected Areas statewide (layer 4) — preserves and
    /// conservation areas, with their WAC citation and WDFW detail page.
    static var protectedAreasURL: URL {
        var components = URLComponents(string: "\(mapServer)/4/query")!
        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "outFields", value: "MPA_Name,TypeOfMPA,WAC,DetailedInfoURL"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
        ]
        return components.url!
    }

    /// Statewide: keep every marine area.
    static func filter(marineAreas: [MarineArea]) -> [MarineArea] {
        marineAreas
    }

    /// Statewide: keep every water-access site (launches and shore access alike).
    static func filter(accessSites: [AccessSite]) -> [AccessSite] {
        accessSites
    }
}
