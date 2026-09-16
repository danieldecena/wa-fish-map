# WAFishMap — Status

## Confirmed working

- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; the
  "Oregon" polygon is filtered out of the map, not seeded) plus 11 freshwater counties. WDFW-checked
  2026-08-30.
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
  as four explicit stops. Above 150km altitude a site draws as an 11pt dot
  instead of a balloon pin.
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
  list first, precomputed per site in `FishingMapModel.indexWaterbodies`). Baker
  Lake sockeye is the only shipped row — no river carries one yet.
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

## Next Up

- Silver Lake -> North Silver Lake lake-facts match is unverified against WDFW.

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

### 2026-09-16 (same-name rivers split; guidance tests merged in)

- Decided: a river name splits into separate features where its NHD pieces
  sit more than 40 km apart (unrelated rivers 77-236 km; gaps inside one
  river at most 24.6 km). Split runs get creek-style ids; only the run
  nearest the name's USGS gauge is `gauged` and owns flow stats and colour.
  Split rivers, like creeks, never resolve a waterbody note. 6 names -> 13
  runs; 1302 of 1312 features unchanged. The 4 new tests fail with
  `isSplit` forced false. 956fcde.
- Decided: took the site/pier/river/popover guidance UI tests from the
  unmerged `test/guidance-on-every-sheet` branch but not its heat change,
  which zero-weights poor and unrated spots: a product change, not a fix.
  Its river preselect was renamed to `River.ID` for the MKMapView view.
- Observed: Harper Pier (CLOSED) draws a gray pin and a gray Closed badge
  on live data. The iPad buoy reload fix is unit-green but not seen on an
  iPad (one simulator at a time).
- Observed: no `Simulator.app` exists in either installed Xcode; the running
  Simulator window was launched from a since-replaced bundle, so it cannot be
  reopened by path or bundle id. An auto-commit hook also committed session
  work under its own messages twice (efb3a8b, cd6ef01).

### 2026-09-16 (launch indexing measured)
- Decided: filter rivers once per `indexWaterbodies` pass, not per site. Measured
  with a throwaway Swift Testing timer on the real bundled rivers (1,312), lakes
  (653) and guide, plus 480 synthetic inland launches, iPhone 17 Pro simulator on
  Apple silicon (not an A7 device), 5 runs: `indexWaterbodies` min 142.3 / median
  146.4 ms before, 100.8 / 102.3 ms after; `indexSitesToAreas` 107.7 / 109.9 ms.
  The per-site `filter` alone was 36.7 / 37.1 ms, about 25% of the pass.
  Resolved counts unchanged (256 waterbodies, 215 lakes). `indexSitesToAreas`
  got the same fix afterwards (6be7588), not re-timed. The timer ran 2.5 s, so it was not kept; A7 profiling stays open.

### 2026-09-16 (lake facts on the launch sheet)

- Decided: lake facts from WDFW's 2014 lakes points, matched by acreage reach + name check; distance alone matched Lyle Lake to Herman Lake.

### 2026-09-16 (camera, clusters, creeks, failed reads)

- Decided: the camera is bounded to Washington (cameraBoundary plus a 3,200 km
  zoom-out cap; 1,600 km cut off the coast). Clusters draw a fixed 1.2x, chosen
  over main's count-based scaling. #17, 9b3a4fb.
- Decided: creeks ship split into connected runs with unique ids (same-name
  creeks are separate features) and never resolve a waterbody. Stream order is
  judged per run, not per segment, which had silently dropped Clover and
  Issaquah creeks. 1,025 creeks. Unrated water drew at 45% gray / 0.6 pt and was
  invisible, which read as missing data; now 75% / 1.2 pt floor. #17.
- Decided: an empty WDFW layer, MPA layer, pier fetch or USGS fetch is a failed
  read, never "0 sites", "clear" or "gauge not reporting". Mutation-checked. #18.
