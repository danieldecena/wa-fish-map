import Foundation

/// One heatmap cell: a coordinate and a normalized 0...1 intensity (cold→hot).
struct HeatZone: Equatable, Sendable, Identifiable {
    let id: Int
    let center: LonLat
    let intensity: Double
}

enum HeatMap {
    /// Bucket weighted points into a lon/lat grid and emit one zone per non-empty cell,
    /// with intensity normalized to the densest cell. Pure and testable — no map state.
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

        let maxSum = sums.values.max() ?? 1
        return sums.sorted { $0.key < $1.key }.enumerated().map { index, entry in
            HeatZone(
                id: index,
                center: LonLat(
                    longitude: (Double(entry.key.x) + 0.5) * cellDegrees,
                    latitude: (Double(entry.key.y) + 0.5) * cellDegrees
                ),
                intensity: maxSum > 0 ? entry.value / maxSum : 0
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
