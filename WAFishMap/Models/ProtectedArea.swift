import CoreLocation

/// A WDFW Marine Protected Area (MapServer layer 4): the geography of a preserve
/// or conservation area. Purely a polygon plus its WAC citation — the app renders
/// where it is and links WDFW, and never states the rule itself.
struct ProtectedArea: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    /// Free-form: "Marine Preserve", "Conservation Area", "Octopus Preserve" today.
    /// Kept a String because WDFW adds types.
    let type: String
    let wac: String
    let detailURL: URL?
    let polygon: [LonLat]

    /// Live layer 4 stores the citation bare ("220-330-180"); render it as a WAC.
    var wacCitation: String {
        let trimmed = wac.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.uppercased().hasPrefix("WAC") ? trimmed : "WAC \(trimmed)"
    }

    var mapCoordinates: [CLLocationCoordinate2D] {
        polygon.map(\.clLocationCoordinate)
    }

    /// Same ray-cast as `MarineArea.contains(_:)` — one shared implementation.
    func contains(_ point: LonLat) -> Bool {
        LonLat.polygon(polygon, contains: point)
    }

    struct Properties: Decodable {
        let name: String?
        let type: String?
        let wac: String?
        let detailURL: String?

        enum CodingKeys: String, CodingKey {
            case name = "MPA_Name"
            case type = "TypeOfMPA"
            case wac = "WAC"
            case detailURL = "DetailedInfoURL"
        }
    }

    init(name: String, type: String, wac: String, detailURL: URL?, polygon: [LonLat]) {
        self.name = name
        self.type = type
        self.wac = wac
        self.detailURL = detailURL
        self.polygon = polygon
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard case .polygon(let rings) = feature.geometry,
              let outer = rings.first,
              let name = feature.properties.name, !name.isEmpty else { return nil }
        let raw: [LonLat] = outer.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return LonLat(longitude: pair[0], latitude: pair[1])
        }
        let coords = LonLat.droppingClosingVertex(raw)
        guard coords.count >= 3 else { return nil }
        self.name = name
        type = feature.properties.type ?? ""
        wac = feature.properties.wac ?? ""
        detailURL = feature.properties.detailURL.flatMap(URL.init(string:))
        polygon = coords
    }
}
