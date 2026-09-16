import Testing
@testable import WAFishMap

struct WaterbodyResolverTests {
    private static let river = River(
        name: "Test River", streamOrder: 4, lengthKm: 1,
        lines: [[LonLat(longitude: -122.000, latitude: 47.500),
                 LonLat(longitude: -121.990, latitude: 47.500)]]
    )
    private static let guide = FreshwaterGuide(
        species: [], waterbodySites: ["Test Lake": ["Lakeside Ramp"]]
    )
    private static let nearRiver = LonLat(longitude: -121.995, latitude: 47.5005)

    @Test func anUncuratedRampBesideARiverResolvesToTheRiver() {
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: Self.nearRiver, rivers: [Self.river]) == "Test River")
    }

    /// A lake launch near an inlet river must keep the lake.
    @Test func theCuratedListBeatsANearbyRiver() {
        #expect(Self.guide.waterbody(forFacility: "Lakeside Ramp", at: Self.nearRiver, rivers: [Self.river]) == "Test Lake")
    }

    @Test func anUncuratedRampFarFromEveryRiverResolvesToNothing() {
        let far = LonLat(longitude: -121.995, latitude: 47.509)
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: far, rivers: [Self.river]) == nil)
    }
}
