import Foundation
import Testing
@testable import WAFishMap

/// A wrong lake puts another lake's facts on a sheet, which breaks the scope
/// promise; a miss shows nothing. So most of these pin refusals. The real pairs
/// come from a 2026-09-16 probe of WDFW launches against WDFW lake points, where
/// distance alone matched Lyle Lake to Herman Lake.
struct LakeTests {
    static func lake(_ name: String, _ lon: Double, _ lat: Double, acres: Double?) -> Lake {
        Lake(name: name, county: "King", longitude: lon, latitude: lat, acres: acres,
             elevationFeet: nil, management: nil, shorelineAccess: nil, boatRamp: nil,
             websiteURL: nil, species: [])
    }

    // MARK: Name check

    @Test(arguments: [
        ("Steel Lake", "Steele Lake"),
        ("Tim Ponds", "Tims Ponds"),
        ("Lake Saint Clair", "St. Clair Lake"),
        ("Devils Lake", "Lost (Devil’s) Lake"),
        ("North Lake", "North Lake"),
        ("Pond 6-Buena", "I-82 Pond 6"),
    ])
    func namesThatAgree(facility: String, lake: String) {
        #expect(Lake.namesAgree(facility: facility, lake: lake))
    }

    @Test(arguments: [
        ("Lyle Lake", "Herman Lake"),
        ("Corral Lake", "Potholes Reservoir"),
        ("North Lake", "South Lake"),
        ("Silver Lake", "North Silver Lake"),
        ("Caliche Lakes", "Upper Caliche Lake"),
        ("Elton Pond", "Elton Pond North"),
    ])
    func namesThatDisagree(facility: String, lake: String) {
        #expect(!Lake.namesAgree(facility: facility, lake: lake))
    }

    /// A launch not named for a lake (Medicare Beach on Potholes) is not checked.
    @Test func aLaunchNotNamedForWaterIsNotNameChecked() {
        #expect(Lake.namesAgree(facility: "Medicare Beach", lake: "Potholes Reservoir"))
    }

    // MARK: Matching

    @Test func aLaunchInReachOfOneLakeMatchesIt() {
        let dolloff = Self.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)
        let launch = LonLat(longitude: -122.284561, latitude: 47.323529)
        #expect(Lake.match(facilityName: "Lake Dolloff", at: launch, in: [dolloff])?.name == "Lake Dolloff")
    }

    @Test func twoLakesInReachMatchNothing() {
        let a = Self.lake("A Lake", -122.000, 47.000, acres: 500)
        let b = Self.lake("B Lake", -122.004, 47.000, acres: 500)
        let between = LonLat(longitude: -122.002, latitude: 47.000)
        #expect(Lake.match(facilityName: "Access", at: between, in: [a, b]) == nil)
    }

    @Test func aLakeWithNoAcreageNeverMatches() {
        let unknown = Self.lake("Mystery Lake", -122.0, 47.0, acres: nil)
        #expect(Lake.match(facilityName: "Mystery Lake", at: LonLat(longitude: -122.0, latitude: 47.0), in: [unknown]) == nil)
    }

    @Test func aLaunchOutOfReachMatchesNothing() {
        // 21 acres -> r ~ 165 m, reach ~ 648 m. This launch is ~2.2 km away.
        let dolloff = Self.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)
        let far = LonLat(longitude: -122.2836, latitude: 47.3428)
        #expect(Lake.match(facilityName: "Lake Dolloff", at: far, in: [dolloff]) == nil)
    }

    @Test func aContradictingNameRefusesAnOtherwiseGoodMatch() {
        let herman = Self.lake("Herman Lake", -119.2030, 46.8900, acres: 60)
        let lyleLaunch = LonLat(longitude: -119.203165, latitude: 46.895406)
        #expect(Lake.match(facilityName: "Herman Lake", at: lyleLaunch, in: [herman]) != nil)
        #expect(Lake.match(facilityName: "Lyle Lake", at: lyleLaunch, in: [herman]) == nil)
    }

    // MARK: The shipped resource

    private static func bundled() throws -> [Lake] {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "lakes", withExtension: "json"))
        return try LakeLoader.lakes(from: Data(contentsOf: url))
    }

    @Test func theBundleHoldsTheStatewideLakeList() throws {
        let lakes = try Self.bundled()
        #expect(lakes.count >= 600)
        let dolloff = try #require(lakes.first { $0.name == "Lake Dolloff" })
        #expect(dolloff.county == "King")
        #expect(!dolloff.species.isEmpty)
    }

    /// Real WDFW launch coordinates (layer 0, 2026-09-16) against the shipped
    /// lakes. Three launches within 2 km of each other in Federal Way, and the
    /// two probe mismatches from eastern Washington, and the Spokane County
    /// Silver Lake launch the direction-word rule stopped matching North Silver.
    @Test(arguments: [
        ("Lake Dolloff", -122.284561, 47.323529, "Lake Dolloff" as String?),
        ("Steel Lake", -122.300005, 47.325877, "Steele Lake"),
        ("North Lake", -122.289173, 47.308077, "North Lake"),
        ("Lyle Lake", -119.203165, 46.895406, nil),
        ("Corral Lake", -119.311142, 46.969255, nil),
        // On Silver Lake (67 m from its NHD shore), 792 m from North Silver
        // Lake's WDFW point and outside Silver Lake's own reach.
        ("Silver Lake", -117.656981, 47.571883, nil),
    ])
    func realLaunchesMatchTheirOwnLake(facility: String, lon: Double, lat: Double, expected: String?) throws {
        let lakes = try Self.bundled()
        let matched = Lake.match(facilityName: facility, at: LonLat(longitude: lon, latitude: lat), in: lakes)
        #expect(matched?.name == expected)
    }
}
