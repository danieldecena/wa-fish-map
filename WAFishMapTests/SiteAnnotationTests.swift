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

struct ClosedPierTests {
    private func pier(_ name: String) -> FishingPier {
        FishingPier(name: name, countyName: "Kitsap", websiteURL: "",
                    coordinate: LonLat(longitude: -122.5, latitude: 47.5))
    }

    @Test func aPierNamedClosedIsClosedAndCarriesNoRating() {
        let closed = pier("Harper Pier (Yukon Harbor) (CLOSED)")
        #expect(closed.isClosed)
        let a = SiteAnnotation(pier: closed, rating: .excellent, closurePlausible: true)
        #expect(a.isClosed)
        #expect(a.rating == nil)
        #expect(!a.closurePlausible)
    }

    @Test func anOpenPierKeepsItsRating() {
        let open = pier("Des Moines Pier")
        #expect(!open.isClosed)
        #expect(SiteAnnotation(pier: open, rating: .good).rating == .good)
    }

    @Test func aClosedPierDoesNotColourItsCluster() {
        let members = [SiteAnnotation(pier: pier("A (CLOSED)"), rating: .excellent),
                       SiteAnnotation(pier: pier("B"), rating: .fair)]
        #expect(SiteClusterView.bestRating(of: members) == .fair)
    }
}

struct DirectionsButtonTests {
    @Test func theLinkAsksAppleMapsForDrivingDirectionsToTheSpot() throws {
        let url = try #require(DirectionsButton.url(
            name: "Harper Pier", coordinate: LonLat(longitude: -122.52, latitude: 47.51)))
        #expect(url.absoluteString
            == "https://maps.apple.com/directions?destination=47.51,-122.52&mode=driving")
    }
}

struct PinSpokenSummaryTests {
    private func pier(_ name: String) -> FishingPier {
        FishingPier(name: name, countyName: "King", websiteURL: "",
                    coordinate: LonLat(longitude: -122.4, latitude: 47.3))
    }

    @Test func aRatedPinSaysWhatItIsAndItsRating() {
        #expect(SiteAnnotation(pier: pier("Redondo Pier"), rating: .good).spokenSummary
            == "Fishing pier, rated Good")
    }

    @Test func theOutlineIsSpokenToo() {
        let a = SiteAnnotation(pier: pier("Redondo Pier"), rating: .fair, closurePlausible: true)
        #expect(a.spokenSummary == "Fishing pier, rated Fair, season may be closed, verify with WDFW")
    }

    @Test func aClosedPierSaysClosedAndNothingElse() {
        let a = SiteAnnotation(pier: pier("Harper Pier (CLOSED)"), rating: .excellent, closurePlausible: true)
        #expect(a.spokenSummary == "Fishing pier, closed per WDFW")
    }

    @Test func anUnratedPinSaysSoRatherThanNothing() {
        #expect(SiteAnnotation(pier: pier("Lake Pier")).spokenSummary == "Fishing pier, no seasonal guidance")
    }

    /// One fixed step up for every cluster (chosen over count-based sizing on
    /// 2026-09-16): larger than a single pin, modest enough not to cover water.
    ///
    /// Stated against the pin, not against 1. The thresholds were absolute
    /// while a pin drew at MKMarkerAnnotationView's own size; once pins were
    /// scaled to 0.8 so they stopped covering place labels, a cluster at 0.95
    /// was still a step above a pin but no longer above 1, and this failed
    /// while the behaviour it names was correct.
    @Test func aClusterIsOneModestSizeUpFromAPin() {
        #expect(SiteClusterView.scale > MarkerMetrics.pin)
        #expect(SiteClusterView.scale <= MarkerMetrics.pin * 1.3)
    }

    @Test func aClusterReadsItsBestRating() {
        let members = [SiteAnnotation(pier: pier("A"), rating: .fair), SiteAnnotation(pier: pier("B"), rating: .good)]
        #expect(SiteClusterView.spokenSummary(of: members) == "best rated Good")
        #expect(SiteClusterView.spokenSummary(of: [SiteAnnotation(pier: pier("C"))]) == "no seasonal guidance")
    }
}
