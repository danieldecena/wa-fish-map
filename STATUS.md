# WAFishMap — Status

## Confirmed working

- Washington Fishing Map, published as versions 16-19 on 2026-10-26: a Week tab
  (open seasons, this week's reports, new WDFW rules, coming up, a 7-day bundled NOAA
  tide table, spots), deep links (`?mode=&month=&species=&site=&river=`), one
  five-tab bar (Week, Map, Year, Spots, Counts) on every page, and the map's
  control card as one 56 px row (phones: a mode menu and a species icon). 196
  Node tests (193 pass, 3 skipped because the local salmon.db is absent; 62 in the
  new week, tides, links and tabs files); `check-week.mjs` all checks pass. The
  live tide fetch is blocked by the frame's CSP, so tides are bundled in
  `week/tides-data.js` (see the 2026-10-26 entry); version 19 shipped the bundle.
- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; the
  "Oregon" polygon is filtered out of the map, not seeded) plus freshwater rows:
  statewide, 8 county overrides and 6 waterbody rows (counted 2026-10-20;
  `updated` 2026-10-18). WDFW-checked 2026-08-30 and in the 2026-09-16 data pass.
- The web pages in `Artifacts/` are published and tested apart from the app:
  Washington Fishing Map (`salmon-rivers/`, Recent reports + Typical season),
  Washington Fishing Year and the SW Washington Creel Table. 134 Node tests,
  15 Python script tests and the Fishing Year data check pass (2026-10-20).
- `fisheries.json` v1 Puget Sound seed cross-checked against WDFW; corrections
  applied (see decision log).
- Dawn/dusk comes from real sun times: `SolarTimes` (NOAA equations, pure, no
  network) at the map's camera center, with the fixed hour buckets kept as the
  fallback.
- Season/closure capping ships: a curated `seasonRisk` table in fisheries.json
  is matched to species by case-insensitive substring at load, stamping
  `riskMonths` that clamp a species to `.fair`, so a fishery whose season is set
  annually can never render as Prime. Capped species carry a "Season varies —
  verify" badge and their reason. 11 table rows cover the 42 entries whose notes
  already described a closure.
- Ratings run a thermal ramp — Slow azure, Fair amber, Good orange, Prime red —
  as four explicit stops. Past 400km altitude pins hand over to the density
  overlay (`MapDetailLevel.pinMaxDistance`).
- The ramp holds up for deuteranopia and protanopia: every adjacent pair is
  separated by simulated colour or by glyph ink, asserted in
  `CVDSeparationTests`. Fair/Good is the thin pair (see the 2026-10-06 entry).
- The heat overlay draws each grid cell as a tiling MapPolygon, ranked against
  the other cells rather than normalised to the densest one, in four violet
  bands over a muted basemap. Cell size follows the camera.
- The map opens on the user's location when a fix lands inside Washington and
  they have not moved the camera; a denied permission now says so and links to
  Settings.
- Marine launch and pier sheets show that day's NOAA high/low tides for the
  nearest bundled station (170 WA + Columbia-mouth). Follows the map date;
  next extreme after the plan time is highlighted.
- Pins cluster via MapKit's `clusteringIdentifier` (the hand-rolled grid
  clusterer was deleted in the MKMapView migration). Past 400km they are not
  drawn at all — `MapDetailLevel` — and the density overlay is forced on so the
  map is never blank; the legend follows what is drawn, not the toggle.
- Species-first picker recolours pins, clusters, heat, and area fills by an
  exact species name from the guide; missing listings stay gray. Date picker
  unchanged.
- `WAFishMapUITests` is a real target and the verify badge is **observed on
  screen**, not inferred. `-uiTesting` loads the bundled fixture and preselects a
  site so no tap injection is involved; `-planMonth n` pins the month.
- Piers are checked against Marine Protected Areas and answer the same
  three-way `inside / clear / unavailable` as launches, through a shared
  `ProtectedAreaSection`. Piers outside every marine polygon answer freshwater.
- `freshwater.byWaterbody` pins a claim to one lake or river. A lake resolves
  through the curated `waterbodySites` list; a river resolves by exact name to
  any inland launch or pier within 150 m of its line (`River.nearest`, curated
  list first, precomputed per site in `FishingMapModel.indexWaterbodies`). The
  shipped rows are walleye on four Grant County lakes, Skagit River coho and Puyallup River coho (both added 2026-10-18).
