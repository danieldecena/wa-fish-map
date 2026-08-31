import CoreLocation

/// A public fishing pier (WDFW MapServer layer 1). The layer is a joined view, so its
/// GeoJSON property keys are fully qualified (e.g. `GeoWeb.dbo.Fish_MapsPiers_V.PierName`).
struct FishingPier: Identifiable, Equatable, Sendable {
    var id: String { "pier|\(name)|\(coordinate.longitude)|\(coordinate.latitude)" }
    let name: String
    let countyName: String
    let websiteURL: String
    let coordinate: LonLat

    var mapCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }

    struct Properties: Decodable {
        let name: String
        let countyName: String
        let websiteURL: String

        enum CodingKeys: String, CodingKey {
            case name = "GeoWeb.dbo.Fish_MapsPiers_V.PierName"
            case countyName = "GeoWeb.dbo.Fish_MapsPiers_V.CountyFIPSName"
            case websiteURL = "GeoWeb.dbo.Fish_MapsPiers_V.WebsiteURL"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? c.decodeIfPresent(String.self, forKey: .name) ?? nil) ?? ""
            countyName = (try? c.decodeIfPresent(String.self, forKey: .countyName) ?? nil) ?? ""
            websiteURL = (try? c.decodeIfPresent(String.self, forKey: .websiteURL) ?? nil) ?? ""
        }
    }

    init(name: String, countyName: String, websiteURL: String, coordinate: LonLat) {
        self.name = name
        self.countyName = countyName
        self.websiteURL = websiteURL
        self.coordinate = coordinate
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard case .point(let longitude, let latitude) = feature.geometry else { return nil }
        let props = feature.properties
        name = props.name.isEmpty ? "Public Pier" : props.name
        countyName = props.countyName
        websiteURL = props.websiteURL
        coordinate = LonLat(longitude: longitude, latitude: latitude)
    }
}
