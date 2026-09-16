## Tasks
- [ ] [you] Observe pin VoiceOver labels on device (needs unlocked phone)
- [x] [you] App name, subtitle, category, age rating — ASC + CFBundleDisplayName "WA Fish Map"
- [x] Privacy policy page hosted — https://danieldecena.github.io/wa-fish-map/privacy.html
- [x] Store description, keywords, review notes — pasted in ASC version (see listing-draft checklist)
- [x] [you] App Store screenshots in ASC — 6 on the 6.5" slot
- [x] [you] App Privacy questionnaire — Precise Location / App Functionality / not linked / not tracking
- [x] Archive and upload release build — ASC build 2 (1.0)
- [x] [you] ASC App Privacy: set Location to Data Not Collected
- [x] Upload build 6: PR #41 manifest, iPhone-only (#43)
- [x] [you] Submit 1.0 (6) for App Store review — Waiting for Review
- [ ] [you] Release to the App Store after approval (manual release)


## Completed

- [x] Build 4 uploaded to ASC (from 66c16ba, accepted as 4)
- [x] Shared simulator test-host kill: runbook rule (~/.claude ed7fdcf)
- [x] Recenter button uses live location, not launch fix -- #33
- [x] Directions link uses unified Maps URL on iOS 18.4+ -- #35
- [x] Glass effect on MA area labels (iOS 26) -- #36
- [x] MapCoordinatorTests recentre test hung 10 min under load
- [x] Inland pins all Good in Sept: statewide list is uniform -- #38
- [x] Grant walleye: per-reservoir rows, drop county row -- #34
- [x] Baker Lake sockeye row reaches no WDFW launch -- #37

- [x] Build 3 uploaded to ASC (data batch 1, from a47cc87)

- [x] Data pass second batch: omissions sourced, unsupported calls settled

- [x] Layered app icon — 439e377 (render checked 2026-09-16)
- [x] Fix app icon via generator script — 86f630f

- [x] Final data pass against WDFW (3 reports in docs/research)
- [x] Spokane River row refused (logged 2026-09-16)

- [x] Profile launch indexing on iPhone 16 Pro (A7 impossible)

### 2026-09-16 — cleared from Tasks (goal run)

- [x] Verify flow stats against USGS source
- [x] Seed or hide the Oregon marine polygon (hidden)
- [x] Add PrivacyInfo privacy manifest — 492a874
- [x] Audit location permission strings — 74cb109
- [x] Attribution: Apple Weather mark and data credits — c705807
- [x] UI test: disclaimer and WDFW link on every sheet
- [x] Weather: plan past last forecast hour shows last hour
- [x] Empty MPA layer reads as "clear" at every site
- [x] iPad buoy section keeps previous site's reading
- [x] USGS fetch failure blamed on "gauge not reporting"
- [x] Empty live WDFW layer shows "0 access sites"
- [x] Pier fetch failure is invisible (try? swallowed)
- [x] Weather cache has no age; refetch after ~1 h
- [x] Weather: cancelled fetch can write the old hour
- [x] Opening map frames Washington with no WA location fix — d2a106a
- [x] VoiceOver labels: pins, clusters, legends, rating badge
- [x] No location fix: map stays on North America, never frames WA — #16, #17
- [x] Info button 44pt hit target + navigation disclaimer in chrome/footer
- [x] Draft privacy policy + App Store listing copy — docs/app-store/
- [x] Screenshot helper script — scripts/app_store_screenshots.sh
- [x] Merge weather hour/cache/cancel fixes — PR #19
- [x] Shore snap: saltwater piers/launches no longer freshwater
- [x] Verify species weights (7 adjusted; 6 no source found)
- [x] Watch fish silhouettes on screen (Dash Point, Crescent Lake)
- [x] Watch the Closed badge in a closed pier sheet
- [x] Look at creeks on screen with Rivers on (PR #17)
- [x] Creek sheet says "No USGS gauge on this river"
- [x] Creek filter drops small fished creeks (order<3, <10 km)
- [x] Confirm PR #17 "unstable" is the CI billing block (moot: merged, checks pass)
- [x] Same-name rivers still merge (two Green Rivers)
- [x] Review and merge PR #17 — 9b3a4fb
- [x] Key river stats/flow by id before any creek gets a gauge
- [x] Filter rivers once in indexWaterbodies, not per site
- [x] Live load shows no false "piers unavailable" (PR #18)
- [x] [you] Review and merge PR #18

### 2026-09-16 — cleared from Tasks

- [x] Fix the 28 strict-concurrency warnings (1 in USGSFlowLoader)
- [x] Model index for site and pier waterbodies
- [x] Resolve the two stashes on the PR 4 branch — 6e21fb5
- [x] Merge main into PR 4, suite green — b996199
- [x] Map popover WDFW link, species-aware sheets, Pacific calendar
- [x] WDFW 15s timeout + concurrent piers fetch — 6deea4d
- [x] Keep every ring of marine/protected areas, punch holes — 63fc7fe
- [x] Tide table reloads on site change — 0386a21
- [x] Strict concurrency warnings on (28 found) — d5fc9e2
- [x] Cache ring groups; Pacific calendar + species in all sheets — 22fe6c1
- [x] Cursor: install swiftlang.swift-vscode + remove CodeLLDB
- [x] Generate buildServer.json for Cursor (xcode-build-server)
- [x] Merge PR 4 (CI billing-blocked; verified locally) — 13c45d4
- [x] River nearest-match within 150 m — b68d7b6
- [x] Waterbody resolver: curated list then river
- [x] Reachability gate accepts river names
- [x] ContentUnavailableView for the load-failure state — 406d3dc
- [x] run_sim: resolve -d name to a udid before build — 34217d4
- [x] run_sim: guard against mid-build simulator shutdown — 34217d4
- [x] run_sim: verified end-to-end run with screenshot — 34217d4
- [x] Restore PR 4 build on phone after review-branch trial
- [x] Merge PR 5 run_sim script — merged 2026-09-16
- [x] Review PR 4 MKMapView migration branch
- [x] Outline markers where a closure is plausible — 3ba2b1e
- [x] All-species colour: mean of top three species — 6fc64b8
- [x] Fade WDFW-closed piers; Directions in Maps — d2ece00
- [x] Fish icon sized by typical weight in sheets — 721937e

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
Plan approved 2026-09-16 11:59.

Sessions start in "plan" (permissions.defaultMode in
~/.claude/settings.json). Bypass is reachable in the Shift+Tab cycle only
when launched via `cb` (--allow-dangerously-skip-permissions); `yolo`
(--dangerously-skip-permissions) starts in bypass outright.

Only if Claude Code actually closed:

    claude --resume 4e357a8b-dc36-4446-96db-9f46a2997f27

(`-c` resumes the most recent session; bare `--resume` opens a searchable picker.)
<!-- /resume-footer -->
