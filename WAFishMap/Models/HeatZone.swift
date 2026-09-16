import Foundation

/// One heatmap cell: its centre, the span of the cell it came from, and a
/// rank-based 0...1 intensity (cold→hot).
///
/// The span travels with the zone so the view can draw the real cell. Drawing an
/// invented radius instead made zones wider than their own cells, and translucent
/// overlap composites rather than maxes — two mediocre neighbours rendered darker
/// than one genuinely hot cell, so the layer encoded "how many cells hold data"
/// rather than "how good is this water".
struct HeatZone: Equatable, Sendable, Identifiable {
    let id: Int
    let center: LonLat
    let cellDegrees: Double
    let intensity: Double

    /// The cell's four corners, for drawing it as a tiling polygon.
    var corners: [LonLat] {
        let half = cellDegrees / 2
        return [
            LonLat(longitude: center.longitude - half, latitude: center.latitude - half),
            LonLat(longitude: center.longitude + half, latitude: center.latitude - half),
            LonLat(longitude: center.longitude + half, latitude: center.latitude + half),
            LonLat(longitude: center.longitude - half, latitude: center.latitude + half)
        ]
    }
}

enum HeatMap {
    /// Bucket weighted points into a lon/lat grid and emit one zone per non-empty cell.
    ///
    /// Intensity is the cell's RANK among all cells, not its share of the densest
    /// one. Dividing by the maximum let a single outlier crush every ordinary cell
    /// toward the floor; rank answers "better than how many others", which is the
    /// question the overlay is actually asked, and is unmoved by one hot outlier.
    /// Pure and testable — no map state.
    static func zones(points: [(coord: LonLat, weight: Double)], cellDegrees: Double) -> [HeatZone] {
        guard cellDegrees > 0, !points.isEmpty else { return [] }

        var sums: [GridKey: Double] = [:]
        for p in points {
            let key = GridKey(
                x: Int((p.coord.longitude / cellDegrees).rounded(.down)),
                y: Int((p.coord.latitude / cellDegrees).rounded(.down))
            )
            sums[key, default: 0] += p.weight
        }

        let weights = sums.values.sorted()
        let denominator = Double(weights.count - 1)
        return sums.sorted { $0.key < $1.key }.enumerated().map { index, entry in
            // Cells strictly below this one, over the number of other cells. Ties
            // share a rank, and a lone cell is both coldest and hottest — call it hot.
            let strictlyLower = weights.firstIndex { $0 >= entry.value } ?? 0
            return HeatZone(
                id: index,
                center: LonLat(
                    longitude: (Double(entry.key.x) + 0.5) * cellDegrees,
                    latitude: (Double(entry.key.y) + 0.5) * cellDegrees
                ),
                cellDegrees: cellDegrees,
                intensity: denominator > 0 ? Double(strictlyLower) / denominator : 1
            )
        }
    }

    struct GridKey: Hashable, Comparable {
        let x: Int
        let y: Int
        static func < (lhs: GridKey, rhs: GridKey) -> Bool {
            (lhs.y, lhs.x) < (rhs.y, rhs.x)
        }
    }
}
