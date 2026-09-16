import Testing
import MapKit
@testable import WAFishMap

/// Guards the defect where the double-tap and two-finger-tap recognizers were
/// attached but could never fire: the handler only accepted `.began`/`.changed`,
/// which discrete tap recognizers never enter. A user who zoomed by tapping was
/// still treated as not having moved the camera, so a late location fix yanked
/// the map away from them.
@MainActor
struct CameraGestureTests {
    typealias Coordinator = FishingMapRepresentable.Coordinator

    @Test func discreteTapStatesCountAsACameraMove() {
        // .recognized is .ended — the only state a tap recognizer ever reaches.
        #expect(Coordinator.isCameraMove(.ended))
        #expect(Coordinator.isCameraMove(.recognized))
    }

    @Test func continuousDragStatesStillCountAsACameraMove() {
        #expect(Coordinator.isCameraMove(.began))
        #expect(Coordinator.isCameraMove(.changed))
    }

    @Test func idleAndAbandonedStatesAreNotACameraMove() {
        #expect(!Coordinator.isCameraMove(.possible))
        #expect(!Coordinator.isCameraMove(.cancelled))
        #expect(!Coordinator.isCameraMove(.failed))
    }
}
