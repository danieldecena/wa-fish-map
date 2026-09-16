import Foundation
import Testing
@testable import WAFishMap

struct MarineAreaTests {
    /// A 2×2 square centered on the origin.
    let square = MarineArea(
        areaName: "T", areaTitle: "Test", wac: "",
        coordinates: [
            LonLat(longitude: -1, latitude: -1),
            LonLat(longitude: 1, latitude: -1),
            LonLat(longitude: 1, latitude: 1),
            LonLat(longitude: -1, latitude: 1),
        ]
    )

    @Test func containsPointInside() {
        #expect(square.contains(LonLat(longitude: 0, latitude: 0)))
        #expect(square.contains(LonLat(longitude: 0.9, latitude: -0.9)))
    }

    @Test func rejectsPointOutside() {
        #expect(!square.contains(LonLat(longitude: 2, latitude: 2)))
        #expect(!square.contains(LonLat(longitude: 0, latitude: 5)))
        #expect(!square.contains(LonLat(longitude: -1.5, latitude: 0)))
    }

    @Test func degeneratePolygonContainsNothing() {
        let line = MarineArea(
            areaName: "L", areaTitle: "", wac: "",
            coordinates: [LonLat(longitude: 0, latitude: 0), LonLat(longitude: 1, latitude: 1)]
        )
        #expect(!line.contains(LonLat(longitude: 0.5, latitude: 0.5)))
    }

    /// Two disjoint square rings in one Polygon — WDFW packs every island and
    /// disjoint part of a marine area as extra rings of the same feature.
    let twoSquares = MarineArea(
        areaName: "T2", areaTitle: "Test", wac: "",
        rings: [
            [LonLat(longitude: -1, latitude: -1), LonLat(longitude: 1, latitude: -1),
             LonLat(longitude: 1, latitude: 1), LonLat(longitude: -1, latitude: 1)],
            [LonLat(longitude: 10, latitude: 10), LonLat(longitude: 12, latitude: 10),
             LonLat(longitude: 12, latitude: 12), LonLat(longitude: 10, latitude: 12)],
        ]
    )

    @Test func containsAPointInEitherDisjointRing() {
        #expect(twoSquares.contains(LonLat(longitude: 0, latitude: 0)))
        #expect(twoSquares.contains(LonLat(longitude: 11, latitude: 11)))
        #expect(!twoSquares.contains(LonLat(longitude: 5, latitude: 5)))
    }

    /// An outer square with an inner hole ring — even-odd containment (toggling
    /// once per ring the point falls inside) excludes the hole and keeps the
    /// ring between the hole and the outer boundary.
    let squareWithHole = MarineArea(
        areaName: "H", areaTitle: "Test", wac: "",
        rings: [
            [LonLat(longitude: -10, latitude: -10), LonLat(longitude: 10, latitude: -10),
             LonLat(longitude: 10, latitude: 10), LonLat(longitude: -10, latitude: 10)],
            [LonLat(longitude: -2, latitude: -2), LonLat(longitude: 2, latitude: -2),
             LonLat(longitude: 2, latitude: 2), LonLat(longitude: -2, latitude: 2)],
        ]
    )

    @Test func excludesTheHoleButKeepsTheRingBetween() {
        #expect(!squareWithHole.contains(LonLat(longitude: 0, latitude: 0)))
        #expect(squareWithHole.contains(LonLat(longitude: 5, latitude: 5)))
        #expect(!squareWithHole.contains(LonLat(longitude: 50, latitude: 50)))
    }

    /// Known-good control: a plain single-ring polygon's containment is
    /// unchanged by the even-odd, multi-ring rewrite.
    @Test func singleRingBehaviourIsUnchanged() {
        #expect(square.contains(LonLat(longitude: 0, latitude: 0)))
        #expect(!square.contains(LonLat(longitude: 2, latitude: 2)))
    }
}

/// The shore snap: WDFW polygons stop at the shoreline and a pier or ramp is
/// recorded at its landward end, just outside.
struct MarineAreaShoreSnapTests {
    /// A 0.1° square near Puget Sound's latitude, so metres are realistic.
    static func square(_ name: String, west: Double) -> MarineArea {
        MarineArea(areaName: name, areaTitle: name, wac: "", coordinates: [
            LonLat(longitude: west, latitude: 47.3), LonLat(longitude: west + 0.1, latitude: 47.3),
            LonLat(longitude: west + 0.1, latitude: 47.4), LonLat(longitude: west, latitude: 47.4),
        ])
    }
    let a = square("A", west: -122.6)
    let b = square("B", west: -122.3)
    /// 1° of longitude at 47.35°N is about 75.4 km.
    let metresPerLonDegree = 111_320.0 * cos(47.35 * .pi / 180)

    @Test func aPointJustOutsideTheShoreSnapsToThatArea() throws {
        let tenMetresEast = LonLat(longitude: -122.5 + 10 / metresPerLonDegree, latitude: 47.35)
        #expect(!a.contains(tenMetresEast))
        #expect(try #require(MarineArea.matching(tenMetresEast, in: [a, b])).areaName == "A")
    }

    @Test func aPointFarInlandMatchesNothing() {
        let halfKilometreEast = LonLat(longitude: -122.5 + 500 / metresPerLonDegree, latitude: 47.35)
        #expect(MarineArea.matching(halfKilometreEast, in: [a, b]) == nil)
    }

    @Test func theSnapStopsAtItsTolerance() {
        let inside = LonLat(longitude: -122.5 + 140 / metresPerLonDegree, latitude: 47.35)
        let outside = LonLat(longitude: -122.5 + 160 / metresPerLonDegree, latitude: 47.35)
        #expect(MarineArea.matching(inside, in: [a]) != nil)
        #expect(MarineArea.matching(outside, in: [a]) == nil)
    }

    @Test func containmentBeatsANearerNeighboursEdge() throws {
        let c = Self.square("C", west: -122.5)   // shares A's east edge
        let justInsideC = LonLat(longitude: -122.5 + 5 / metresPerLonDegree, latitude: 47.35)
        #expect(try #require(MarineArea.matching(justInsideC, in: [a, c])).areaName == "C")
    }

    @Test func theNearestAreaWinsBetweenTwoShores() throws {
        // A's east edge is -122.5, B's west edge is -122.3; this point is nearer B.
        let nearB = LonLat(longitude: -122.3 - 20 / metresPerLonDegree, latitude: 47.35)
        let farA = Self.square("A2", west: -122.3 - 0.1 - 100 / metresPerLonDegree)
        #expect(try #require(MarineArea.matching(nearB, in: [farA, b])).areaName == "B")
    }
}