- Marine sheets show the nearest NDBC buoy's latest wave height and water
  temperature, each with its own timestamp.
- WeatherKit works on device. `testWindReadsARealValueOnDevice` **passed** on a
  physical iPhone 16 Pro 2026-09-02, asserting a live `… mph` reading and the
  success-only footer on screen at once. It ran in 7.7s against 68-79s for every
  prior failing run, because the fetch now returns instead of grinding out.
  The test has both inputs: it was observed failing on the same device before the
  fix and passing after, so a green run means something.
- `./scripts/verify_weatherkit_device.sh` is the one command that proves it:
  device pre-flight, build, sign, install, run, then confirm from the device.
- The suite is 152 tests: 148 Swift Testing in 23 suites plus 4 XCUITest, with
  one skip. The skip is `testWindReadsARealValueOnDevice`, gated to hardware on
  purpose.
- Rivers draw. Slice 1 is **built and observed**, not inferred: `xcodebuild
  test` exits 0, and each new test was confirmed to have run by name rather than
  by the suite total moving. `rivers.json` carries 287 Washington rivers from
  USGS NHD, and the FTYPE trap is guarded at both ends — `EXPECTED_RIVERS` in
  the generator and `RiverTests.theBigRiversAreActuallyInTheBundle` over the
  shipped file, with `theColumbiaIsTheWholeRiverNotAFragment` asserting length
  because a fragment passes a name check.
- Tapping a river opens a sheet. Overlays are not selectable the way
  annotations are, so `Coordinator.riverTap(_:)` hit-tests by hand: a 22-point
  fingertip tolerance converted to metres at the current zoom, deferring to any
  pin under the finger. `River.distanceMeters(to:)` is pure, so selection is
  tested without a map, with a control (a point 1km off must read ~1000m, or
  "measures distance" is indistinguishable from "always returns zero").
- The river sheet distinguishes two silences that look identical: "no USGS gauge
  on this river" is permanent, "has a gauge but it is not reporting right now"
  is not. Flow and water temperature carry separate timestamps, because a gauge
  can report discharge every 15 minutes and temperature hourly.
- River flow is live. `USGSFlowLoader` pulls every active Washington gauge's
  discharge and water temperature in one keyless call, and `RiverFlowStats`
  locates today's reading in that river's own day-of-year distribution, bundled
  from USGS daily statistics by `scripts/build_river_stats.py` (77 rivers, the
  Skagit backed by 101 years). **Verified against the source, not just on
  screen**: Puyallup 208 cfs against a p10 of 298 draws Slow, Snoqualmie 123
  mid-range draws Good, Skagit 5,370 just over its p10 of 5,320 draws Fair —
  each colour traced from the live number through the right percentile row.
- Flow deliberately cannot reach Prime. Normal flow means conditions are
  workable, never that fish are in the river, so `.excellent` stays the seasonal
  guide's word and red keeps one meaning. Both tails read Slow, because bony and
  blown out are equally unfishable.
- 57% of drawn river length is gauged (78% of mainstems, 13 of 14 marquee
  rivers). The 208 ungauged rivers are mostly order-3 tributaries and render
  lighter and thinner so the gauged mainstems carry the signal.
- The muted basemap engages for rivers, confirmed by an A/B on the simulator
  rather than by reading the code: with the layer off the map is saturated green
  with deep blue water and black labels; with it on, terrain, water, roads and
  labels all drop back and the river lines become the heaviest linework on
  screen. The first capture of this looked blank and was only map tiles still
  loading — a second capture 25s later settled it.
- Build 1 is installed from TestFlight. Apple reports the build
  `IN_BETA_TESTING`, attached to the internal group `Internal` (`f303ff11-…`),
  and `danieldecena@icloud.com` at state `INSTALLED` — the tester state is the
  observation, not the upload receipt or the group membership. `./scripts/testflight_internal.py` created
  that chain and reads it back; run without `--apply` it is a read-only
  diagnosis of what is missing.

## Known broken

- The 44pt marker tap target is asserted as geometry plus a simulator edge tap
  (`MarkerEdgeTapUITests`). That test cannot isolate `hitRect`: the simulator
  never consults it (see 2026-10-18, re-confirmed 2026-10-26), so it passes
  with the rect deleted, too small, too large, or refusing every touch.
  Hardware reach is not observed.
