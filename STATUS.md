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
  list first, precomputed per site in `FishingMapModel.indexWaterbodies`). The
  shipped rows are walleye on four Grant County lakes; no river carries one yet.
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

- Colour-blind reading of the rating ramp is untested. Prime, Good and Fair are
  three adjacent warm hues separated mostly by lightness, which is the case
  deuteranopia and protanopia collapse. Slow is safe. The ramp plan's option C
  (a ring channel) is the fix if it matters.
- The 44pt marker tap target is asserted as geometry only. An edge tap on
  hardware is the other half.

## Next Up

- Colour-blind pass on the ramp, or an explicit decision not to do one.
- Everything in the App Store lane is `[you]`-blocked: the ASC resubmit and the
  post-approval release.

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

### 2026-09-20 (rating ramp: one definition, contrast measured, closure becomes a shape)

- Decided: the ramp keeps deferring to Apple's system colours. The plan expected
  the stops to be too close in lightness and had granted a platform-deference
  exception for hand-picked literals. Measured on device instead: every adjacent
  pair clears ΔL* 12 in both appearances (slow→fair 27.3/27.3, fair→good
  14.4/15.8, good→prime 13.3/13.3), so the exception was not needed and was not
  taken. `RampLightnessTests` holds the numbers and fails the build if the gap
  closes.
- Decided: `FishingRating.color` returns `DS.Rating` and the four literals in
  `ColorRamp.swift` are gone. There were two ramps; the views drew the one that
  could not adapt, so the dark map drew the light ramp.
- Decided: the rating colour is no longer the badge's text colour. Label and
  wash moved together on one slider, so every state failed 4.5:1 in light and
  Fair reached 1.38:1. Label is `.primary`; the ramp keeps the fill and the
  stroke. Dark passed throughout beforehand, which is why this survived: a fix
  checked only in dark would have looked complete.
- Decided: **"season may be closed" no longer draws as a pale balloon.** This
  reverses the 2026-09-16 map-legibility decision (now in STATUS-ARCHIVE.md). That marker put the rating colour on
  the glyph, which measured 1.51:1 for Fair and 2.31:1 for Good against a 3:1
  floor. Neither fix that kept colour on the glyph worked: reaching 3:1 needs a
  glyph at L* ≤ 61.7, which means darkening Fair by 22.5 points until it is no
  longer yellow; and washing the balloon instead collapses the stops to ΔL* 3-9,
  failing the ramp's own gate. So the balloon now always carries the rating at
  full strength, and closure is carried by a badge subview
  (`SiteMarkerView.applyClosureBadge`) — a shape, so colour does one job.
  A subview rather than a badged `glyphImage` because a cluster's glyph is its
  member count, and overwriting it would trade one fact for another.
- Decided: the marker glyph's ink is picked by measured contrast against the
  balloon, not fixed to white. White failed on the light end of the ramp (Fair
  1.51:1, Good 2.31:1). A hardcoded list of "the light stops" would go stale the
  moment a token moves, and the stops are themselves dynamic.
- Observed: `** TEST FAILED **` from a compile error with zero tests run is
  indistinguishable from a firing assertion if only the verdict line is read.
  This happened twice in one session and nearly got written up as a successful
  control both times. Check the error count and the case count before reading
  any red as evidence.
- Observed: `withKnownIssue` wrapped around both appearances failed with "Known
  issue was not recorded", because the dark case genuinely passed. It caught its
  own misuse, which is the behaviour to want from it.
- Not done: nothing here has been looked at. The arm's-length check on the
  regional frame in both appearances is slice 6 and is the real gate. The
  numbers say the proxies pass; they do not say the map reads better.

### 2026-09-20 (slice 6: the frames were looked at, and the gate does not pass)

- Decided: the glyph ink rule is "white unless white fails 3:1", not "whichever
  ink contrasts more". The maximising version turned every glyph black,
  including Prime and Slow where white already clears the floor (3.57 and 3.52
  in light). It passed the contrast gate and looked wrong: white on a saturated
  marker is the platform's own convention. Caught only by looking at the frames,
  which is the entire argument for this slice existing.
