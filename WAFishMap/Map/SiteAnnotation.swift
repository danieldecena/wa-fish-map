import MapKit

/// `MKAnnotation` wrapper around `AccessSite` / `FishingPier` for the MapKit
/// migration. `id` must equal the source model's `id` exactly — the map
/// delegate hands it straight back to `model.selectedSiteID`.
final class SiteAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let rating: FishingRating?
    let kind: Kind
    /// The rating rests on a season that may be closed this month. Drawn as a
    /// warning badge on the marker (`SiteMarkerView.applyClosureBadge`), so the
    /// marker keeps its rating colour at full strength: never gray, which
    /// already means "no guidance".
    let closurePlausible: Bool
    /// The facility itself is closed (WDFW listing), not just its season.
    let isClosed: Bool

    enum Kind: CaseIterable {
        case launch, shore, pier

        var spokenName: String {
            switch self {
            case .launch: "Boat launch"
            case .shore: "Shore access"
            case .pier: "Fishing pier"
            }
        }
    }

    /// What VoiceOver reads after the pin's name. The pin's colour and outline
    /// carry the rating and the closure flag, and neither reaches a VoiceOver
    /// user without this.
    var spokenSummary: String {
        if isClosed { return "\(kind.spokenName), closed per WDFW" }
        var parts = [kind.spokenName, rating.map { "rated \($0.label)" } ?? "no seasonal guidance"]
        if closurePlausible { parts.append("season may be closed, verify with WDFW") }
        return parts.joined(separator: ", ")
    }

    init(site: AccessSite, rating: FishingRating?, closurePlausible: Bool = false) {
        self.id = site.id
        self.coordinate = site.mapCoordinate
        self.title = site.facilityName
        self.rating = rating
        self.kind = site.hasLaunch ? .launch : .shore
        self.closurePlausible = closurePlausible
        self.isClosed = false
    }

    init(pier: FishingPier, rating: FishingRating? = nil, closurePlausible: Bool = false) {
        self.id = pier.id
        self.coordinate = pier.mapCoordinate
        self.title = pier.name
        // A closed pier carries no rating, so it cannot colour a cluster.
        self.rating = pier.isClosed ? nil : rating
        self.kind = .pier
        self.closurePlausible = pier.isClosed ? false : closurePlausible
        self.isClosed = pier.isClosed
    }
}
