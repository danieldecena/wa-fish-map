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

- **Map never frames Washington without a location fix** (seen 2026-09-16 with
  location cleared). Every good framing today coincided with a fix, so the initial
  fit in `FishingMapRepresentable` may never run. Reproduce with
  `simctl location clear` before touching code.
- Branch `claude/goal-followups` (shore snap, VoiceOver labels, cluster scale) is
  pushed with no PR yet.

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

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

### 2026-09-03 (four counties, checked against WDFW rather than recalled)

- Decided: Pierce, Mason and Thurston get freshwater overrides; **Kitsap keeps
  the statewide default on purpose.** Every species present in more than 15% of
  Kitsap's 13 WDFW lowland lakes is already one of the statewide four (Rainbow
  76%, Largemouth 53%, coastal cutthroat 30%). Recording that so the item is not
  reopened as unfinished - a county with no entry is now an answer, not a gap.
- The evidence is WDFW's own lake database, not recall. Its lowland-lakes view
  takes `county[]` and `species` as term ids, so a species can be counted across
  every lake in a county: Yellow Perch is in 73% of Thurston lakes, 60% of
  Pierce, 40% of Mason and 7% of Kitsap. Rock Bass is the sharper signal - WDFW's
  own species page names King, Pierce, Snohomish and Thurston and calls it "not
  common in the state", which is exactly what a county tier is for.
- King and Snohomish were scraped as the control. Without them there was no way
  to tell a defensible bar from an arbitrary one, and they disagree: King's
  Yellow Perch override sits at 100% of its lakes, Snohomish's Smallmouth at
  10%. So the tier is editorial, not threshold-driven, and the new rows were
  chosen to sit at or above the stronger of the two.
- Fixed while verifying, both shipped defects rather than improvements:
  - King's Yellow Perch peaked in Aug-Oct. WDFW says the bite is "best in the
    summer after they finish spawning in April-May" and "begins to decline in
    the fall". Corrected to Jun-Aug best, May/Sep good, and the new counties
    carry the corrected months rather than inheriting the wrong ones.
  - Spokane's Rainbow Trout note read "Liberty, Newman, and other lowland
    lakes." Those are two specific Spokane County lakes, so the note was wrong
    at every other freshwater site in the county - the same defect
    `NoteScopeTests` was built for, in prose its regex does not match. This is
    the second instance of the "Potholes" class, and it confirms the rule binds
    the editor and not just the test.
- Observed, not inferred: WDFW's live layer returns `CountyName` as a bare name,
  and the four keys match exactly against 477 statewide sites (Pierce 15, Mason
  23, Thurston 18, Kitsap 12). A key like "Pierce County" would have made the
  override silently never fire. Suite: 171 tests in 26 suites pass, UI target 4
  with 1 device-gated skip, `** TEST SUCCEEDED **`.

### 2026-09-03 (rivers are lines, and a line cannot be contained)

- Decided: add rivers to the map in three slices - draw them, colour them by
  live USGS flow, then make them tappable. The design is in
  `~/.claude/plans/sorted-conjuring-hollerith.md`.
- The structural reason this is not a small change: every fishable thing in the
  app is a *point* inside a *polygon*, and `MarineArea.contains(_:)` is how a
  point earns its colour. A river is a line that crosses counties and holds
  different fish at the mouth than at the headwaters, so no containment test can
  answer what it is worth today.
- Colour comes from live USGS flow, not curated guidance. Rivers close by river,
  by reach, by run, sometimes mid-week by emergency rule, so an editorial rating
  on a river is a far stronger claim than the same rating on a marine area.
  Flow is a fact that holds whether or not the river is open, which is the same
  standing tides and NDBC wave height already have.
- Flow reuses the existing blue-amber-orange-red ramp rather than minting a
  fourth colour vocabulary. The mapping is deliberately non-monotonic: blown out
  and bone dry both read Slow, the fishable window reads Prime.
- Ungauged named rivers draw neutral gray, the colour that already means "no
  rating available" on inland launches. Borrowing the nearest basin gauge was
  rejected - a tributary can fish well on a day its mainstem is unfishable, and
  that is exactly the case where a manufactured reading does harm.
- Geometry is bundled, not fetched. WDFW's `MajorFishingArea` MapServer has no
  hydrography layer, so this is a new source either way; bundling sidesteps the
  `exceededTransferLimit` guard and draws with no network.
- The four default-covered counties (Pierce, Mason, Kitsap, Thurston) moved out
  of Next Up prose and into `TASKS.md` as a tracked item, so "if desired" stops
  being a reason it never gets looked at.


### 2026-09-02 (an invitation is only as good as the inbox it lands in)

- Pauline cannot activate her App Store Connect invitation: it was sent to
  `romulopauline@yahoo.com`, an address she no longer has access to. Nothing in
  App Store Connect reports this. Her row simply stays grey and pending, and
  the Add Testers dialog keeps offering one name, which reads like a bug in the
  group rather than a dead mailbox.
- The generalisable part: the internal route's cost is not the invitation, it
  is that the invitation must reach an inbox the person still reads *and* be
  the Apple Account their iPhone signs in with. Two conditions, neither
  visible from the console, both silent when unmet.
- Also ruled out tonight, so they are not re-explored: Sandbox test accounts
  (in-app purchases only), Sandbox Family Sharing (same), the Safari Web
  Extension packager (wrong software kind), adding testers directly to a build
  (still external, still needs review), and the Business tax/bank forms (they
  enable payment, they do not create a legal entity, and the Free Apps
  Agreement is already Active). None of these distribute an app.
- `/Applications/Xcode.app` is Xcode 26.6 and cannot run on this macOS 27.0
  beta; `Xcode-beta.app` (27.0) is what `xcode-select` points at and what every
  build used. Re-downloading from the App Store cannot help, since the store
  only ships the stable build. Left for the user to delete by hand (root-owned).
- Xcode Cloud declined for now: it removes a constraint (one shared Mac) that a
  single developer does not have, and it is metered past 25 compute hours.
  Revisit when 90-day TestFlight expiry starts costing a manual rebuild.

### 2026-09-02 (TestFlight: both routes, because external made them wait)

- Decided: run internal testing *as well as* external. External was chosen
  first and is still in flight, but App Store Connect will not let anyone join
  a public link until Beta App Review approves the build, and the wait was the
  thing being optimised against. Internal has no review at all.
- Invited Joseph Decena and Pauline Romulo as App Store Connect users with the
  `Developer` role. Both landed on `All Apps` access rather than WA Fish Map
  only; accepted knowingly, since it is the account's only app. Revisit if a
  second app ever ships.
- Cost of this route, recorded so it is not rediscovered: each person needs an
  Apple Account on the team and has to activate an emailed invitation, which
  expires in about 7 days. That is exactly what the external route avoided.