- Observed: the ink rule works on screen. Orange carries black (white measures
  2.31 on it), Prime carries white (3.57). That second channel also helps Prime
  separate from Good, which was not planned for.
- Observed: the dark frame now draws the dark ramp. It previously drew the light
  one, because the literals could not adapt. Slice 1 confirmed by eye.
- **Not passed: slice 6's arm's-length gate.** The failure is in the observation,
  not demonstrably in the ramp:
  - Light frame is a genuine regional view and shows Fair, Good and Prime.
    Fair separates from Good clearly. Prime separates from Good, but weakly --
    consistent with their ΔL* of 13.3, the narrowest pair in the ramp.
  - Dark frame landed at a much tighter zoom and shows only Fair and Good. Two
    of four ratings at a non-regional zoom cannot answer "do the ratings
    separate in dark". It is not evidence either way.
  - Slow never appears in any frame, so the Prime/Slow collision flagged when
    the ramp was measured (within half an L* of each other, differing by hue
    alone) is still completely untested on screen.
  - The closure badge never appears in any frame, so the 14pt mark on a marker
    drawn at 0.8 has not been seen at all.
  - The light frame is roughly 85% Good. Separation reads there because the
    other ratings are rare exceptions, which is a much weaker test than a mixed
    map.
- Observed: the camera is not deterministic between runs of
  `scripts/app_store_screenshots.sh`. Two runs twenty minutes apart produced
  different regions and different zooms from the same 15 s wait, so the frames
  are not comparable to each other and cannot be a repeatable gate as they
  stand.
- Next: the gate needs a frame that contains all five states at a fixed camera.
  The `-uiTesting` seam already exists for the sheets and is the obvious place
  to add it. Until then slice 6 is open, and the plan's fallback (option C, a
  ring channel on Prime) should not be adopted or rejected -- there is no
  observation to justify either.

### 2026-09-20 (slice 6 passes, on a frame built to make it answerable)

- Decided: the ramp gate gets its own frames, `docs/design/ramp-check/`, taken
  at a pinned camera and a pinned month. The App Store frames could not answer
  it: they reframe themselves from the location fix, so two runs produced
  different regions and zooms, and in September they are ~85% Good, which tests
  nothing. `-uiTestingRegion lat,lon,span` is the fourth and last argument on
  `UITestSeam`, and it exists for the same reason the other three do.
- Decided: November at 47.95,-123.00 span 1.3. November is the one month that
  puts all four ratings in adjacent Puget Sound areas — Prime in 10/11/12, Good
  in 8-2 and 13, Fair in 8-1 and 9, Slow in 5/6/7 — so one frame holds the whole
  ramp.
- Observed: the span is load-bearing. At 2.0 the frame came back as a violet
  heat map with no pins at all, because `MapDetailLevel` hands pins over to the
  density overlay past 400 km of camera distance. That is the app working as
  designed, and it would have read as "the pins disappeared" to anyone who did
  not check the threshold.
- **Slice 6 passes.** Prime, Good, Fair and Slow are all separable at arm's
  length in both appearances, which is more than the three bands the plan asked
  for.
- Observed, and it corrects an earlier worry: the Prime/Slow collision flagged
  when the ramp was measured — within half an L* of each other — does not
  matter on screen. Red and blue differ so strongly in hue that equal lightness
  never confuses them. Lightness was the wrong thing to worry about for that
  pair.
- Observed: the weak pair is **Good against Fair**, not Prime against Good.
  Orange and yellow are adjacent warm hues, and since slice 4 both carry black
  glyphs, the ink channel gives no help telling them apart. They do separate,
  but they are what would fail first if a stop moved.
