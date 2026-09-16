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

    /// A creek's name repeats across the state, so it must never become a
    /// waterbody key, even with the ramp sitting right on it.
    @Test func aRampOnACreekResolvesToNothing() {
        let creek = River(name: "Rock Creek", streamOrder: 3, lengthKm: 1,
                          lines: Self.river.lines, id: "Rock Creek@-122.000,47.500", kind: .creek)
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: Self.nearRiver, rivers: [creek]) == nil)
    }

    /// A note keyed "Green River" cannot say which Green River, so a split run
    /// never resolves, even the gauged one.
    @Test func aRampOnASplitRiverResolvesToNothing() {
        let split = River(name: "Test River", streamOrder: 4, lengthKm: 1, lines: Self.river.lines,
                          id: "Test River@-122.000,47.500", gauged: true)
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: Self.nearRiver, rivers: [split]) == nil)
    }

    @Test func anUncuratedRampFarFromEveryRiverResolvesToNothing() {
        let far = LonLat(longitude: -121.995, latitude: 47.509)
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: far, rivers: [Self.river]) == nil)
    }
}
