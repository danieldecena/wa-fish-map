import CoreLocation

/// The answer to "is this site in a Marine Protected Area?". `unavailable` is a
/// first-class outcome: the layer is live-only, and a failed fetch must not read
/// back as a clean site.
enum ProtectedAreaCheck: Equatable {
    case inside(ProtectedArea)
    case clear
    case unavailable
}

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
    /// Every ring of the source geometry — see `MarineArea.rings`; the same
    /// packing (multi-part Polygon, or MultiPolygon) shows up on this layer too.
    let rings: [[LonLat]]
    /// `rings` grouped into outer boundaries and their holes, computed once at
    /// init — see `MarineArea.ringGroups` for why this must not be recomputed
    /// on every rating-colour change.
    let ringGroups: [LonLat.RingGroup]

    /// The largest ring by vertex count, ties keeping the first. Stands in
    /// wherever a single ring is needed (predates multi-ring areas).
    var polygon: [LonLat] {
        var best = rings.first ?? []
        for ring in rings.dropFirst() where ring.count > best.count { best = ring }
        return best
    }

    /// Live layer 4 stores the citation bare ("220-330-180"); render it as a WAC.
    var wacCitation: String {
        let trimmed = wac.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.uppercased().hasPrefix("WAC") ? trimmed : "WAC \(trimmed)"
    }

    /// Two of the 44 live areas are named "Marine Area 12", which collides with the
    /// app's own marine-area concept — a marine area is not a protected area. On a row
    /// whose job is to name what you are standing in, those lead with the type instead.
    var hasGenericName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.hasPrefix("marine area")
            || trimmed.allSatisfy { $0.isNumber || $0 == "-" || $0 == " " }
    }

    /// "Inside Golden Gardens", or "Inside an Octopus Preserve" when the name is generic.
    var headline: String {
        guard hasGenericName, !type.isEmpty else { return "Inside \(name)" }
        let article = "aeiou".contains(type.lowercased().first ?? "x") ? "an" : "a"
        return "Inside \(article) \(type)"
    }

    /// The subject the detail line opens with — whichever of type/name the headline
    /// did not use, so neither is lost.
    private var detailSubject: String {
        hasGenericName && !type.isEmpty ? name : type
    }

    /// What WDFW's own designation means, by type. Only the four prohibitive types
    /// carry a restriction claim; anything else — including a type WDFW adds later —
    /// asserts no rule and routes the reader to WDFW.
    var restrictionSentence: String {
        switch type {
        case "Marine Preserve", "Conservation Area", "Octopus Preserve", "Urchin and Cucumber":
            "Fishing or shellfishing may be prohibited or limited here."
        case "Voluntary":
            "WDFW asks fishers to voluntarily avoid this area."
        case "Health Closure":
            "This is a public-health closure, not a fishing rule. Check WDFW before harvesting here."
        default:
            "WDFW designates this area. Check WDFW for what applies here."
        }
    }

    /// The full sentence the sheet renders. Drops the citation cleanly when WDFW's
    /// WAC field is empty, rather than shipping "Marine Preserve — . Fishing…".
    var detailLine: String {
        let citation = wacCitation
        let subject = detailSubject
        let lead = switch (subject.isEmpty, citation.isEmpty) {
        case (false, false): "\(subject) — \(citation). "
        case (false, true): "\(subject). "
        case (true, false): "\(citation). "
        case (true, true): ""
        }
        return lead + restrictionSentence
    }

    var mapCoordinates: [CLLocationCoordinate2D] {
        polygon.map(\.clLocationCoordinate)
    }

    /// Same even-odd, multi-ring containment as `MarineArea.contains(_:)` — one
    /// shared implementation.
    func contains(_ point: LonLat) -> Bool {
        LonLat.rings(rings, contains: point)
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

    /// Single-ring convenience — kept for callers (and tests) predating
    /// multi-ring areas.
    init(name: String, type: String, wac: String, detailURL: URL?, polygon: [LonLat]) {
        self.init(name: name, type: type, wac: wac, detailURL: detailURL, rings: [polygon])
    }

    init(name: String, type: String, wac: String, detailURL: URL?, rings: [[LonLat]]) {
        self.name = name
        self.type = type
        self.wac = wac
        self.detailURL = detailURL
        self.rings = rings
        self.ringGroups = LonLat.groupRings(rings)
    }

    init?(feature: GeoJSONFeature<Properties>) {
        guard let name = feature.properties.name, !name.isEmpty else { return nil }
        let rawRings: [[[Double]]]
        switch feature.geometry {
        case .polygon(let rings): rawRings = rings
        case .multiPolygon(let polygons): rawRings = polygons.flatMap { $0 }
        default: return nil
        }
        let parsedRings: [[LonLat]] = rawRings.compactMap { ring in
            let raw: [LonLat] = ring.compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return LonLat(longitude: pair[0], latitude: pair[1])
            }
            let coords = LonLat.droppingClosingVertex(raw)
            return coords.count >= 3 ? coords : nil
        }
        guard !parsedRings.isEmpty else { return nil }
        self.name = name
        type = feature.properties.type ?? ""
        wac = feature.properties.wac ?? ""
        detailURL = feature.properties.detailURL.flatMap(URL.init(string:))
        rings = parsedRings
        ringGroups = LonLat.groupRings(parsedRings)
    }
}
