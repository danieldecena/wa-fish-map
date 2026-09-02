## Tasks

- [ ] Flag sites inside WDFW Marine Protected Areas (44, live, unused)
- [ ] MKMapView migration: MapKit clustering, then chart tiles if a URL resolves
- [ ] XCUITest target: observe the verify badge, retire the unobservable claims
- [ ] Clamp cluster badges below a readable zoom
- [ ] WeatherKit wind/precip at plan time
- [ ] Waterbody note tier: restore the Baker Lake sockeye entry
- [ ] Piers outside marine polygons answer freshwater, not neutral
- [ ] Index piers against Marine Protected Areas too
- [ ] Launch pins draw a default marker, anchor.fill is not a symbol
- [ ] Wave height + water temp from NDBC (no depth)
- [x] Daylight row in the detail sheets — 72bec59
- [x] Layered OS27 app icon — 2 vector layers + document gradient fill
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
Plan approved 2026-09-01 17:43.

Sessions start in "plan" (permissions.defaultMode in
~/.claude/settings.json). Bypass is reachable in the Shift+Tab cycle only
when launched via `cb` (--allow-dangerously-skip-permissions); `yolo`
(--dangerously-skip-permissions) starts in bypass outright.

Only if Claude Code actually closed:

    claude --resume cb15233e-025c-4c94-884f-0bf8d07d49ed

(`-c` resumes the most recent session; bare `--resume` opens a searchable picker.)
<!-- /resume-footer -->