- `PinVoiceOverProbe` fails every run (stale element index, see 2026-10-09), and
  it is in the default test plan.
- App Store version 1.0 (10) was Waiting for Review under 5.2.5, resubmitted
  2026-10-09 7:28 PM (read from Apple). **Not re-read since** — check App
  Store Connect before acting on this line. Daniel has not replied to Apple's
  Sep 24 message in the thread; Apple also asks for a device screen
  recording in the App Review Notes for future submissions.
- The App Store screenshots predate the 2026-10-14 design pass; refresh them
  at the next submission.
- `Artifacts/app-store-listing` has dead demo, privacy and support links (see
  its `artifact.json`); fixing it means republishing, which wants Daniel's OK.

## Next Up

- 1.0 (10): read Apple's verdict in App Store Connect (last read 2026-10-09).
  Approved → release by hand. Rejected → follow the 2026-10-09 workflow entry.
- Fishing Year: pink seasons once WDFW sets the 2027 odd-year rules (Apr 2027);
  confirm the Green River ramp and Two Rivers Point stops.
- 1.0 (9) carries the pin VoiceOver fix and is with both TestFlight groups,
  `Internal` and `insideout`, beta review approved (read from Apple 2026-10-09).

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

### 2026-10-26 (marker edge-tap test lands, and what it cannot prove)
- The edge-tap test and its finding sat unmerged on `origin/test/marker-edge-tap-outside` (e750258, d3a8c57) while `main` still read "geometry only"; a fresh attempt today re-derived the same result. Landed that branch's test file as-is instead of a second version.
- Re-confirmed on the iOS 27.1 SDK simulator: with `SiteMarkerView.point(inside:with:)` returning `false` for every touch (compiled into the app, checked in the build log), a tap 0pt from the pin's centre still opened its sheet; a tap past the drawn 30pt frame did too, with the override returning `bounds.contains(point)`. MapKit selects by its own slop. So the planned control ("must go red with the rect removed") cannot be built in the Simulator.
- The branch's 2026-10-18 finding, carried here since it never reached `main`: on the iOS 27.0 simulator, `minimumTapTarget` at 1pt, at 140pt, and `point(inside:)` returning `false` all left the measured reach and the test unchanged. A lone pin's reach is MapKit's own: out to 50pt either side and 54pt above its centre, 25pt below.
- Decided: the test guards that a pin stays selectable from all four edges, not that `hitRect` makes it so. Whether hardware honours the rect is a device run, filed as a `[you]` task.

### 2026-10-26 (river sources recovered, not recreated)
- The "lost" river-rules note and the `rivers-tap.js` / `sites.js` generators were never lost: they sit on the unmerged `origin/feat/one-app-2026-10-20` (commits a1fad96, 55d8fc0), whose page work reached `main` by another route. Restored as-is. Evidence: that branch's `rules.js` and `rivers-tap.js` are byte-identical to `main`'s; `build_rivers_tap.py` rebuilt `rivers-tap.js` byte for byte; `build_spawning_sites.py` rebuilt `sites.js` with identical data and only the header now naming the real script (it said `build_sites.py`, which never existed).
- Decided: the three files are generated or sourced again, not hand-maintained. The README says how to rebuild them.
- The Puget river reports pass was not repeated this session: the first pass ran the same day.

### 2026-10-26 (PR 55 close-out, one owner per page url)
- PR 55's open check is done: `NoteScopeTests` and `WaterbodyResolverTests` ran on a Mac (11 tests in 2 suites, pass) on a spare simulator, not the booted one another session was using. The `wa-fish-map-pr55` worktree was clean and removed.
- Decided: a folder whose page was folded into the main map keeps `published-in.json`, not `artifact.json` (PR 83). Fishing Year and Three Friends both still claimed the main url, so three files owned one url and the artifact register failed "url owned twice". The main map's binding is the only owner; the register (terminal-kit df69f22, version 9) now agrees on 85 bindings.
- The one-map-with-layers Design canvas (79zGaaVT) is recorded in `Artifacts/one-map-layers-design/`. It is a mockup; nothing in it feeds the live map.

