import MapKit
import Testing
@testable import WAFishMap

/// A pin's rating is carried by its tint alone, which VoiceOver cannot see. The
/// marker has to say it in words, and so does a cluster, whose count is a glyph.
@MainActor
struct MarkerAccessibilityTests {
    private func site(_ name: String) -> AccessSite {
        AccessSite(facilityName: name, countyName: "Thurston", hasLaunch: true,
                   launchSurface: .gravel, hasRestrooms: false, directions: "",
                   coordinate: LonLat(longitude: -122.9, latitude: 47.14))
    }

    @Test func aRatedPinSpeaksItsNameAndRating() {
        let view = SiteMarkerView(annotation: SiteAnnotation(site: site("Boston Harbor"), rating: .good),
                                  reuseIdentifier: nil)
        #expect(view.isAccessibilityElement)
        #expect(view.accessibilityLabel == "Boston Harbor")
        #expect(view.accessibilityValue == FishingRating.good.label)
    }

    @Test func anUnratedPinSaysNoData() {
        let view = SiteMarkerView(annotation: SiteAnnotation(site: site("Tiger Lake"), rating: nil),
                                  reuseIdentifier: nil)
        #expect(view.accessibilityValue == "No data")
    }

    @Test func aClusterSpeaksItsCountAndBestRating() {
        let members = [SiteAnnotation(site: site("A"), rating: .fair),
                       SiteAnnotation(site: site("B"), rating: .excellent),
                       SiteAnnotation(site: site("C"), rating: nil)]
        let view = SiteClusterView(annotation: MKClusterAnnotation(memberAnnotations: members),
                                   reuseIdentifier: nil)
        #expect(view.isAccessibilityElement)
        #expect(view.accessibilityLabel == "3 sites")
        #expect(view.accessibilityValue == "Best: \(FishingRating.excellent.label)")
    }
}
