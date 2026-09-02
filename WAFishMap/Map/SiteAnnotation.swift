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

    enum Kind: CaseIterable {
        case launch, shore, pier
    }

    init(site: AccessSite, rating: FishingRating?) {
        self.id = site.id
        self.coordinate = site.mapCoordinate
        self.title = site.facilityName
        self.rating = rating
        self.kind = site.hasLaunch ? .launch : .shore
    }

    init(pier: FishingPier, rating: FishingRating? = nil) {
        self.id = pier.id
        self.coordinate = pier.mapCoordinate
        self.title = pier.name
        self.rating = rating
        self.kind = .pier
    }
}
