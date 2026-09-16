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
