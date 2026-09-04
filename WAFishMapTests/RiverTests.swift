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
