import MapKit
import Testing
@testable import WAFishMap

struct SiteAnnotationTests {
    @Test func anAnnotationCarriesItsSiteIdentityUnchanged() {
        let site = AccessSite(
            facilityName: "Boston Harbor", countyName: "Thurston",
            hasLaunch: true, launchSurface: .concrete, hasRestrooms: true,
            hasCamping: false,
            ada: AccessSite.ADAAccess(parking: false, restroom: false, dock: false, boatLaunch: false),
            openDates: "", publicNotes: "",
            directions: "", coordinate: LonLat(longitude: -122.90, latitude: 47.10)
        )
        let a = SiteAnnotation(site: site, rating: .excellent)
        #expect(a.id == site.id)
        #expect(a.title == "Boston Harbor")
        #expect(a.kind == .launch)
        #expect(abs(a.coordinate.latitude - 47.10) < 0.0001)
    }

    @Test func aPierAnnotationCarriesItsPierIdentityUnchanged() {
        let pier = FishingPier(
            name: "Des Moines Pier", countyName: "King", websiteURL: "",
            coordinate: LonLat(longitude: -122.33, latitude: 47.40)
        )
        let a = SiteAnnotation(pier: pier)
        #expect(a.id == pier.id)
        #expect(a.title == "Des Moines Pier")
        #expect(a.kind == .pier)
        #expect(abs(a.coordinate.latitude - 47.40) < 0.0001)
    }
}

struct ClusterClosureTests {
    private func pin(_ rating: FishingRating?, flagged: Bool) -> SiteAnnotation {
        SiteAnnotation(
            pier: FishingPier(name: "P", countyName: "King", websiteURL: "",
                              coordinate: LonLat(longitude: -122.33, latitude: 47.40)),
            rating: rating, closurePlausible: flagged
        )
    }

    @Test func outlinedWhenEveryTopRatedMemberIsFlagged() {
        #expect(SiteClusterView.closurePlausible(of: [pin(.good, flagged: true), pin(.fair, flagged: false)]))
    }

    @Test func solidWhenAnyTopRatedMemberIsUnflagged() {
        #expect(!SiteClusterView.closurePlausible(of: [pin(.good, flagged: true), pin(.good, flagged: false)]))
    }
}