- Not tested, and the real remaining risk: **colour-blind reading.** Prime, Good
  and Fair are three adjacent warm hues separated mostly by lightness, which is
  the case deuteranopia and protanopia collapse. Slow is safe. The plan's
  fallback (option C, a ring channel) is the answer if this matters, and the
  gate as worded does not test it, so nothing here says it is fine.
- Observed: the closure badge works in both appearances. It inverts correctly
  (black circle in light, white in dark), stays legible on a marker drawn at
  0.8, and does not collide with a cluster's member count — which was the reason
  it is a subview rather than a badged glyph image.
- Still not verified: the 44pt tap target. It is a geometry assertion; an edge
  tap on hardware is the other half.

### 2026-09-20 (detail-sheet graphics, and slice 7's chrome trim)

- Decided: river flow draws as a range strip with a marker, never a bar.
  `flowRating` is non-monotonic on purpose -- bony and blown out are both
  unfishable -- so a filled bar would encode more-is-better, which is the wrong
  claim. `trackPosition` interpolates through the five percentile stops rather
  than along the cfs axis, because flow distributions are skewed: on a
  plausible day the median is 400 of a 1600 range, so a linear axis would put
  it a quarter along instead of halfway.
- Decided: the season ribbon rotates to start at the current month rather than
  anchoring on January. A November-to-February season splits into two
  disconnected blobs at opposite ends of a fixed strip, which is the most
  misleading case it could have. Every card rotates identically, so species
  stay comparable on one sheet. Both the contiguous run and the January-anchored
  split are asserted, so the reason is a test rather than a comment.
- Decided: a typical-size bar was considered for the species card and rejected.
  The silhouette already scales with weight, several weights are flagged
  unverified in `SpeciesSize`, and halibut beside rainbow trout has no honest
  shared axis.
- Observed: the ribbon's risk mark shipped white on first draft, which is the
  same 1.51:1 defect slice 4 fixed on the map. Caught by looking at the rendered
  sheet, not by any test. Fixed by reusing `SiteMarkerView.glyphTint(on:)` so
  the ribbon and the map cannot drift apart, with a test pinning both to one
  rule. Second time today that looking found something every green check missed.
- Observed: the shipped App Store river frame was a screenshot of an error
  message. `-uiTesting` loads the bundled fixture and never calls USGS, so the
  sheet could only render "couldn't reach USGS". `fixtureFlow` gives it the
  gauge's own p75 -- deliberately off centre, where a marker pinned at the
  median would hide an axis that was not being applied at all.
- Decided (slice 7): the header is one row. The light-hint sentence moved to the
  info popover, the duplicated sun/moon glyph is gone, and date and time sit
  behind one button that opens a graphical picker. The compact `DatePicker`'s
  pills ignore `controlSize` and were what forced the bar onto two lines.
- Decided (slice 7): a cluster is named for its lead member only. MapKit's
  default "<first member> +N more" draws under a badge already reading N, and
  those labels were most of the regional frame's clutter. The count survives on
  the badge and in the accessibility value.
- Still blocked on a human, unchanged: the ASC resubmit and the on-device
  VoiceOver pass.
### 2026-09-17 (Rivers watchdog kill)

- Found: tapping Rivers could kill the app. Not an exception — a FRONTBOARD
  `0x8BADF00D` **scene-update watchdog** termination, "exhausted real (wall
  clock) time allowance of 10.00 seconds", 28.1s of CPU. Three such reports sit
  on the device; **two of the three** (`WAFishMap-2026-09-16-152618`,
  `WAFishMap-2026-09-17-142141`) carry the identical triggered-thread stack:
  `syncRivers` -> `MKMapView.addOverlays` -> `MKOverlayContainerView
  _considerAddingDrawable:inAddRect:` -> `NSConcreteMapTable objectForKey:`.
  The third, 35s after the first, is in SwiftUI environment machinery — a
  follow-on while still thrashing.
