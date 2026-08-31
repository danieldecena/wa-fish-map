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

    @Test func zoneCarriesItsCellSpan() {
        let zones = HeatMap.zones(
            points: [(LonLat(longitude: -122.90, latitude: 47.10), 1)],
            cellDegrees: 0.15
        )
        let zone = zones[0]
        #expect(zone.cellDegrees == 0.15)
        #expect(zone.corners.count == 4)
        // Corners span exactly one cell, centred on the zone.
        let lons = zone.corners.map(\.longitude)
        let lats = zone.corners.map(\.latitude)
        #expect(abs((lons.max()! - lons.min()!) - 0.15) < 1e-9)
        #expect(abs((lats.max()! - lats.min()!) - 0.15) < 1e-9)
    }

    @Test func oneOutlierDoesNotFloorOrdinaryCells() {
        // Three ordinary cells and one enormous outlier. Under max-normalisation
        // the ordinary cells would sit at 0.01-0.03; under rank they stay spread.
        var points: [(coord: LonLat, weight: Double)] = [
            (LonLat(longitude: -122.90, latitude: 47.10), 1),
            (LonLat(longitude: -122.60, latitude: 47.10), 2),
            (LonLat(longitude: -122.30, latitude: 47.10), 3),
        ]
        points.append((LonLat(longitude: -117.40, latitude: 47.60), 300))
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15).sorted { $0.intensity < $1.intensity }
        #expect(zones.count == 4)
        #expect(zones.map(\.intensity) == [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0])
    }

    @Test func tiedCellsShareARank() {
        let points: [(coord: LonLat, weight: Double)] = [
            (LonLat(longitude: -122.90, latitude: 47.10), 2),
            (LonLat(longitude: -122.60, latitude: 47.10), 2),
            (LonLat(longitude: -122.30, latitude: 47.10), 5),
        ]
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15)
        let intensities = zones.map(\.intensity).sorted()
        #expect(intensities == [0.0, 0.0, 1.0])
    }

    @Test func intensityQuantisesToFourBands() {
        #expect(ColorRamp.densityBand(0.0) == 0)
        #expect(ColorRamp.densityBand(0.3) == 1)
        #expect(ColorRamp.densityBand(0.6) == 2)
        #expect(ColorRamp.densityBand(1.0) == 3)   // top value clamps into the last band
    }
}
