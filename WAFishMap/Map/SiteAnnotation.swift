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
    /// The rating rests on a season that may be closed this month. Drawn as an
    /// outlined marker: never gray, which already means "no guidance".
    let closurePlausible: Bool
    /// The facility itself is closed (WDFW listing), not just its season.
    let isClosed: Bool

    enum Kind: CaseIterable {
        case launch, shore, pier
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
