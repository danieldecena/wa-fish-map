# Marker edge-tap UI test

Spec: none. This plan closes the STATUS "Known broken" line "The 44pt marker
tap target is asserted as geometry only. An edge tap ... is the other half."

## Context

- `WAFishMap/Map/AnnotationViews.swift`: `SiteMarkerView` and the cluster view
  draw scaled (`MarkerMetrics.pin` = 0.8, cluster 0.95) and override
  `point(inside:with:)` with `MarkerMetrics.hitRect`, so the touch area is 44pt
  on screen while the drawing is smaller.
- `WAFishMapTests/MarkerTapTargetTests.swift` asserts that rect as geometry
  only. Nothing yet proves a real touch near the edge of a pin, outside the
  drawn balloon but inside 44pt, selects the site.
- UI test fixture: `-uiTesting -uiTestingRegion <region>` (see
  `WAFishMapUITests/PinSpokenTextUITests.swift` for the launch, the
  `siteDetailSheet` identifier, dismissing the sheet by tapping open map, and
  finding a pin by `label BEGINSWITH`).
- The test targets use Xcode file-system synchronized groups: a new `.swift`
  file in `WAFishMapUITests/` is compiled without editing `project.pbxproj`.

## Global Constraints

- Every `xcodebuild`/`simctl` run goes through the `ios-build` skill (load it
  before the first one) and `scripts/run_sim.sh`; never hardcode a device name.
- Exit status is taken from the command itself, never through a pipe; capture
  the log to a file.
- An assertion that cannot fail is not a check: the test must be shown red
  against a deliberately broken target before its green counts.
- No change to app behaviour. Production code may change only to add an
  accessibility identifier if one is strictly needed, and none is expected.
- Match the style and comment density of the existing UI tests.
- `PinVoiceOverProbe` is a known failure; do not read it as a regression and
  do not touch it.

## Task 1: Edge-tap UI test for a site pin

Create `WAFishMapUITests/MarkerEdgeTapUITests.swift` with one test,
`testATapOutsideTheDrawnPinButInsideFortyFourPointsOpensItsSheet`.

1. Launch with the same fixture and region approach as `PinSpokenTextUITests`,
   wait for the map, and dismiss the fixture's open sheet the same way.
2. Pick one isolated site pin (not a cluster), found by its accessibility
   label. Read its on-screen frame (`frame` of the XCUIElement). If the frame
   turns out not to be the drawn size (check by logging it once and comparing
   with 0.8 x the marker's natural size), say so in the report and use the
   drawn size from `MarkerMetrics` instead.
3. Compute a tap point on the horizontal line through the frame's centre at
   an offset `d` from centre with `drawnHalfWidth < d < 22` (choose the
   midpoint of that interval and assert the interval is non-empty, so the
   test fails loudly if the pin is ever drawn at 44pt or wider). Tap it with
   `XCUICoordinate` relative to the app or map.
4. Assert `siteDetailSheet` appears and that it is this pin's sheet (its
   title or an element inside it carries the pin's name).
5. Choose the pin and side so no other pin, cluster or chrome lies within
   44pt of the tap point; state in a comment why that pin is isolated.

Control (required, not committed): temporarily change
`SiteMarkerView.point(inside:with:)` to return
`bounds.contains(point)` (or set the hit rect scale to 1), run only this
test, and confirm it FAILS with the sheet-not-shown assertion. Revert, confirm
`git diff` shows the production file unchanged, run again and confirm it
PASSES. Record both runs (command, exit status from the command itself, the
relevant log lines) in the report.

Then run the whole UI test target once and report results, naming any
failure other than `PinVoiceOverProbe`.

Update `STATUS.md`: remove the "Known broken" line about the 44pt target and
add a decision-log entry under today's date saying what the test proves, and
that it runs in the Simulator (synthesised touches go through the same UIKit
hit testing as real ones; a hardware run is not part of this task). Tick the
`TASKS.md` line "Edge-tap UI test for the 44pt marker target".

Commit with a message explaining what the test proves and the control result.
