import Foundation

/// What the map draws at a given camera distance.
///
/// MapKit's `clusteringIdentifier` declutters badges that collide, but it has no
/// notion of a badge being *unreadable*: pulled back to a continental view the
/// 477 access sites collapse into a solid mass of pins whose "+N more" labels
/// overlap each other, and the map says less than an empty one would. Past that
/// distance the density overlay carries the state-wide picture instead, which is
/// what it was built for.
///
/// Extracted as a pure predicate rather than an inline comparison so it can be
/// asserted directly — the same reason `Coordinator.isCameraMove(_:)` exists.
enum MapDetailLevel {
    /// Where individual pins stop being legible. Matches the distance at which
    /// `heatCellDegrees` switches to its coarsest bucket, so pins hand over to
    /// the overlay at exactly the point the overlay starts painting broadly.
    static let pinMaxDistance: Double = 400_000

    static func showsPins(atCameraDistance distance: Double) -> Bool {
        distance < pinMaxDistance
    }

    /// The overlay is forced on wherever pins are hidden, so pulling back never
    /// yields a blank map. The user's own toggle still wins everywhere else.
    static func showsHeat(userEnabled: Bool, atCameraDistance distance: Double) -> Bool {
        userEnabled || !showsPins(atCameraDistance: distance)
    }
}
