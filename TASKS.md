## Tasks
- [ ] Puget Sound river reports: repeat the sourcing pass (spec 2026-10-26-puget-river-reports) when new shop or guide reports appear; a river is added only with a report at most 21 days old (Skagit added 2026-10-26 on the Confluence Fly Shop's Oct 10 report; replace it when a fresher one appears). First pass: docs/research/2026-10-26-puget-river-reports.md.

#### Design critique 2026-10-26

- [ ] [you] Unlock the iPhone and run the pin device script
- [ ] [you] Observe pin VoiceOver labels on device (needs unlocked phone)
- [ ] Fishing Year: source pink once WDFW sets 2027 odd-year seasons (Apr 2027)

## Completed

### 2026-10-27 — cleared from Tasks

- [x] Kent guide pin hidden under Codiga Park at opening zoom -- grouped, not yet published
- [x] Confirm 1.0 shows in the public App Store -- live 01:22
- [x] Look over the one-map page on a phone and a desktop -- browser pass 2026-10-27, see STATUS
- [x] Run `node Artifacts/salmon-rivers/check-week.mjs` where Playwright is installed (the MacBook); it was cut to the one map on 2026-10-26 and has not run since.
- [x] Live conditions sub-project: USGS flow inside the map's site sheets (NOAA tides are done for marine Typical-season sheets, from the bundle).
- [x] Fishing Year build: `scripts/build_fishing_year.py` writes `Artifacts/fishing-year/data.js`; the map reads a byte copy at `salmon-rivers/seasons-data.js` (`test/season-places.test.js` fails until it is copied). Make the build write both, and add a `season-places.js` entry for any new season.
- [x] Recover the river-rules note and generators — 1af89ed
- [x] Map deep links: spawning month append and transient sync -- no history entry, see STATUS
- [x] Edge-tap UI test for the 44pt marker target
- [x] [you] Check the attached recording shows the far-date state -- moot, 1.0 (10) approved
- [x] [you] Reply to Apple only if build 10 is rejected -- approved, no reply
- [x] Release 1.0 (10) to the App Store -- READY_FOR_SALE 2026-10-27
- [x] Fishing Year: confirm Two Rivers Point (city plan)

### 2026-10-27 — Artifacts folder organized

- [x] Seasons source moved from `Artifacts/fishing-year/` to `Artifacts/salmon-rivers/seasons/`; the build writes only `seasons-data.js` (byte-identical output), and `test/season-places.test.js` now checks it against `seasons.json`. The retired Fishing Year and Three Friends pages moved to `Artifacts/archive/`; still-published pages stay at `Artifacts/<slug>/`, where the home artifact checks look.

### 2026-10-26 — cleared from Tasks

- [x] Year page row links: the built Year page already gives every season row `id="row-<season id>"`; `year/anchor.js` (new, loaded after `data.js`) presses the row named by the URL hash, and Week's Open now and Coming up season rows link to `../year/index.html#<id>`. Not yet viewed in a browser (local server and browsers are blocked in this session): open `year/index.html#chum` and a Week link once to confirm the row selects and scrolls.
- [x] Harden `links.js` parsing: month `^\d{1,2}$`, `today` a real calendar date, `Links.toQuery(null)` returns ''.
- [x] Week tide table now shows today plus the next six days (`Week.next7`), not the Mon–Sun week.
- [x] The map's TODAY (`index.html`) now reads Washington's date (`Tides.laParts`), not the device's, so a viewer outside Washington sees the right day's tides, report ages and season tags. Tested with a simulated Tokyo device; published as version 31 on 2026-10-26.
- [x] Week build robustness and tests: `FY.seasons || []` guard, future-dated reports are not fresh, unknown rating reads "No report", empty Spots row; boundary, tie-break, release-only and escaping tests.
- [x] `check-week.mjs` hardening: static server 403 on escaping paths, directory serves index.html or 404, unknown `--flags` exit 2 with usage, `browser.close()` in try/finally.
- [x] Counts on a phone: closed Filters details ("Filters · N active"), sticky River column, right-edge fade (<=480 px).
- [x] Counts page shell: centred column, large h1, plain subtitle, "(not parsed)" shown as "Unclear species" (display only; `counts/index.html` is hand-maintained, the data keeps the raw value).
- [x] Tide rows: at >=600 px each `td` is a 2-column grid of fixed 158px columns so extremes line up and never wrap.
- [x] Map overlays on phones: legend collapses to a 44 px "Key" button at <=390 px; the "Tap any river" hint hides after the first tap, drag or zoom (session).
- [x] Amber/orange outside the rating ramp: Year progress meter and selected calendar bar use `--accent` (plain CSS in `year/index.html`); Week chip reads "Ends soon · ends Oct 31 · 5 days". Follow-up: the Year source that builds `year/index.html` is not in this repo, so the same two CSS values must be changed there before the next rebuild.
- [x] "Taste #3 of 5" with a title explaining the taste order.
- [x] Repeated "Read the rule" links carry `aria-label="Read the WDFW rule for <rivers>"`.
- [x] Week copy: tides caption is "Tides" (picker names the station); footer already read "Seasons from Washington Fishing Year, updated <date>."
- [x] Open-now rows on Week have no way onward: they now link to their Year row (see the Year row links entry).
- [x] Harden WeatherKit attribution: larger mark + legal link
- [x] Device UI test asserts attribution mark and legal link
- [x] Review notes: WeatherKit attribution paragraph + STATUS log
- [x] Upload attribution fix to ASC — accepted as build 8
- [x] [you] Record WeatherKit attribution on iPhone for App Review
- [x] Resubmit 1.0 (8) with recording — Waiting for Review
- [x] Colour-blind pass on the ramp: no ring, CVD gate added
- [x] Link the unit-only test plan into the scheme and verify it
- [x] Pin VoiceOver probe fails on a stale element index — 1dbfb36
- [x] Design critique 1: lead the sheets with What's biting — b18e4af
- [x] Design critique 2: raise the fine print contrast
- [x] Design critique 3: readable pier Closed chip
- [x] Design critique 4: 44pt recentre touch target
- [x] Design critique 5: Rivers and Heat as real toggles
- [x] Design critique 6: species pill and chrome type roles
- [x] Design critique 7: verify all and record in STATUS
- [x] Fishing Year: grey bars with one highlight (kit rule)
- [x] Fishing Year: 44px touch targets on tabs, chips and rows
- [x] Fishing Year: save type, contrast and scroll checks in the repo
- [x] Fishing Year: access list beside the map at 600px and up
- [x] Fishing Year: shorten or dock the sticky stop card on phones
- [x] Fishing Year: source link and as-of date on each season
- [x] Fishing Year: Green and Skagit line warnings, real errors?
- [x] Fishing Year: verify the 13 hand-sourced stops against WDFW
- [x] Fishing Map page: link back to Fishing Year (page in flux)

### 2026-09-20 — cleared from Tasks

- [x] Flow vs normal: range strip (p10-p90 track, p25-p75 band, p50 tick, today's marker), not a bar
- [x] Best-months ribbon: 12 cells, current month marked, riskMonths on a non-colour channel
- [x] Decide the best-months wrap: rotate to start at the current month
- [x] [you] App name, subtitle, category, age rating — ASC + CFBundleDisplayName "WA Fish Map"
- [x] Privacy policy page hosted — https://danieldecena.github.io/wa-fish-map/privacy.html
- [x] Store description, keywords, review notes — pasted in ASC version (see listing-draft checklist)
- [x] [you] App Store screenshots in ASC — 6 on the 6.5" slot
- [x] [you] App Privacy questionnaire — Precise Location / App Functionality / not linked / not tracking
- [x] Archive and upload release build — ASC build 2 (1.0)
- [x] [you] ASC App Privacy: set Location to Data Not Collected
- [x] Upload build 6: PR #41 manifest, iPhone-only (#43)
- [x] [you] Submit 1.0 (6) for App Store review — Waiting for Review

- [x] Fix the Rivers watchdog kill: one overlay per style -- 5bdbc6d
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
Plan approved 2026-09-21 16:47.

Sessions start in "plan" (permissions.defaultMode in
~/.claude/settings.json). Bypass is reachable in the Shift+Tab cycle only
when launched via `cb` (--allow-dangerously-skip-permissions); `yolo`
(--dangerously-skip-permissions) starts in bypass outright.

Only if Claude Code actually closed:

    claude --resume 1f7317de-786d-4345-a4f4-babf6f9efb0e

(`-c` resumes the most recent session; bare `--resume` opens a searchable picker.)
<!-- /resume-footer -->
