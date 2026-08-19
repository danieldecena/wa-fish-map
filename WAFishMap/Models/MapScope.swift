import Foundation

enum MapScope {
    /// v1 slice. To expand, add names here — URLs and filters follow.
    static let marineAreaNames: Set<String> = ["13"]
    static let countyNames: Set<String> = ["Thurston"]

    static let cameraCenter = LonLat(longitude: -122.8165, latitude: 47.1203)
    static let cameraSpanDegrees: Double = 0.45

    private static let mapServer = "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/FP_Projects/MajorFishingArea/MapServer"

    static var marineAreasURL: URL {
        var components = URLComponents(string: "\(mapServer)/6/query")!
        let names = marineAreaNames.sorted().map { "'\($0)'" }.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "where", value: "AreaName IN (\(names))"),
            URLQueryItem(name: "outFields", value: "AreaName,AreaTitle,WAC"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "maxAllowableOffset", value: "0.002"),
        ]
        return components.url!
    }

    static var accessSitesURL: URL {
        var components = URLComponents(string: "\(mapServer)/0/query")!
        let names = countyNames.sorted().map { "'\($0)'" }.joined(separator: ",")
        components.queryItems = [
            URLQueryItem(name: "where", value: "Launch=1 AND CountyName IN (\(names))"),
            URLQueryItem(name: "outFields", value: "FacilityName,CountyName,Launch,LaunchType,Restrooms,Directions"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "outSR", value: "4326"),
        ]
        return components.url!
    }

    static func filter(marineAreas: [MarineArea]) -> [MarineArea] {
        marineAreas.filter { marineAreaNames.contains($0.areaName) }
    }

    static func filter(accessSites: [AccessSite]) -> [AccessSite] {
        accessSites.filter { countyNames.contains($0.countyName) && $0.hasLaunch }
    }
}
