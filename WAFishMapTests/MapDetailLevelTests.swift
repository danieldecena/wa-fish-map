import Testing
@testable import WAFishMap

/// Guards the defect the launch screenshot showed: statewide, every access site
/// drew a pin and the badges piled into an unreadable mass of overlapping
/// "+N more" labels.
struct MapDetailLevelTests {
    @Test func pinsDrawWhenTheCameraIsCloseEnoughToReadThem() {
        #expect(MapDetailLevel.showsPins(atCameraDistance: 5_000))
        #expect(MapDetailLevel.showsPins(atCameraDistance: 399_999))
    }

    @Test func pinsAreHiddenOnceBadgesWouldOverlap() {
        #expect(!MapDetailLevel.showsPins(atCameraDistance: 400_000))
        #expect(!MapDetailLevel.showsPins(atCameraDistance: 3_000_000))
    }

    /// The camera starts at `greatestFiniteMagnitude` before the first camera
    /// event, so the very first frame must not be treated as a close-up.
    @Test func theInitialUnknownDistanceHidesPins() {
        #expect(!MapDetailLevel.showsPins(atCameraDistance: .greatestFiniteMagnitude))
    }

    @Test func heatIsForcedOnWhereverPinsAreHidden() {
        #expect(MapDetailLevel.showsHeat(userEnabled: false, atCameraDistance: 400_000))
        #expect(MapDetailLevel.showsHeat(userEnabled: false, atCameraDistance: .greatestFiniteMagnitude))
    }

    /// The control: forcing heat on when zoomed out must not mean heat is always
    /// on, or the toggle is decorative and this predicate cannot fail.
    @Test func heatStaysOffWhenZoomedInAndTheUserHasNotAskedForIt() {
        #expect(!MapDetailLevel.showsHeat(userEnabled: false, atCameraDistance: 5_000))
    }

    @Test func theUserToggleStillWinsWhenZoomedIn() {
        #expect(MapDetailLevel.showsHeat(userEnabled: true, atCameraDistance: 5_000))
    }
}
