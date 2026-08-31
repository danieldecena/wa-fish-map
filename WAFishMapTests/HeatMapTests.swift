import Testing
@testable import WAFishMap

struct HeatMapTests {
    @Test func emptyInputYieldsNoZones() {
        #expect(HeatMap.zones(points: [], cellDegrees: 0.15).isEmpty)
        #expect(HeatMap.zones(points: [(LonLat(longitude: -122, latitude: 47), 1)], cellDegrees: 0).isEmpty)
    }

    @Test func bucketsPointsAndNormalizesToDensestCell() {
        // Three points in one 0.15° cell, one lone point far away.
        let points: [(coord: LonLat, weight: Double)] = [
            (LonLat(longitude: -122.90, latitude: 47.10), 1),
            (LonLat(longitude: -122.89, latitude: 47.11), 1),
            (LonLat(longitude: -122.88, latitude: 47.12), 1),
            (LonLat(longitude: -117.40, latitude: 47.60), 1),
        ]
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15)
        #expect(zones.count == 2)
        #expect(zones.map(\.intensity).max() == 1.0)     // densest cell → 1.0
        #expect(zones.map(\.intensity).min()! < 0.5)      // lone cell (1/3) → lower
    }
}
