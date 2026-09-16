import Testing
@testable import WAFishMap

struct HeatMapTests {
    @Test func emptyInputYieldsNoZones() {
        #expect(HeatMap.zones(points: [], cellDegrees: 0.15).isEmpty)
        #expect(HeatMap.zones(points: [(LonLat(longitude: -122, latitude: 47), 1)], cellDegrees: 0).isEmpty)
    }

    @Test func bucketsPointsAndRanksTheSparserCellLowest() {
        // Three points in one 0.15° cell (weight 3), one lone point far away
        // (weight 1). Rank-based intensity: the lone, lighter cell is strictly
        // below the denser one, so it ranks lowest — 0.0, not some fraction of
        // the dense cell's weight. Asserting the exact value (rather than just
        // "< 0.5") is what distinguishes rank-based intensity from the
        // abandoned max-normalisation, which would have put it at 1/3.
        let points: [(coord: LonLat, weight: Double)] = [
            (LonLat(longitude: -122.90, latitude: 47.10), 1),
            (LonLat(longitude: -122.89, latitude: 47.11), 1),
            (LonLat(longitude: -122.88, latitude: 47.12), 1),
            (LonLat(longitude: -117.40, latitude: 47.60), 1),
        ]
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15)
        #expect(zones.count == 2)
        #expect(zones.map(\.intensity).max() == 1.0)     // densest cell → 1.0
        #expect(zones.map(\.intensity).min() == 0.0)     // lone, sparser cell → 0.0 under rank
    }

    @Test func singleCellHasNoOtherRankToCompareAgainstAndIsHot() {
        // One point means one cell: `weights.count - 1 == 0`, so the rank
        // denominator is zero. The lone-cell branch is exercised by other tests
        // (e.g. the far-away point above), but its `intensity == 1` value —
        // "call it hot" per the comment in HeatMap.zones — was never asserted.
        let zones = HeatMap.zones(
            points: [(LonLat(longitude: -122.90, latitude: 47.10), 1)],
            cellDegrees: 0.15
        )
        #expect(zones.count == 1)
        #expect(zones[0].intensity == 1.0)
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

    @Test func weightRewardsOnlyRatedSpots() {
        #expect(HeatMap.weight(for: .excellent) == 3)
        #expect(HeatMap.weight(for: .good) == 2)
        #expect(HeatMap.weight(for: .fair) == 1)
        #expect(HeatMap.weight(for: .poor) == 0)
        #expect(HeatMap.weight(for: nil) == 0)
    }

    @Test func poorOnlyCellDrawsNothingAgainstARatedNeighbor() {
        // A cell of only poor/unrated points has weight 0, so it draws no zone at
        // all once the grid keys collapse points into cells only when they carry
        // weight — a fair-or-better neighbor still ranks above it.
        let points: [(coord: LonLat, weight: Double)] = [
            (LonLat(longitude: -122.90, latitude: 47.10), HeatMap.weight(for: .poor)),
            (LonLat(longitude: -122.89, latitude: 47.11), HeatMap.weight(for: nil)),
            (LonLat(longitude: -117.40, latitude: 47.60), HeatMap.weight(for: .fair)),
        ]
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15)
        let poorCellZone = zones.first { $0.center.longitude < -120 }
        #expect(poorCellZone != nil)
        #expect(ColorRamp.densityBand(poorCellZone!.intensity) == 0)
    }

    @Test func manyPoorPointsDoNotOutrankOneExcellentPoint() {
        var points: [(coord: LonLat, weight: Double)] = []
        for i in 0..<50 {
            points.append((LonLat(longitude: -122.90 + Double(i) * 0.001, latitude: 47.10), HeatMap.weight(for: .poor)))
        }
        points.append((LonLat(longitude: -117.40, latitude: 47.60), HeatMap.weight(for: .excellent)))
        let zones = HeatMap.zones(points: points, cellDegrees: 0.15)
        let poorCellZone = zones.first { $0.center.longitude < -120 }
        let excellentCellZone = zones.first { $0.center.longitude > -120 }
        #expect(excellentCellZone != nil)
        #expect(poorCellZone != nil)
        #expect(excellentCellZone!.intensity > poorCellZone!.intensity)
    }
}