- Decided: the overlay **count** is the cost, not the geometry. `rivers.json`
  holds 1,319 rivers made of **18,287 reaches**, and `syncRivers` added one
  `MKPolyline` per reach in a single `addOverlays` call on the main thread.
  Reaches that share a colour and a width now go in together as
  `MKMultiPolyline`, so the same 49,693 coordinates reach the map as roughly a
  dozen overlays — bounded by the number of distinct styles, which no amount of
  hydrography can grow. `39c757e`.
- Verified, matched pair on one iPhone 16 Pro, same probe, same conditions: a
  poll loop whose floor is 30s took **48.1s and 48.8s** before the change and
  **30.9s** after. Main-thread blocking on the toggle goes from ~18s to ~0.9s,
  against a 10s watchdog allowance. `riverSheetOpened=true` on both, so rivers
  still draw and are still selectable.
- Honest limit: **the kill itself was never reproduced on demand.** Tapping
  Rivers on the pre-fix build survived every attempt, at the regional span the
  camera eases to and pulled back to the whole state. So this is the *mechanism*
  measured before and after, plus two crash stacks naming it — not a reproduced
  crash made to disappear. The precondition that turns ~18s of blocking into one
  contiguous >10s scene update is still unknown.
- Found: `riverTap` finds the nearest river from the model, never from overlay
  hit-testing, so per-reach overlay identity was never load-bearing. The two
  coordinator tests that told rivers apart by `MKShape.title` now tell them
  apart by style.
- Done: merged as #46 (`5bdbc6d`), archived Release and uploaded to ASC
  (`** EXPORT SUCCEEDED **`, `UPLOAD SUCCEEDED with no errors`). The archived
  binary carries `RiverMultiPolyline`, checked with `strings` on the product
  rather than inferred from the repo. ASC refused CFBundleVersion 6 as already
  used, so Xcode retried with the next free number; **that number was not
  observed** — no issuer id on this machine for the ASC API, and the delivery
  log never prints it. Confirm it in ASC rather than assuming 7.
  Re-checked 2026-09-17: the number is not recoverable locally by any route.
  Every archive's Info.plist reads CFBundleVersion 1 (Organizer rewrites it at
  export, not in the archive), no exported ipa was kept, `DistributionLogs/` does
  not exist and the only altool logs are from 09-02. An ASC API key is on disk
  (`~/.appstoreconnect/private_keys/AuthKey_9528366F2G.p8`) but the issuer id is
  not, and appstoreconnect.apple.com has no signed-in session in Chrome. It takes
  Daniel's sign-in.
- Note: this is **not** iPad work. `FishingMapRepresentable.swift` is
  byte-identical on `main`, so 1.0 (6), in App Store review at the time, has the
  defect. Decided to fix on `main` and upload a replacement build.
- Note: `-only-testing:` naming a **Swift Testing** function ran **zero** tests
  and still printed `** TEST SUCCEEDED **`. It was nearly accepted as proof that
  a mutation had not broken anything; only the whole-suite run caught it. Filter
  to the target, then read the `Test run with N tests` line.

### 2026-09-16 (1.0 (6) submitted for App Store review)

- Decided: ship iPhone-only (#43, `TARGETED_DEVICE_FAMILY = 1` on the app
  target). ASC blocked Add for Review on missing 13-inch iPad screenshots, and
  the iPad layout was never verified. Test targets stay 1,2.
- Decided: build 6 archived from the #43 branch with release Xcode; the archived
  app reads `UIDeviceFamily [1]` and empty `NSPrivacyCollectedDataTypes`. ASC
  refused 5 (-19232) and accepted 6.
- Submitted 1.0 (6) at 3:18 PM, observed as Waiting for Review, manual release.
  ASC App Privacy published as Data Not Collected (observed after reload).
- ASC listing changed: support URL -> `support.html` (live, carries the contact
  email Guideline 1.5 needs); keyword "WDFW" replaced by "trout,lakes"; review
  notes rewritten (the old ones pointed reviewers at `-uiTesting`, which they
  cannot set). `docs/app-store/listing-draft.md` now matches ASC.

