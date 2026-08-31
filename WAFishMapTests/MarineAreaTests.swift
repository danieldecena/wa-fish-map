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
}