- Closed: "map never frames Washington without a fix" (#16, #17) and the
  `claude/goal-followups` branch (merged as #14).

### 2026-09-16 (shore snap, VoiceOver labels, cluster scale)

- Decided: marine area matching snaps to the nearest area within 150 m when a point
  is in no polygon. Live WDFW: 29 of 63 piers outside every area (28 within 1 m),
  saltwater launches 22-108 m out; nearest real lake launch 639 m. Dash Point now
  reads Marine water with tides. 7b904bd.
- Decided: pins, clusters, legends and badges carry VoiceOver text. Pin text is
  unit-tested; the legend label was seen in a UI run; pin labels on screen were not
  (XCUITest pinch rotates instead of zooming). a8d5464.
- Decided: clusters scale 1.1/1.2/1.3x by count, applied in prepareForDisplay
  because MapKit reset a transform set earlier. Seen larger on screen. 023680d.
- Observed: UI test runs reinstall the app and leave the shared simulator without
  location; restore with `simctl privacy grant` and `simctl location set`.

### 2026-09-16 (map legibility: outlines, breadth colour, closed piers, directions, fish size)

- Decided: "season may be closed" draws as an outlined marker (pale balloon,
  rating colour on the glyph), never gray. Gray already means no guidance, and
  the app holds no authoritative closure data. For All, outlined only when every
  top-rated species (or cluster member) is flagged. 3ba2b1e.
- Decided: the All-species colour is the rounded mean of the top three species,
  not the max. September painted every marine area Prime (each has 1-4 peak
  species) and every statewide-inland launch Prime via Cutthroat. Per-species
  ratings unchanged. Inland pins now read uniformly Good in September because
  the statewide freshwater list is the same everywhere; that is data, not code. 6fc64b8.
- Decided: WDFW flags closed piers only by "(CLOSED)" in the pier name (3 live:
  Anacortes Municipal, Harper, Luhr's Beach Dock). Those pins fade gray and carry
  no rating; the sheet shows a Closed badge. Launch "Closed to vehicles <dates>"
  text stays free text in the sheet, not parsed ("4th Friday in April"). d2ece00.
- Decided: directions use a maps.apple.com driving link, not MKMapItem, whose
  coordinate init is iOS 26 only (target is 18). Observed: Maps opened a driving
  route to Dockton Park Pier incl. the Tahlequah ferry. Return to the app is
  iOS's own top-left "< WAFishMap" breadcrumb; the sheet is still open on return.
- Decided: species rows show `fish.fill` sized log-scale by a hand-entered,
  unverified typical weight (SpeciesSize.swift); shellfish/squid get none. Not
  yet seen on screen: the shared simulator was being driven by another session. 721937e.
- Season open/close sources (research, not built): WDFW emergency-rule RSS feed
  and date-range rule search; the annual pamphlet (PDF, July 1-June 30); no
  season fields found in WDFW ArcGIS layers checked; Fish Washington app has no
  public API; reuse terms unconfirmed. Any use must stay "verify with WDFW".
- Water emphasis (answered, not built): the Rivers/Heat toggles already mute the
  basemap; rivers.json carries 287 named rivers only, so "full streams" needs a
  new hydrography source (USGS NHD / WA DNR), a data-size decision.
- Observed: the shared iPhone 17 Pro simulator is used by another session's test
  runs (crash reports from a HeatMapTests test that does not exist here), and
  MapCoordinatorTests' recentre test hung 10 minutes in a full run. Run targeted
  suites, or give each worktree its own simulator.

### 2026-09-16 (privacy manifest declares nothing, on purpose)

- Decided: `WAFishMap/PrivacyInfo.xcprivacy` is all-empty: no tracking, no
  collected data, no required-reason APIs. Grep found no UserDefaults, file
  timestamp, boot-time or disk-space calls, and no third-party packages. The
  user's location never leaves the device: WeatherKit is queried with the
  launch site's coordinate, and WDFW/NOAA/USGS/NDBC requests carry only fixed
  queries or station ids. Adding any of those APIs, an SDK, or a request that
  sends the user's position means updating the manifest and the App Privacy
  answers together. Verified the file ships in the built .app.

### 2026-09-16 (the Oregon marine polygon is hidden, not seeded)

- Decided: drop WDFW's "Oregon" area (North of Falcon, WAC field "Oregon's
  Rules") in `MapScope.filter(marineAreas:)`. Oregon regulates those waters, so
  seeding Washington guidance there would be wrong, and the user confirmed the
  app is Washington only. Matched on `areaName`, not a WAC prefix, so a WDFW
  format change cannot empty the whole layer. `MapScopeTests` failed with the
  filter reverted and passed with it; unit suite 208/31 passed, rc=0.

### 2026-09-16 (GitHub Actions billing dropped)

- Decided: removed the GitHub Actions billing item from TASKS, Known broken and
  Next Up at Daniel's request. PR #4 already merged (13c45d4); CI stays unrun
  until billing is revisited.

### 2026-09-16 (strict-concurrency warnings cleared)
- Decided: clear them with isolation annotations, not code changes. The
  immutable statics (USGS date formatter, two test regexes) are
  `nonisolated(unsafe)`; test suites calling main-actor statics and the XCUITest
  class are `@MainActor`. Clean build-for-testing: 0 concurrency warnings, 5
  unrelated lint warnings left. Unit suite 198/29 passed, rc=0 (`30fd9d9`).
- `indexWaterbodies()` cost on the live bundle is still unmeasured (plan Step 5):
  three simulator attempts died to contention (server died, boot timeout,
  shutting down). The instrumented build sits detached in `../wa-fish-map-timing`.
- The project CLAUDE.md names the simulator `iPhone`; no such device exists now,
  only `iPhone 17 Pro`.

### 2026-09-16 (flow stats checked against USGS, not just on screen)

- Decided: "Stamp the remaining 6 flow-stat gates" was never defined (coined once
  on 2026-09-03). Redefined as a source check and built as
  `scripts/verify_river_stats.py`: every bundled percentile row compared with
  nwis/stat, and each river's live reading traced to the band it draws.
- First run: 69 of 77 rivers matched exactly; 8 had drifted because USGS rolled in
  water year 2026 (Chehalis 1/15 p50 5320 -> 5180). Regenerated `river_stats.json`,
  same 77 rivers and same gauges; re-run 0 drift. The stale table was the failing
  input, the regenerated one the passing input.
- Swift resource tests not re-run (simulator held by another session); their
  invariants (12 months, 5 ascending percentiles, >=10 years, 10 Feb-28-only
  gauges) were checked on the new file in Python.

### 2026-09-16 (the waterbody river tier, and the Spokane row refused)

- Shipped the river waterbody tier (plan
  `docs/superpowers/plans/2026-09-16-river-waterbody-tier.md`, five slices). An
  inland launch or pier now inherits a river's `byWaterbody` rows when it sits
  within 150 m of that river's line: `River.nearest` (pure, confluence-aware),
  a curated-first resolver on `FreshwaterGuide`, and a precomputed
  `FishingMapModel.indexWaterbodies` index so pins never re-scan geometry on
  render. The reachability gate in `NoteScopeTests` now accepts an exact river
  name from `rivers.json` as well as a curated facility, with a misspelled-river
  control proving it still fires.
- **Refused the Spokane River row (plan Task 5, Step 2b — no data change.)** A
  single river-wide note is not defensible: the WA reach's trout rule changes
  reach by reach. Above Nine Mile Dam to the Idaho line is selective-gear,
  release-all-but-hatchery, closed Mar 16 to late May (the classic wild-redband
  fly water). Long Lake and Little Falls reservoirs run landlocked-salmon rules.
  The lower Spokane Arm of Lake Roosevelt is year-round, limit 5, adipose-clip
  retention. Gear, season, and bag structure all differ, so "catch-and-release
  for wild redband" is true only on the top reach and cannot ride the whole
  river. Sources: WAC 220-312-050 entries #308/#197/#187/#191
  (https://app.leg.wa.gov/wac/default.aspx?cite=220-312-050,
  https://www.law.cornell.edu/regulations/washington/WAC-220-312-050); Spokane
  Falls TU reach guide (https://spokanefallstu.org/guide-to-fishing-the-spokane-by-marc-fryt/)
  and Lake Roosevelt redband rule
  (https://spokanefallstu.org/columbia-river/new-fishing-rules-effect-lake-roosevelt-protect-redband-rainbow-trout/).
  If a row is ever wanted, scope it to "Spokane River above Nine Mile Dam" as
  its own curated waterbody, not to the river name.
- So no river ships a `byWaterbody` row yet; Baker Lake (a curated lake) stays
  the only row. The tier's plumbing is proven by unit tests
  (`WaterbodyResolverTests`, `FishingMapModelTests.anInlandLaunchBesideARiverGetsTheRiversRows`),
  not by a screenshot — there is no river row to photograph, which is the honest
  state, not a skipped step.

### 2026-09-16 (finished means a public App Store release)

- Decided: the project's end state is a public App Store release, not a private
  TestFlight beta. The plan runs in four phases: feature-complete, release hardening
  (privacy manifest, attribution, offline states, accessibility), store listing,
  then ship. Its 19 new items are in `TASKS.md`. Plan file:
  `~/.claude-work/plans/twinkling-gliding-neumann.md`.

### 2026-09-03 (the inbox was 11% ours, and none of ours was news)

- Drained this project's share of the capture queue: 214 of 1,965 rows, now 0.
  Backup at `~/.claude/pending-suggestions.tsv.bak-20260903-225852`; the queue
  itself is down to 1,751.
- Nothing was filed, and that is the result rather than a shortcut. All 214 rows
  were read. Every finding is already in this decision log or is transient
  narration ("PR #4 is open with 38 commits"), and every proposal is done, is
  already a `TASKS.md` item, or was an instruction to the assistant mid-turn
  ("Report the device result the moment it lands"). Two looked like live defects
  and were checked against the code rather than assumed: Boston Harbor's
  freshwater misclassification is fixed and asserted in `FishingMapModelTests`,
  and the walleye "Prime at 11:59 PM" note names `bestTime`, which is display-only
  and reaches `SiteDetailSheet` but never the rating.
- The task was mis-scoped, which is why it looked enormous. The queue is
  **global**, not this repo's: `~/.claude/pending-suggestions.tsv` spans 117
  sessions across every project, and `inbox.py file` writes to `~/TASKS.md` by
  default. Filing it here would have moved other repos' work into this one. What
  is left is theirs to drain: 497 home, 461 unattributed, 190 headwaynurse, 169
  `.claude`, 96 radio, 58 Tools.
- The capture hook produces roughly one row per two assistant turns and nothing
  consumed it, so the queue is a transcript rather than a backlog. Read for what
  a session might have dropped, not as a list to work through.
- Method note, because the first attempt reported nothing and looked like it
  worked: `inbox.py` derives a row id from the line **including its trailing
  newline**. Hashing the stripped line produced 214 plausible six-hex ids that
  matched nothing. The tool refused on the first one, and the row count was
  unchanged - which is the only reason it was caught.

### 2026-09-03 (the camera residual was never about the load)

- Closed the "pre-load residual", and the description of it in Known broken was
  wrong. The WDFW load had nothing to do with it. `userGesture` set
  `userMovedCamera` through `DispatchQueue.main.async`, so the claim landed one
  runloop turn after the touch, while every reader of the flag is synchronous -
  the `onChange` that eases to a location fix, and the initial fit. Any fix
  delivered in the same turn as a gesture read `false` and recentred a camera
  the user had just moved. Pre-load was simply when a first fix is most likely,
  not the condition.
- Fixed by writing the flag synchronously. The hop is still correct in
  `regionDidChangeAnimated` and stays there: MapKit can raise that from inside
  `updateUIView`'s own `setRegion`, whereas UIKit dispatches a gesture action
  outside SwiftUI's update pass, so there is nothing to hop off.
- Observed failing first. The three new `MapCoordinatorTests` went red on the
  two claims and green on the control before the fix, which is what separates
  "claims the camera synchronously" from "claims it for any recognizer at all".
  A constant binding cannot see a write, so the tests bind the flag to a box.
  171 tests -> 174, all passing, `** TEST SUCCEEDED **`.
- Standing lesson, since this is the second stale Known-broken entry this week:
  a disclosed residual is a hypothesis with an expiry date. Reproduce it before
  writing a fix for it - this one had been narrowed twice by unrelated commits
  and its stated cause no longer matched the code at all.
