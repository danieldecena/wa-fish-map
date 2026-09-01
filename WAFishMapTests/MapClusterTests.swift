import Testing
@testable import WAFishMap

struct MapClusterTests {
    private let a = LonLat(longitude: -122.90, latitude: 47.10)
    private let nearby = LonLat(longitude: -122.89, latitude: 47.11)
    private let far = LonLat(longitude: -117.40, latitude: 47.60)

    @Test func emptyOrZeroCellYieldsNothing() {
        #expect(HeatMap.clusters(points: [], cellDegrees: 0.15).isEmpty)
        #expect(HeatMap.clusters(
            points: [(id: "x", coord: a, rating: .good)],
            cellDegrees: 0
        ).isEmpty)
    }

    @Test func twoPointsInOneCellBecomeOneCluster() {
        let clusters = HeatMap.clusters(
            points: [
                (id: "boston", coord: a, rating: .fair),
                (id: "luhrs", coord: nearby, rating: .excellent),
            ],
            cellDegrees: 0.15
        )
        #expect(clusters.count == 1)
        #expect(clusters[0].count == 2)
        #expect(Set(clusters[0].memberIDs) == ["boston", "luhrs"])
        #expect(clusters[0].bestRating == .excellent)
        #expect(clusters[0].cellDegrees == 0.15)
    }

    @Test func farApartPointsStaySingletons() {
        let clusters = HeatMap.clusters(
            points: [
                (id: "west", coord: a, rating: .good),
                (id: "east", coord: far, rating: .poor),
            ],
            cellDegrees: 0.15
        )
        #expect(clusters.count == 2)
        #expect(Set(clusters.map(\.count)) == [1])
    }

    @Test func nilRatingsDoNotBeatARealOne() {
        let clusters = HeatMap.clusters(
            points: [
                (id: "none", coord: a, rating: nil),
                (id: "fair", coord: nearby, rating: .fair),
            ],
            cellDegrees: 0.15
        )
        #expect(clusters[0].bestRating == .fair)
    }

    @Test func allNilRatingsStayNil() {
        let clusters = HeatMap.clusters(
            points: [
                (id: "a", coord: a, rating: nil),
                (id: "b", coord: nearby, rating: nil),
            ],
            cellDegrees: 0.15
        )
        #expect(clusters[0].bestRating == nil)
        #expect(clusters[0].count == 2)
    }
}