### 2026-10-26 (Week page, deep links, tides, thin bar)
- Tides are bundled, not fetched. The published page runs in a claude.ai frame whose CSP `connect-src` allows only claude.ai origins, so the Week tab's live `fetch` to NOAA was blocked for viewers (it worked from the build container and a local Playwright page, which is why the spike passed). `scripts/build_tides.py` now fetches CO-OPS hilo predictions (MLLW, english, `lst_ldt`) for 26 stations and writes `Artifacts/salmon-rivers/week/tides-data.js` (45 days, 134 KB); `tides.js` reads it, the Week tab says through which date, and marine Typical-season sheets show "Tides today" from the nearest bundled station. The page makes no network request at all (a test greps `tides.js`, `week.js` and both pages for `fetch(`/`XMLHttpRequest`). Re-run the script at least monthly and republish `week/tides-data.js`.
- The 26 tide station ids were verified against NOAA station metadata (`mdapi/.../stations/<id>.json`, listed under `type=tidepredictions`, state WA) on 2026-10-26:

      9447130 "Seattle" 47.60264 -122.3393
      9446484 "Tacoma" 47.2667 -122.4133
      9447659 "EVERETT" 47.98 -122.223
      9444900 "Port Townsend" 48.11122 -122.759674
      9449880 "Friday Harbor" 48.545277 -123.0125
      9449424 "Cherry Point" 48.862717 -122.75858
      9444090 "Port Angeles" 48.125 -123.44
      9443090 "Neah Bay" 48.370724 -124.601585
      9442396 "La Push, Quillayute River" 47.912838 -124.63574
      9441102 "Westport" 46.90431 -124.10508
      9440910 "Toke Point" 46.7075 -123.96694
      9445478 "UNION, HOOD CANAL" 47.3583 -123.098
      9445303 "Seabeck, Seabeck Bay" 47.6417 -122.828
      9445133 "Bangor" 47.7483 -122.727
      9446969 "OLYMPIA, BUD INLET, PUGET SOUND" 47.06 -122.903
      9446281 "ALLYN" 47.3833 -122.823
      9445958 "Bremerton" 47.5617 -122.623
      9447427 "EDMONDS" 47.8133 -122.383
      9445753 "Port Madison" 47.705 -122.525
      9448794 "ANACORTES, FIDALGO ISLAND" 48.5183 -122.62
      9449211 "BELLINGHAM" 48.745 -122.495
      9447929 "Coupeville, Penn Cove, Whidbey Island" 48.2233 -122.69
      9443361 "SEKIU, CLALLAM BAY" 48.2633 -124.297
      9441187 "Aberdeen" 46.9683 -123.853
      9440846 "BAY CENTER, PALIX RIVER, WILLAPA BAY" 46.6233 -123.945
      9440581 "Cape Disappointment" 46.281 -124.0463

  `build_tides.py` and `tides.js` use short names (Everett, La Push, Union) and NOAA's coordinates rounded to 4 decimals.