### 2026-09-16 (build 4 uploaded; Apple API review items landed)

- Decided: build 4 archived from main 66c16ba with release Xcode and uploaded;
  ASC refused 3 (-19232) and accepted cfBundleVersion 4 (ContentDelivery.log).
  Carries data batch 2 (#32), recenter on live location (#33), Grant walleye
  reservoirs (#34), unified Maps directions URL on 18.4+ (#35), glass area
  labels (#36), Baker Lake removal (#37), lake species filter (#38, #39).
- Decided: the MapCoordinatorTests "hang" was another session's UI-test launch
  killing the unit-test host on a shared simulator (reproduced, rc=65 after
  607s). No code change; the one-session-per-simulator rule is in the ios-build
  runbook.
- Unverified: #35's route rendering (Maps stopped at its first-run ads sheet);
  #33's live-location path has unit tests but no UI coverage.
- Open, from the Apple API review: the privacy label declares Precise Location
  collected while the prompt says location stays on device (your call, ASC and
  PrivacyInfo change together).

### 2026-09-16 (inland launches rated only on species their WDFW lake lists)

- Decided: a launch matched by `Lake.match` to a lake with a WDFW species list
  keeps only statewide/county species that list supports
  (`FreshwaterGuide.fishery(county:waterbody:lakeSpecies:)`, explicit
  `wdfwLakeSpecies` map; unmapped species such as Rock Bass are kept, waterbody
  rows are never filtered). Pin and sheet both read `fishery(for:)`.
- Observed, September, live WDFW launches (477; 452 inland; 199 lake-matched with
  species): ratings went from 199 Good to 179 Good, 12 Prime, 6 Fair, 2 no data.
  Species lists changed at 172 of 199. Colour stays mostly Good because Rainbow
  Trout and Largemouth Bass both carry September as a good month.
- Decided: cutthroat stays dropped at eastern lakes. WDFW's only cutthroat layer
  is "Coastal Cutthroat", listed at 0 of 325 lakes east of -120.5; keeping it
  would put 49 Prime on mostly bass/walleye water with no data behind it, the
  over-claim this filter exists to remove. Piers are not lake-matched and unchanged.

### 2026-09-16 (Baker Lake sockeye row removed: no launch reaches it)

- Decided: drop `byWaterbody["Baker Lake"]` and its `waterbodySites` entry. The
  WDFW launch layer (MapServer/0, 477 of 477 rows) has no "Baker Lake", "Baker
  Lake Resort", "Horseshoe Cove" or "Kulshan Campground" (only "Baker River",
  below the dams), and the pier layer (63 rows) has no Baker name; Moses Lake and
  Billy Clapp Lake in the same query do match. The season-risk stamp test now
  decodes an inline guide and was watched failing with the byWaterbody stamp removed.

### 2026-09-16 (data pass, second batch)

- Decided: applied the settled UNSUPPORTED calls and the sourced additions from
  `docs/research/2026-09-16-datapass-{unsupported-verdicts,additions}.md`.
  Removed the statewide kokanee row (65/653 lakes) and the Grant and Okanogan
  smallmouth rows; Area 13 squid best Dec-Jan, Area 9 squid good from
  September; reworded the Area 2-2 fall Chinook note (its source is a
  secondary report, so it defers to WDFW). Added Area 7 spot shrimp, summer
  hatchery Chinook in Areas 10 and 11, halibut in Areas 9 and 1, Area 6 summer
  squid and Area 1 black rockfish.
- Corrected four agent-proposed rows against their own sources before applying
  (Area 10 Chinook had no June/September, Area 7 shrimp no July, Area 9 halibut
  June is open, Area 1 rockfish months had no source). Two halibut notes were
  reworded because `noSpeciesNoteStatesADate` rejects "Aug-Sep".
- Not added: Area 12 summer Chinook (south of Ayock Point only; the map cannot
  split Area 12), Area 7 summer Chinook (no dated source), statewide perch and
  crappie (fail the statewide rule), Area 2 surfperch (no month source), spot
  shrimp in 8-1 to 13 (closed 2025 and 2026). Grant walleye stays but rates at
  trout-only lakes; per-reservoir rows filed as a task.

### 2026-09-16 (final data pass against WDFW)

- Decided: a month a fishery is closed, or release-only for that species, is
  not a good or best month, even though the rating is editorial timing. Rows
  whose fishery does not exist were removed: Area 13 chum (release-only), Area
  13 crab and crab snaring (closed until further notice), Area 12 lingcod
  (closed year-round), Area 7 blackmouth (closed Oct 1-May 14). A salmon month
  was only changed where the 2025-26 agreed fisheries and the 2026-27 proposals
  agree, so it is not a one-year quirk.
- Applied every WRONG item from the three reports in `docs/research/`
  (2026-09-16-datapass-{puget,coast,freshwater}.md, each with source URLs and
  quotes), plus the UNSUPPORTED items with a clear fix: Areas 10/11 blackmouth
  best April, Area 7 halibut good Aug/Sep, the Area 5 "odd days" and Area 13
  "winter/spring only" clauses, softer rock bass and Mason perch notes, Yakima
  channel catfish removed, and seasonRisk rows for ocean coho, black rockfish
  and halibut September.
- Freshwater county rows that described one waterbody were removed rather than
  reworded (Stevens/Ferry kokanee, walleye and net-pen rainbow; Douglas
  triploids and walleye; Spokane redband; King coho; Chelan Chinook; Yakima
  smallmouth; Kittitas wild rainbow and cutthroat), so those launches fall back
  to the statewide rows. Same rule as the Spokane River refusal.
- Not done: the OMISSION lists (new species such as spot shrimp, summer
  hatchery Chinook, statewide perch and crappie) need their own sourcing; and
  UNSUPPORTED items left for judgement (statewide kokanee, Grant/Okanogan
  smallmouth, Grant walleye, Area 2-2 fall Chinook note, squid timing in 9/12/13).
- Verified: every edit asserted the old value before writing (67 plus notes);
  unit suite 264 tests passed, rc=0, with the built bundle's fisheries.json
  byte-identical to the edited file.

### 2026-09-16 (launch indexing profiled on device)

- Decided: launch indexing needs no further work. No A7 device can run an iOS 18
  app (the floor is A12), so it was profiled on the paired iPhone 16 Pro (A18
  Pro, iOS 27.0) instead: Release build, `xctrace` Time Profiler over a 25 s
  launch, symbolicated with the build's dSYM, inlined frames resolved per
  address with `atos -i`. Main-thread CPU: `indexWaterbodies` 31 ms (28 ms of
  it `Lake.match`), `indexSitesToAreas` 8 ms, `indexPiersToAreas` 1 ms, about
  40 ms in all. (The simulator timings above are not a baseline for this:
  `indexSitesToAreas` was timed there before its fix and not after.) Bigger launch costs are decoding:
  GeoJSON collections 82 ms, protected areas 56 ms, USGS flows 54 ms, rivers
  43 ms. Control: `loadRiverStats`, which xctrace named itself, read 33 ms both
  ways. Not measured: an A12 phone, the oldest that can run the app,
  which will be slower by an unknown factor.

### 2026-09-16 (Silver Lake is not North Silver Lake)

- Decided: direction words (upper/lower/north/south/east/west) are still
  ignored when looking for a shared lake name, but must agree between launch
  and lake. The Spokane County "Silver Lake" launch sits 67 m from Silver
  Lake's NHD shore and 144 m from North Silver Lake's (a separate 71-acre
  lake, whose WDFW point is inside that polygon), yet matched North Silver
  because Silver Lake's own point is outside reach. Against all live launches
  the rule changes 3 of 206 matches, each to no lake facts: Silver Lake,
  Caliche Lakes (was Upper Caliche) and Elton Pond (was Elton Pond North).
  None is shown rather than a guess.

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
