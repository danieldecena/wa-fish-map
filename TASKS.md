## Tasks

- [x] Flag sites inside WDFW Marine Protected Areas (44, live, unused)
- [x] MKMapView migration: MapKit clustering, then chart tiles if a URL resolves
- [x] XCUITest target: observe the verify badge, retire the unobservable claims
- [x] Clamp cluster badges below a readable zoom
- [x] WeatherKit wind/precip at plan time
- [ ] [you] Verify WeatherKit on a physical iPhone — the simulator cannot
- [x] Device-sign the test bundles: build-for-testing on generic/platform=iOS — 24bbeff
- [x] Log the swallowed WeatherKit error in PlanWeatherView — 24bbeff
- [x] Device-gated UI test asserting a live wind reading on screen
- [x] Prove the weather test fails on the simulator (known-bad control)
- [x] scripts/verify_weatherkit_device.sh + README line
- [x] Waterbody note tier: restore the Baker Lake sockeye entry
- [x] Piers outside marine polygons answer freshwater, not neutral
- [x] Index piers against Marine Protected Areas too
- [x] Launch pins draw a default marker, anchor.fill is not a symbol
- [x] Wave height + water temp from NDBC (no depth)
- [x] Daylight row in the detail sheets — 72bec59
- [x] Layered OS27 app icon — 2 vector layers + document gradient fill
- [x] Tap zooms count as a user camera move; protected-area default is unavailable — 15c4b5c
- [x] ContentUnavailableView for the load-failure state — 406d3dc
- [x] Fix app icon: reconnect tail, centre mark, eye inside head; add generator script

- [x] Waterbody-scoped notes: gate + data fix + rule — d26c4ca

- [x] Tide predictions in site detail (NOAA CO-OPS)
- [x] Species-first mode: picker, recolor, month scrubber
- [x] Marker clustering at low zoom (477 pins unreadable statewide)

- [x] Season/closure rating cap + verify badge — d78377b
- [x] Thermal rating ramp, range dots, heat as tiling ranked cells — 3eb5a43
- [x] Open the map on the user's location; location-denied hint — 07f4460

- [x] Real dawn/dusk: solar times drive TimeOfDay — PENDING
- [x] Fix rating color ramp + marker a11y + Dynamic Type fonts — 9045cc2
- [x] Floating glass chrome on iPhone + disclaimer info button — 7f1b685
- [x] Heat legend swap + cache heat zones
- [x] Pier inspector on iPad, loading spinner, zoom-gated labels
- [x] Rewrite verify_wdfw_live script for statewide contract
- [x] Add GitHub Actions CI
- [x] Guard ArcGIS truncation in app load
- [x] Surface load failure in statusMessage

## Completed

- [x] Research coastal marine areas 1, 2, 2-1, 2-2, 3, 4
- [x] Research strait marine areas 5, 6
- [x] Research north Sound areas 7, 8-1, 8-2
- [x] Research 13 freshwater counties
- [x] Merge research into fisheries.json + deferred minors
- [x] Validate, test, build, commit

<!-- resume-footer -->
---
Plan approved 2026-09-02 02:36.

Sessions start in "plan" (permissions.defaultMode in
~/.claude/settings.json). Bypass is reachable in the Shift+Tab cycle only
when launched via `cb` (--allow-dangerously-skip-permissions); `yolo`
(--dangerously-skip-permissions) starts in bypass outright.

Only if Claude Code actually closed:

    claude --resume a1f346c7-be4d-4e2d-bf76-e5ce45f7ae96

(`-c` resumes the most recent session; bare `--resume` opens a searchable picker.)
<!-- /resume-footer -->
