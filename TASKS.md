## Tasks

- [x] Resolve the two stashes on the PR 4 branch — 6e21fb5
- [x] Merge main into PR 4, suite green — b996199
- [x] Map popover WDFW link, species-aware sheets, Pacific calendar
- [x] WDFW 15s timeout + concurrent piers fetch — 6deea4d
- [x] Keep every ring of marine/protected areas, punch holes — 63fc7fe
- [x] Tide table reloads on site change — 0386a21
- [x] Strict concurrency warnings on (28 found) — d5fc9e2
- [x] Cache ring groups; Pacific calendar + species in all sheets — 22fe6c1
- [x] Fix the 28 strict-concurrency warnings (1 in USGSFlowLoader)
- [x] Cursor: install swiftlang.swift-vscode + remove CodeLLDB
- [x] Generate buildServer.json for Cursor (xcode-build-server)
- [ ] Profile launch indexing in Instruments (A7)
- [ ] [you] TestFlight: add both to the Internal group once they activate
- [ ] [you] Re-invite Pauline at her Apple Account address
- [ ] [you] GitHub Actions billing blocks PR #4 CI
- [x] Merge PR 4 (CI billing-blocked; verified locally) — 13c45d4
- [x] River nearest-match within 150 m — b68d7b6
- [x] Waterbody resolver: curated list then river
- [ ] Model index for site and pier waterbodies
- [x] Reachability gate accepts river names
- [ ] Spokane River row gated on WDFW, docs, verify
- [ ] Stamp the remaining 6 flow-stat gates
- [ ] Seed or hide the Oregon marine polygon
- [ ] Add PrivacyInfo privacy manifest
- [ ] Audit location permission strings
- [ ] Attribution: Apple Weather mark and data credits
- [ ] UI test: disclaimer and WDFW link on every sheet
- [ ] Offline states render unavailable, never stale
- [ ] Accessibility pass on pins, legend, sheets
- [ ] Final data pass and updated stamp
- [ ] [you] App name, subtitle, category, age rating
- [ ] Privacy policy page (host is your call)
- [ ] Store description, keywords, review notes
- [ ] App Store screenshots from uiTesting fixtures
- [ ] [you] App Privacy questionnaire
- [ ] Archive and upload release build
- [ ] [you] Submit for App Store review
- [ ] [you] Release to the App Store
- [ ] Layered OS27 app icon (3 SVG layers, Icon Composer)
- [x] ContentUnavailableView for the load-failure state — 406d3dc
- [ ] Fix app icon: reconnect tail, centre mark, eye inside head; add generator script
- [x] run_sim: resolve -d name to a udid before build — 34217d4
- [x] run_sim: guard against mid-build simulator shutdown — 34217d4
- [x] run_sim: verified end-to-end run with screenshot — 34217d4
- [x] Restore PR 4 build on phone after review-branch trial
- [x] Merge PR 5 run_sim script — merged 2026-09-16
- [x] Review PR 4 MKMapView migration branch

## Completed

- [x] Drain this project's 214 capture-inbox rows, the rest are other repos — 03c254d
- [x] Close the camera-guard pre-load residual
- [x] Verify Pierce, Mason, Kitsap, Thurston freshwater vs the default
- [x] Flag sites inside WDFW Marine Protected Areas (44, live, unused)
- [x] MKMapView migration: MapKit clustering, then chart tiles if a URL resolves
- [x] XCUITest target: observe the verify badge, retire the unobservable claims
- [x] Clamp cluster badges below a readable zoom
- [x] WeatherKit wind/precip at plan time
- [x] Verify WeatherKit on a physical iPhone — answered: Apple returns 401
- [x] Device-cache reset for WeatherKit — tried 2026-09-02, did not fix it
- [x] WeatherKit REST control — 200 with real data; device path is the fault
- [x] WeatherKit works on device — legacy WEATHERKIT vs WEATHER_KIT capability
- [x] WeatherKit attribution — WeatherAttribution mark + legal link — c705807
- [x] Cache PlanWeatherView by hourKey — c705807
- [x] TestFlight: internal group + account holder as tester, build 1 attached
- [x] TestFlight: external group insideout, build 1 submitted for Beta App Review
- [x] TestFlight: public join link on insideout, tester limit 5
- [x] TestFlight: invite Joseph and Pauline as Developer-role ASC users
- [x] Rivers slice 1: decode lines, bundle rivers.json, draw them
- [x] Rivers slice 2: USGS live flow colours the lines
- [x] Rivers slice 3: tap a river for flow, temp and notes
- [x] Fix the UI query: containing() filters descendants, a StaticText is a leaf
- [x] Device-sign the test bundles: build-for-testing on generic/platform=iOS — 24bbeff
- [x] Log the swallowed WeatherKit error in PlanWeatherView — 24bbeff
- [x] Device-gated UI test asserting a live wind reading on screen
- [x] Known-bad control for the weather test — observed on the device itself
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
- [x] Research coastal marine areas 1, 2, 2-1, 2-2, 3, 4
- [x] Research strait marine areas 5, 6
- [x] Research north Sound areas 7, 8-1, 8-2
- [x] Research 13 freshwater counties
- [x] Merge research into fisheries.json + deferred minors
- [x] Validate, test, build, commit

<!-- resume-footer -->
---
Plan approved 2026-09-16 01:19.

Sessions start in "plan" (permissions.defaultMode in
~/.claude/settings.json). Bypass is reachable in the Shift+Tab cycle only
when launched via `cb` (--allow-dangerously-skip-permissions); `yolo`
(--dangerously-skip-permissions) starts in bypass outright.

Only if Claude Code actually closed:

    claude --resume fdc9e5b5-c265-4d80-a25d-7e9a56ff4fc8

(`-c` resumes the most recent session; bare `--resume` opens a searchable picker.)
<!-- /resume-footer -->