- Typical season has no month control, so the `month` parameter applies to Spawning only.
- The Year page has no season anchors, so Week links to the top of `../year/index.html`. Follow-up filed in TASKS.md.
- Built in a local copy because the repo was unreachable, then applied here on top of a capture of live 1792491424-046f (the service's injected document skeleton stripped from index.html; geo.js kept as generated, the live copy differed only in number formatting). Four existing tests (controls x2, design spacing, typical deep-link guard) were rewritten for the thin bar and the links.js boot; each was watched failing on broken code.
- The page's "No network requests from the page" rule has no exception (README).
- The map's control card became one 56 px row on Daniel's request; on phones the mode switch is a menu and species a filter icon. Unselected mode labels measure 4.85:1 dark / 4.77:1 light.
- Tests: 62 Node tests in 4 new files (`week`, `tides`, `links`, `tabs`); 196 Node tests in all (193 pass, 3 skipped without the local db); `check-week.mjs`: all checks passed, lowest tab-label contrast 4.77 (light) / 4.85 (dark).
- The three standalone artifacts (Where Salmon Spawn, Washington Fishing Year, Three Friends Fishing Hole) were deleted 2026-10-26 after being merged into the main URL.

### 2026-10-20 (project docs brought up to date)

- Decided: CLAUDE.md, README and SETUP now cover the `Artifacts/` web pages,
  their bindings, the Swift-to-JS rating coupling, the four test suites and the
  six new data scripts, none of which they mentioned. CI is recorded as Xcode
  Cloud only. Decision-log entries from 2026-09-20 and earlier moved to
  `STATUS-ARCHIVE.md` (this file was 45 KB). `Artifacts/fishing-year` got a
  README. `.playwright-mcp/` is gitignored. No app code or `fisheries.json`
  change; the only data change is the Fishing Year sync below.
- Every fish artifact on the account now has its source in `Artifacts/`:
  Three Friends Fishing Hole added; published source captured for the design
  system, App Store listing, interactive preview and Inside WAFishMap. Fishing
  Year had been republished outside the repo (Green River timing note, Three
  Friends stop note); those edits were copied into `seasons.json` and the
  rebuilt `data.js` is byte-identical to the live one. The Washington Fishing
  Map and Creel Table matched the repo already.
- Not verified: the 1.0 (10) review state. Whoever next has App Store Connect
  access reads it and replaces the line under Known broken.

### 2026-10-18 (web pages: Washington Fishing Map, Fishing Year, creel)

- Summary only; the commits and the page READMEs hold the detail. The salmon
  rivers page became the Washington Fishing Map with a Typical season mode
  (540 statewide sites rated by a JS port of `FishingRating`, pinned to the
  Swift tests). WDFW creel counts reach map sites only through the reviewed
  `scripts/creel_crosswalk.json`. Washington Fishing Year moved its data into
  `seasons.json`, sourced against the 2026-27 pamphlet and emergency rules.
  Skagit River and Puyallup River coho rows were added to `fisheries.json`
  (PRs 54, 55; `docs/research/2026-10-18-*-coho.md`). Retro: `docs/NOTES.md`.

### 2026-10-14

- Decided: act on the 2026-10-14 design critique's three priorities (plan
  `docs/superpowers/plans/2026-10-14-design-critique-priorities.md`, PR 51).
  "What's biting" now leads the launch and pier sheets, below the
  protected-area qualifier and above the WDFW footer. Fine print moved from
  tertiary to `DS.Ink.fineprint` (secondaryLabel; measured on system and
  secondary background: light 3.44 / 3.30, dark 6.36 / 5.95), floor 3.0:1
  because secondaryLabel itself sits near 3.5:1. Closed chip rebuilt like
  RatingBadge. Recentre touch area 44pt, drawing unchanged. Rivers and Heat are
  real Toggles with a custom `LayerToggleStyle` (solid `DS.Chrome` fill and
  white label when on): the system button toggle style was tried first and drew
  a pale wash with tinted text, nearly unreadable in dark, so the fill is drawn
  by hand to match what `ToggleTintContrastTests` measures. Species menu is a
  pill; map chrome names its type roles. The App Store screenshots predate this
  and are refreshed at the next submission.
- Found: giving the toggles an accessibility identifier replaced the default
  one (the label), which broke `RiversCrashProbe`'s lookup by "Rivers". The
  probe now looks up `riversToggle`. Anything that finds chrome by label needs
  the same check after an identifier is added.

### 2026-10-09 (workflow: fixing an App Review rejection and shipping the fix)

- Found: Apple's rejection screenshot (Download link on the rejected item in
  App Review) showed the sheet in the "forecast doesn't reach that date" state
  with no Apple Weather mark and no legal link. The attribution was only drawn
  beside a real reading. Fixed in `e953b69`, shipped as 1.0 (10).
- Decided: read the reviewer's own evidence before replying or rebuilding. The
  text of a rejection is stock wording; the attached screenshot is what they saw.
- The steps that worked, in order:
  1. Download the screenshot from the rejected item, open it, and find the
     state it shows. Grep the code for where that state renders.
  2. Fix, then add a device test that puts that exact state on screen
     (`-planDaysAhead 60` in `UITestSeam` for this one). WeatherKit does not
     work in the Simulator, so only `scripts/verify_weatherkit_device.sh` or a
     direct `xcodebuild test` on the iPhone can observe the mark.
  3. Prove the new test fails on the old code: restore the previous file with
     `git show <sha>^:<path>`, assert the diff is non-empty, run the test, watch
     it go red, then `git checkout` the file back.
  4. Save to history, then ship with the `testflight-shipper` agent
     (`app-ship`: upload, wait, internal group). It refuses to upload if Apple
     already lists the build number.
  5. Outside testers are a separate, approved step:
     `/opt/homebrew/bin/python3 ship.py submit-beta wafishmap --build N` (flag
     is `--build`, not a bare number). Read `status` back; a dropped connection
     on 2026-10-09 left it not submitted, and one retry went through.
  6. On the App Store version page: remove the old build, Add Build, pick the
     new one, click Save, then read the page back. Replying to Apple and
     "Update Review" are Daniel's. Browser clicks that remove a build or press
     Save were blocked by the auto-mode classifier in Safari, so these two
     clicks are his by hand.
