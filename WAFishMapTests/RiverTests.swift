import Foundation
import Testing
@testable import WAFishMap

/// Two jobs. The first half is ordinary parsing. The second is a data-quality
/// gate over the shipped `rivers.json`, in the spirit of `NoteScopeTests`: the
/// generator's FTYPE filter once dropped the Skagit, Skykomish and Snake
/// entirely and reduced the Columbia to an 8.8km fragment, and the file still
/// looked healthy — 315 rivers with a plausible stream-order spread. Only naming
/// the rivers that must be there catches that.
struct RiverTests {
    @Test func multiLineStringDecodesEveryRun() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature",
           "geometry":{"type":"MultiLineString","coordinates":[
             [[-121.80,48.40],[-121.70,48.42]],
             [[-121.60,48.45],[-121.50,48.47],[-121.40,48.50]]
           ]},
           "properties":{"name":"Skagit River","streamOrder":6,"lengthKm":191.0}}
        ]}
        """.data(using: .utf8)!

        let rivers = try RiverLoader.rivers(from: json)
        #expect(rivers.count == 1)
        let skagit = rivers[0]
        #expect(skagit.name == "Skagit River")
        #expect(skagit.id == "Skagit River")
        #expect(skagit.streamOrder == 6)
        #expect(skagit.lines.count == 2)
        #expect(skagit.lines[1].count == 3)
        // Longitude first in GeoJSON; the app has swapped these before.
        #expect(skagit.lines[0][0] == LonLat(longitude: -121.80, latitude: 48.40))
        #expect(skagit.mapLines[0][0].latitude == 48.40)
        #expect(skagit.mapLines[0][0].longitude == -121.80)
    }

    @Test func aBareLineStringIsAcceptedAsASingleRun() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature",
           "geometry":{"type":"LineString","coordinates":[[-122.0,47.0],[-121.9,47.1]]},
           "properties":{"name":"Green River","streamOrder":4,"lengthKm":183.9}}
        ]}
        """.data(using: .utf8)!
        let rivers = try RiverLoader.rivers(from: json)
        #expect(rivers.count == 1)
        #expect(rivers[0].lines.count == 1)
    }

    @Test func aCreekDecodesItsOwnIdAndKind() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-122.0,47.0],[-121.9,47.1]]},
           "properties":{"id":"Rock Creek@-122.000,47.000","kind":"creek","name":"Rock Creek","streamOrder":3,"lengthKm":12.0}},
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-117.9,47.0],[-117.8,47.1]]},
           "properties":{"id":"Rock Creek@-117.900,47.000","kind":"creek","name":"Rock Creek","streamOrder":4,"lengthKm":77.0}}
        ]}
        """.data(using: .utf8)!
        let creeks = try RiverLoader.rivers(from: json)
        #expect(creeks.map(\.kind) == [.creek, .creek])
        #expect(Set(creeks.map(\.id)).count == 2)
        #expect(creeks.allSatisfy { $0.name == "Rock Creek" })
    }

    /// The control. Without it, "decodes a line" cannot be told apart from
    /// "accepts anything" — a polygon must still be refused.
    @Test func nonLineGeometryIsRefused() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature",
           "geometry":{"type":"Polygon","coordinates":[[[-122.0,47.0],[-121.9,47.0],[-121.9,47.1],[-122.0,47.0]]]},
           "properties":{"name":"Not a river","streamOrder":3,"lengthKm":10.0}}
        ]}
        """.data(using: .utf8)!
        #expect(try RiverLoader.rivers(from: json).isEmpty)
    }

    /// A one-vertex run cannot be stroked; it must be dropped, and a river left
    /// with nothing to draw must not survive as an empty line.
    @Test func runsShorterThanTwoVerticesAreDropped() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature",
           "geometry":{"type":"MultiLineString","coordinates":[[[-122.0,47.0]]]},
           "properties":{"name":"Stub River","streamOrder":2,"lengthKm":9.0}}
        ]}
        """.data(using: .utf8)!
        #expect(try RiverLoader.rivers(from: json).isEmpty)
    }

    @Test func lineWeightRisesWithStreamOrder() {
        func width(_ order: Int) -> CGFloat {
            River(name: "x", streamOrder: order, lengthKm: 1, lines: []).lineWidth
        }
        #expect(width(2) < width(4))
        #expect(width(4) < width(7))
    }

    // MARK: Tap distance

    /// A short east-west run at 47.5N, about 750m long.
    private static let reach = River(
        name: "Test River", streamOrder: 4, lengthKm: 1,
        lines: [[LonLat(longitude: -122.000, latitude: 47.500),
                 LonLat(longitude: -121.990, latitude: 47.500)]]
    )

    @Test func aPointOnTheLineIsEssentiallyZeroAway() throws {
        let onIt = LonLat(longitude: -121.995, latitude: 47.500)
        let distance = try #require(Self.reach.distanceMeters(to: onIt))
        #expect(distance < 1)
    }

    /// The control for the test above. Without a point that is genuinely far,
    /// "measures distance" cannot be told from "always returns zero".
    @Test func aPointOffTheLineMeasuresTheRealGap() throws {
        // 0.0090 degrees of latitude is almost exactly 1km.
        let north = LonLat(longitude: -121.995, latitude: 47.509)
        let distance = try #require(Self.reach.distanceMeters(to: north))
        #expect(distance > 950 && distance < 1050, "got \(distance)m, expected ~1000m")
    }

    /// Past the end of a segment the answer is the distance to the endpoint,
    /// not to the infinite line the segment sits on.
    @Test func beyondTheEndItMeasuresToTheEndpoint() throws {
        let east = LonLat(longitude: -121.980, latitude: 47.500)
        let distance = try #require(Self.reach.distanceMeters(to: east))
        // 0.010 degrees of longitude at 47.5N is about 750m.
        #expect(distance > 700 && distance < 800, "got \(distance)m")
    }

    @Test func theNearestOfTwoRiversWins() throws {
        let far = River(
            name: "Far River", streamOrder: 4, lengthKm: 1,
            lines: [[LonLat(longitude: -122.000, latitude: 47.600),
                     LonLat(longitude: -121.990, latitude: 47.600)]]
        )
        let tap = LonLat(longitude: -121.995, latitude: 47.502)
        let near = try #require(Self.reach.distanceMeters(to: tap))
        let away = try #require(far.distanceMeters(to: tap))
        #expect(near < away)
    }

    @Test func aRiverWithNoDrawableRunHasNoDistance() {
        let empty = River(name: "Empty", streamOrder: 1, lengthKm: 0, lines: [])
        #expect(empty.distanceMeters(to: LonLat(longitude: -122, latitude: 47.5)) == nil)
    }

    // MARK: Nearest river

    private static let other = River(
        name: "Other River", streamOrder: 3, lengthKm: 1,
        lines: [[LonLat(longitude: -122.000, latitude: 47.5020),
                 LonLat(longitude: -121.990, latitude: 47.5020)]]
    )

    @Test func aPointBesideARiverMatchesIt() {
        // ~55m north of Test River.
        let ramp = LonLat(longitude: -121.995, latitude: 47.5005)
        #expect(River.nearest(to: ramp, within: 150, in: [Self.reach])?.name == "Test River")
    }

    /// The control: without a point that must NOT match, "matches" is
    /// indistinguishable from "always returns the first river".
    @Test func aPointAKilometreOffMatchesNothing() {
        let far = LonLat(longitude: -121.995, latitude: 47.509)
        #expect(River.nearest(to: far, within: 150, in: [Self.reach]) == nil)
    }

    /// The bounding-box prefilter must be widened by the match distance, or a
    /// ramp just past a river's end, off both of its axes, is thrown away.
    @Test func aPointPastARiversCornerStillMatches() {
        // ~75m east of the east end and ~78m north: ~108m away, outside the
        // line's own bounds on both axes.
        let ramp = LonLat(longitude: -121.989, latitude: 47.5007)
        #expect(River.nearest(to: ramp, within: 150, in: [Self.reach])?.name == "Test River")
    }

    /// Two rivers in range: the nearer one wins, whatever the array order.
    @Test func theNearerRiverWinsAtAConfluence() {
        // ~167m from Test River, ~56m from Other River (0.002 deg lat apart).
        let point = LonLat(longitude: -121.995, latitude: 47.5015)
        #expect(River.nearest(to: point, within: 300, in: [Self.reach, Self.other])?.name == "Other River")
    }

    // MARK: The shipped resource

    private static func bundled() throws -> [River] {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "rivers", withExtension: "json"))
        return try RiverLoader.rivers(from: Data(contentsOf: url))
    }

    /// Every one of these was absent or a fragment under the StreamRiver-only
    /// filter. They are the known-good input that tells a working build from a
    /// plausible-looking broken one.
    @Test func theBigRiversAreActuallyInTheBundle() throws {
        let names = Set(try Self.bundled().map(\.name))
        for expected in ["Columbia River", "Snake River", "Skagit River",
                         "Skykomish River", "Yakima River", "Cowlitz River",
                         "Methow River", "Chehalis River", "Hoh River",
                         "Wenatchee River"] {
            #expect(names.contains(expected), "\(expected) is missing from rivers.json")
        }
    }

    /// Creeks are in the bundle, split per run: many unrelated creeks share a
    /// name, and merged by name one feature would span the state. Unique ids are
    /// what tap-to-select keys on.
    @Test func creeksShipAsSeparateUniquelyIdentifiedRuns() throws {
        let all = try Self.bundled()
        let creeks = all.filter { $0.kind == .creek }
        #expect(creeks.count > 200, "creeks missing from rivers.json")
        #expect(creeks.contains { $0.name == "Crab Creek" })
        #expect(creeks.filter { $0.name == "Rock Creek" }.count > 1, "same-name creeks were merged")
        #expect(Set(all.map(\.id)).count == all.count, "duplicate river ids")
        #expect(all.filter { $0.kind == .river }.count > 280, "adding creeks lost rivers")
    }

    /// Two unrelated Green Rivers, 150 km apart, once shipped as one feature,
    /// so the King County gauge coloured the Cowlitz County river too. Each is
    /// now its own run, and only the one the gauge sits on owns the name's flow.
    @Test func unrelatedRiversSharingANameShipSeparatelyWithOneGauged() throws {
        let all = try Self.bundled()
        for name in ["Green River", "White River", "Cedar River"] {
            let runs = all.filter { $0.kind == .river && $0.name == name }
            #expect(runs.count >= 2, "\(name) was merged into one feature")
            #expect(runs.allSatisfy { $0.isSplit })
            #expect(runs.filter { $0.gauged }.count == 1, "\(name) must have exactly one gauged run")
        }
        let kingGreen = try #require(all.first { $0.id == "Green River@-122.266,47.376" })
        #expect(kingGreen.gauged)
        // A gap inside one river is not two rivers.
        #expect(all.filter { $0.name == "Chehalis River" }.count == 1)
        #expect(all.filter { $0.name == "Yakima River" }.count == 1)
    }

    @Test func aSplitRunDecodesGaugedAndOnlyTheGaugedRunOwnsTheName() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-122.3,47.4],[-122.2,47.4]]},
           "properties":{"id":"Green River@-122.300,47.400","kind":"river","name":"Green River",
                         "streamOrder":5,"lengthKm":90.0,"gauged":true}},
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-122.6,46.4],[-122.5,46.4]]},
           "properties":{"id":"Green River@-122.600,46.400","kind":"river","name":"Green River",
                         "streamOrder":4,"lengthKm":40.0}},
          {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-121.8,48.4],[-121.7,48.4]]},
           "properties":{"id":"Skagit River","kind":"river","name":"Skagit River",
                         "streamOrder":6,"lengthKm":191.0}}
        ]}
        """.data(using: .utf8)!
        let rivers = try RiverLoader.rivers(from: json)
        #expect(rivers.map { $0.ownsNameGauge } == [true, false, true])
        #expect(rivers.map { $0.isSplit } == [true, true, false])
    }

    /// A fragment passes a name check. Length is what separates the whole
    /// Columbia from the 8.8km of it the broken filter kept.
    @Test func theColumbiaIsTheWholeRiverNotAFragment() throws {
        let columbia = try #require(try Self.bundled().first { $0.name == "Columbia River" })
        #expect(columbia.lengthKm > 500)
        #expect(columbia.streamOrder >= 7)
    }

    @Test func everyBundledRiverHasSomethingToDraw() throws {
        for river in try Self.bundled() {
            #expect(!river.lines.isEmpty, "\(river.name) has no geometry")
            #expect(river.lines.allSatisfy { $0.count >= 2 }, "\(river.name) has a one-point run")
        }
    }

    /// Washington only, like every other layer in the app. The build envelope
    /// reaches into Oregon and Idaho, so the state clip is load-bearing.
    @Test func noRiverSitsEntirelyOutsideWashington() throws {
        for river in try Self.bundled() {
            let points = river.lines.flatMap { $0 }
            let inState = points.contains { point in
                (45.5...49.1).contains(point.latitude)
                    && (-124.9...(-116.9)).contains(point.longitude)
            }
            #expect(inState, "\(river.name) has no vertex in Washington")
        }
    }
}