- Gotcha: `verify_weatherkit_device.sh` counts any non-simulator device, so an
  offline iPad makes it refuse with "more than one physical device". It was
  bypassed with a direct `xcodebuild -destination platform=iOS,id=<iPhone UDID>`.
- Gotcha: bare `python3` cannot run `ship.py` (needs 3.10+ syntax); use
  `/opt/homebrew/bin/python3`.
- Done 2026-10-09 7:28 PM: Daniel saved build 10 and resubmitted; Apple read
  back 1.0 (10) Waiting for Review. A Waiting-for-Review submission has no
  reply box, so the reply to Apple's Sep 24 message cannot be sent unless the
  submission is cancelled; the fix goes in the App Review Notes instead (saved
  and read back, 2421 chars, WeatherKit section now says the mark and link show
  in every state). The attached .mp4 was not played, so whether it shows the
  date-too-far state is unverified.

### 2026-10-09 (1.0 (8) was rejected again on 09-24; build 9 is with internal testers)

- Found: App Store version 1.0 (8) is Rejected and has been since 2026-09-24
  06:18. This file said "Waiting for Review" for fifteen days because nothing
  read the status back after the 09-21 resubmission. Read today from the
  submission page (id `4cef16a5-876e-4b53-88de-c9c1997adcbd`): three messages,
  Apple 09-21 00:18, Daniel 09-21 17:29, Apple 09-24 06:18; review date
  September 24 on an iPhone 17 Pro Max; guideline 5.2.5 again. Apple's text:
  "The issues we previously identified still need your attention", then the same
  ask as before, a physical-device screen recording showing where WeatherKit is
  used, sent as a reply and kept in the review notes. The version page does list
  `WAFishMap-WeatherKit-attribution-review.mp4` as the review attachment, and
  Apple attached its own `Screenshot-0924-061726.png`, not opened here. Not
  known: why the recording did not satisfy the reviewer. No reply was sent and
  nothing was resubmitted today.
- Done: 1.0 (9) uploaded from `1437920` through `~/developer/app-ship` and read
  back from Apple as VALID, in beta testing in the `Internal` group, not in
  `insideout`, beta review not submitted. The upload was accepted on the 1.0
  train. The submission page still shows build 8, Rejected, last updated by
  Apple, so the upload changed nothing there.
- Found, minutes later: build 9 is with outside testers too. `app-ship`'s run log
  has `submit-beta` at 18:13 and Apple now reads beta review APPROVED, external
  in beta testing, groups `Internal` and `insideout`. It was run from another
  session, which recorded it as Daniel's; the line above was true when read.

### 2026-10-09 (pin spoken text saved for build 9; the probe still fails)

- Decided: the pin and cluster label change from 2026-10-07 is saved and goes out
  in the next TestFlight build. Observed today on the iPhone 18 Pro simulator,
  iOS 27.0: the app builds, the unit plan ran 331 tests in 53 suites with none
  failing, and `PinSpokenTextUITests` ran 1 test and passed, printing
  `Boston Harbor, Boat launch, rated Good`. Not done: that test was not run
  against the old label and value split, so it has not been seen to fail.
- Found: the rewritten `PinVoiceOverProbe` fails 3 runs of 3 at its first
  `describe(pins())`, line 27, with "No matches found for Element at index 26".
  `allElementsBoundByIndex` resolves each element when `.label` is read, and the
  map has redrawn by then. It stops before `isOurs` or the zoom loop run, so
  nothing past that line is shown to work, and the cluster label has no on-screen
  coverage. Saved as it stands because the version before it could not pass
  either (it read `value`, which MapKit never exposes). It is in the default
  test plan, so a full default run goes red on it.

### 2026-10-07 (test plans linked: explicit default, unit plan second)

- Decided: the scheme lists two explicit plans, `WAFishMap` (default, both bundles)
  and `WAFishMapUnit`. Linking only the unit plan beside the automatic one emptied
  the automatic plan: the default run failed with "There are no test bundles
  available to test", while the untouched scheme listed 341 tests on the same
  simulator. That failure is the red the comparison was watched going.
- Observed (Xcode 27.0, `-enumerate-tests`): default plan = the pre-change set
  exactly, 331 unit + 10 UI; unit plan = the 331 alone. The unit plan then ran:
  331 tests in 53 suites passed.
- Not done: the Xcode Cloud workflow still only builds. Adding a Test action that
  uses `WAFishMapUnit` is a step in Xcode or App Store Connect; the API route
  needs the issuer id this Mac does not have.

### 2026-10-06 (colour-blind pass on the ramp: no ring, gate added)

- Decided: no ring channel. Measured with `WAFishMapTests/CVDSeparationTests.swift`
  (exact, resolved tokens, Machado 2009 severity 1.0, linear RGB, iPhone 18 Pro) and
  looked at in all four simulated frames (`scripts/cvd_check.py` regenerates
  them beside the pinned frames in `docs/design/ramp-check/`; not committed). Slow is safe. Criterion: a pair fails when dL* < 12 AND dE76 < 30.
- Numbers (dL* / dE76), light then dark:
  - deuteranopia: fair->good 12.71/18.8, 14.01/21.9; good->prime 11.11/19.5, 11.14/21.1
  - protanopia: fair->good 17.51/24.7, 18.99/28.8; good->prime 18.14/39.6, 17.79/40.4
- good->prime fails the colour test under deuteranopia in both appearances. It is
  carried by glyph ink (black on Good, white on Prime), asserted on the real views.
  fair->good passes but is the weakest pair and has no second channel: 0.7 L* above
  the floor in light deuteranopia, and in the dark frames the pins read as two
  yellows (Fair vivid, Good muted). If that ever matters, the ring goes on Fair, not
  Prime (the old "option C on Prime" note predates the ink observation); Good is ~85%
  of the map in season, so ringing it would ring everything.
- The gate fails the build when a token move leaves a pair neither separated by
  simulated colour nor by ink. It was watched failing first: the first version
  failed on good->prime until the ink channel was asserted; with the deuteranopia
  matrix swapped for identity, three control assertions went red.
- Plan's calibration claim corrected: pure red/green keeps a real lightness gap
  under a correct simulation, so it does not fail the dL*/dE criterion. The known-bad
  control is a green built to match red's simulated green channel (dL* 0.3, dE76 7.9).
- Simulated frames are approximate (P3 screenshots read as sRGB); the Swift numbers
  are the exact ones.
- Stale line fixed: "11pt dot above 150km" died with the dot renderer in `868aa35`.
- Runbook note: after the mutated run finished, `xcodebuild` stayed alive with the
  results final; killed by PID (matches the 2026-09-16 hang).

### 2026-09-21 (App Review rejection 5.2.5, WeatherKit attribution)

- Found: 1.0 (6) rejected under 5.2.5. Apple's message: the reviewer could not confirm WeatherKit attribution (Apple Weather mark + legal source link) and wants a physical-device screen recording showing where WeatherKit is used, in App Review notes, for every future submission.
- Decided: harden the attribution and ship a new build rather than reply-only. The old mark was 12pt, `.tertiary`, with only a chevron as the legal link. Now 20pt full contrast plus a labelled "Other data sources" link (`8339996`); the device UI test asserts both.
- Observed on iPhone 16 Pro: the device UI test failed with the legal-link id deliberately broken (live WSW 4 mph reading on screen, mark assertion passing), then passed unmodified in 7.7s.
- Uploaded from `562604b` via exportArchive; ASC refused 1 and 7 (`previousBundleVersion: 7`, so a 7 exists that this log did not create) and accepted **build 8**.
- Found: `1ced71d` (NDBC throwing URL) left `WAFishMapTests` uncompilable, so the unit suite had not run since. Fixed in `8339996`; 275 tests pass.

### 2026-09-21 (Workflow Audit & URL Safety)

- **CI Restored:** Configured Xcode Cloud (`ci_scripts/ci_post_clone.sh`) to replace the disabled GitHub Actions runners. Enforces the strict iOS 26 SDK requirement seamlessly using Apple Developer compute.
- **Testing Fixed:** `scripts/run_sim.sh` now correctly accepts a `test` argument, aligning with the `README.md` instructions and restoring command-line UI testing.
- **Safety:** Replaced force-unwrapped static URLs in `NDBCLoader` with throwing `invalidURL` constructions to prevent silent upstream parsing crashes.
