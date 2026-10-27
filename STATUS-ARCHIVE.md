# WAFishMap — Decision log archive

Rotated out of `STATUS.md` to keep the live file readable. Append-only;
git holds the full history either way. Newest first.

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

### 2026-09-16 (privacy manifest declares nothing, on purpose)

- Decided: `WAFishMap/PrivacyInfo.xcprivacy` is all-empty: no tracking, no
  collected data, no required-reason APIs. Grep found no UserDefaults, file
  timestamp, boot-time or disk-space calls, and no third-party packages. The
  user's location never leaves the device: WeatherKit is queried with the
  launch site's coordinate, and WDFW/NOAA/USGS/NDBC requests carry only fixed
  queries or station ids. Adding any of those APIs, an SDK, or a request that
  sends the user's position means updating the manifest and the App Privacy
  answers together. Verified the file ships in the built .app.

### 2026-09-16 (privacy manifest matches ASC Location answers)

- Supersedes the empty collected-types decision above for nutrition-label
  consistency. ASC App Privacy declares Precise Location, App Functionality,
  not linked, not tracking. `PrivacyInfo.xcprivacy` now declares the same
  `NSPrivacyCollectedDataTypePreciseLocation` entry. Required-reason API
  array stays empty (still no UserDefaults / file-timestamp / boot-time /
  disk-space). WeatherKit and map providers receive coordinates needed for
  the request (plan site or area/station), not a retained user profile — same
  story as `docs/app-store/privacy-policy.md` and the live GitHub Pages URL.
  Tracking remains false; no tracking domains.

### 2026-09-16 (Location is not collected; reverts adda11f)

- Decided: the manifest and ASC answer declare no collected data. Apple counts
  data as collected only when it leaves the device. The user's fix drives the
  camera only (`FishingMapView` recentre); `PlanWeatherView` and
  `DirectionsButton` send the launch's `site.coordinate`, and WDFW/NOAA queries
  are statewide or by station. Adding a request that carries the user's fix
  means re-declaring Precise Location in both places.

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

### 2026-08-31 (species-first)
- Decided: recolor, do not hide. Exact name match. Reuse the date picker.

### 2026-08-31 (marker clustering)
- Decided: keep the heat toggle. Clusters replace overlapping pins, not the wash.
- Decided: same lon/lat grid as heat, tap zooms into the cell, color is the
  best rating in the cell. No MKMapView rewrite.

### 2026-08-31 (tide predictions)
- Decided: day's high/low table, not live stage. The map already has a plan date;
  live height fights a future Saturday.
- Decided: nearest bundled NOAA station (170 WA + Columbia-mouth), not a runtime
  catalog (`state=WA` is ignored and returns 3,500 US stations) and not one
  station per marine area (wrong at the edges).
- Decided: marine only, fail open, same "not a tide book" posture as WDFW.

### 2026-08-31 (season/closure + map design)
- Decided: cap, do not hide. A closure-prone species keeps its card and its
  place in "Biting now" but cannot reach Prime. Hiding it would cost the user
  the information that sends them to WDFW.
- Decided: cap only in flagged months, not blanket per species, so a fishery
  reliably open at its peak still reaches Prime.
- Decided: curate centrally by species name, not `verifyMonths` on all 134 rows.
  Substring matching knowingly over-flags (Lingcod, Crab, Coho, Sockeye,
  Chinook); over-flagging is the safe direction for a "verify" signal, and
  `"seasonRisk": "none"` is the per-row escape hatch.
- Decided: the rating ramp is thermal (blue → amber → orange → red) as four
  explicit stops. Sampling a blue-to-red line ran the midtones through magenta,
  which reads as a different scale and put Good and Prime adjacent in the
  reddest stretch.
- Decided: the heat overlay draws real grid cells, not circles. Circles 10-28km
  across in an 11.3km cell had to overlap, and translucent overlap composites
  rather than maxes, so two mediocre neighbours out-darkened one hot cell — the
  layer encoded how many cells held data. Diagnosis came from a peer session and
  its arithmetic was verified against the source here.
- Decided: rank each cell against the others instead of normalising to the
  densest. One outlier crushed every ordinary cell to the floor.
- Decided: mute the basemap while heat is on. A translucent fill takes its
  colour from what is under it, so one band read pink over city, brown over
  forest, violet over water. Hue-shifting the bands compensated and looked
  garish; draining the ground fixed the cause.
- Decided: the Stop-hook auto-commit is off. It swept unreviewed work into
  commits and pushed them three times in one session, each under a generic
  fallback message. `~/bin/auto-commit.sh` stays on disk; `auto-push.sh` still
  runs.

Older entries: [STATUS-ARCHIVE.md](STATUS-ARCHIVE.md).

### 2026-08-30 (data-update review)
- Reviewed how data updates: geo layers self-update per launch (live fetch,
  bundle fallback); fisheries.json is release-only by design. Fixed the gaps:
  - Rewrote scripts/verify_wdfw_live.py for the statewide contract (17 live
    AreaNames, fisheries.json schema/months/areaName membership, layer counts
    vs maxRecordCount, fixture anchors). Verified both ways: passes on real
    data, fires on a mutated copy (bogus area + month 13), mutation asserted.
  - Added .github/workflows/ci.yml: ubuntu contract job (push/PR + weekly cron
    for WDFW drift) + macOS xcodebuild test job.
  - App now rejects truncated ArcGIS responses (exceededTransferLimit at either
    level -> WDFWLayerError.truncatedResponse) instead of rendering a partial
    layer as complete; layer 0 is 477/2000 today so headroom is large.
  - load() no longer strands "Loading…" when live fetch and bundle both fail;
    restores the intent of old-main b5a15bc whose content was dropped in the
    history unification. Both behaviors unit-tested (19/19 green).
- Left unpaginated fetch as-is: verifier warns at 80% of maxRecordCount, which
  is the cheap early signal; pagination only if that ever fires.

### 2026-08-30
- Verified `fisheries.json` seasonal facts against WDFW via parallel research.
  Material corrections applied:
  - Blackmouth (resident Chinook): MA 10/11 were "best Nov-Feb" but those areas
    are generally closed then; real fishery is a spring (Mar-Apr) selective
    opener. MA 13 shifted to spring-leaning (best Jan-Apr, good Nov-Dec).
  - Lingcod: inner Puget Sound (MA 5-11) closes ~Jun 15, so July is closed —
    dropped month 7 from goodMonths on all marine lingcod entries.
  - MA 9 summer Chinook: June typically closed — dropped from goodMonths.
  - Grant Co walleye (Potholes): fishes best post-spawn (Jun-Aug), not May-Jun.
- Deferred minors (squid Oct, MA 13 cutthroat Dec) were already present in the
  data — no change needed.

### 2026-08-30 (statewide seed)
- Extended `fisheries.json` statewide: added marine areas 1, 2, 2-1, 2-2, 3, 4,
  5, 6, 7, 8-1, 8-2 (11 new) and freshwater counties King, Snohomish, Spokane,
  Stevens, Ferry, Douglas, Yakima, Kittitas, Whatcom (9 new). Data WDFW-checked
  via direct web research (subagents hit the account session limit, so research
  ran in the main loop).
- Signature fisheries per region: coastal ocean salmon (Jun-Sep) + Mar-Oct
  bottomfish + albacore + razor clams; strait summer Chinook/coho + halibut +
  spring blackmouth; north Sound coho/pinks/blackmouth; Lake Roosevelt
  kokanee/walleye, Rufus Woods triploids, Baker sockeye, Yakima smallmouth, etc.
- Left Pierce/Mason/Kitsap/Thurston on the statewide default (not distinct
  enough to seed). Only the "Oregon" area polygon stays unseeded.
- Verified all 16 areaName values match the live WDFW layer-6 set; JSON valid;
  all months 1-12; tests green.

### 2026-09-01 (UI test target, zoom clamp, piers, waterbody tier)

- The verify badge is now **observed**, not inferred. `WAFishMapUITests` launches
  the app with `-uiTesting -planMonth 7`, which loads the bundled fixture and
  preselects Boston Harbor, and asserts the badge is on screen. That retires the
  Known-broken entry it had carried since it shipped. Injected taps are not
  involved: the seam preselects the site, which is why this finally worked after
  a session of unreliable tap injection.
- The UI assertions do not hardcode how many species a month flags. The first
  draft did, reimplementing `inSeason(month:)` in the test, and was wrong in both
  directions — 3 badges where it expected 2, 2 where it expected 1. A test that
  restates the rule it checks cannot catch that rule being wrong. It now asserts
  the badge is present and that badges are fewer than species listed: selective,
  not unconditional.
- `.accessibilityIdentifier` on a card *container* collapses it into one
  accessibility element and hides the badge inside. Marking the species name
  instead keeps both queryable. Cost one red run to find.
- Decided: pins stop being drawn past 400km (`MapDetailLevel`) and the density
  overlay is forced on there, because MapKit's clustering declutters collisions
  but has no notion of a badge being unreadable. The legend follows what is
  drawn, not the toggle — a rating legend over a heat map lies.
- Piers are indexed against MPAs where piers load, not in the MPA block: piers
  arrive after that layer, so an index built there would run against an empty
  list and every assertion would pass for the wrong reason.
- NDBC readings are per-field, not per-observation: station 46088's newest row
  carries a wave height and `MM` for water temperature, with the real
  temperature one row older. Each reading keeps its own timestamp. `MM` is
  absence — read as zero it would report flat calm water at freezing.
- Corrected twice on WeatherKit, both times by checking instead of reasoning.
  "Blocked on a paid account" was wrong (the membership is paid); "the
  capability must be enabled by hand in the portal" was also wrong
  (`-allowProvisioningUpdates` enabled it and minted the profile). The live
  fetch still fails on the simulator for an unrelated reason — ad-hoc signing,
  no profile, no JWT — so the feature ships verified at build and unverified at
  runtime, and says so.
- The graphify post-commit hook is installed in all 11 repos that have a graph,
  and new repos get a guarded template hook via `init.templateDir`. Deliberately
  not a global `core.hooksPath`: that overrides every repo's own `.git/hooks`
  and would silently disable the gitleaks and claude-dir-guard hooks in `~/`.
- The freshwater tier gained `byWaterbody` keyed by a curated facility list.
  Substring-matching facility names against waterbody names was rejected — it is
  the same prose-matching guess `NoteScopeTests` exists to prevent.

### 2026-09-01 (camera gestures, protected-area default)

- Decided: `SiteDetailSheet.protectedAreaCheck` defaults to `.unavailable`, not
  `.clear`. `.clear` renders "not in a protected area" for a check that never
  ran, which is a safety claim asserted from the absence of a result. An
  unavailable check must read as unknown.
- `userGesture` guarded on `.began`/`.changed`, states a discrete recognizer
  never enters, so the double-tap and two-finger-tap recognizers were attached
  but could not fire and tap zooms did not count as a user camera move. The
  guard is now `Coordinator.isCameraMove(_:)`, covered by
  `WAFishMapTests/CameraGestureTests.swift`.
- Corrected: that commit extracted the guard and wrote the test but never
  changed the predicate, which still accepted only `.began`/`.changed`. The
  refactor shipped and the fix did not, so tap zooms still went uncounted. The
  commit said in its own message that the suite was unfinished when it landed;
  the run that followed failed on `discreteTapStatesCountAsACameraMove()` and
  the failure sat unread until a stale background task reported it. `.ended` is
  now accepted (`.recognized` is `.ended`), 108 tests in 18 suites pass. A test
  written alongside a fix does not prove the fix is in the commit.
- `appliedSelectionID = nil` moved above the visibility guard in the deselect
  handler. MapKit drops the selection whether or not the pin is on screen, so
  leaving the applied id set meant `syncSelection`'s guard held forever and a
  pin panned back into view never re-highlighted.

### 2026-09-01 (MKMapView migration)

- Decided: migrate the SwiftUI `Map` to a `UIViewRepresentable`-hosted
  `MKMapView`. SwiftUI's Map exposes neither annotation clustering nor tile
  overlays; the hand-rolled grid clustering produced an unreadable badge
  pile-up statewide. Native `clusteringIdentifier` replaced it and the
  scaffolding was deleted (202 lines).
- Decided: no third-party basemap or chart tiles. Esri's ocean basemap is a
  full basemap, not an overlay, so drawing it means hiding Apple's and losing
  the road and ramp labels that get a user to the water. OpenSeaMap composites
  but adds little. Sticking with Apple; depth remains Navionics' job per the
  WA fishing split already in CLAUDE.md. The tile-overlay half of the
  migration's rationale is retired; clustering was the real motivation.
- Found: `anchor.fill` is not an SF Symbol, so every boat-launch pin has drawn
  as a default marker since the first commit (537a292) on both the SwiftUI and
  MapKit paths. Observed by calling `UIImage(systemName:)` on the simulator,
  not by reading docs. `SiteMarkerGlyphTests` now resolves every `Kind` case
  against the real symbol table.
- Found: WDFW layer 4 carries six `TypeOfMPA` values, not the three the plan
  sampled. "Fishing may be prohibited or limited here" is false for
  `Voluntary` (WDFW asks, prohibits nothing) and `Health Closure` (biotoxin,
  different authority), affecting 4 of 44 areas. Wording is now type-dependent
  with a neutral fallback that asserts no rule.


### 2026-09-01 (layered icon, hand-authored)
- The `.icon` bundle is generated by `scripts/make_icon.swift`, not by Icon
  Composer's GUI. Two things I reported earlier were wrong and are corrected
  here: Xcode *does* ship an `icon.json` template (per platform, e.g.
  `iPhoneOS.platform/.../Icon Composer Icon.xctemplate/`) - I had only searched
  inside Icon Composer.app - and there *is* a CLI. Neither the GUI handoff nor
  the schema guesswork was necessary.
- `ictool` renders a bundle to PNG in any appearance and is how to check one
  without a device. It is NOT the same-named shim in `Developer/usr/bin`, which
  rejects the arguments:
  `"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" WAFishMap/WAFishMap.icon --export-image --output-file /tmp/i.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`
  Renditions: Default, Dark, TintedLight, TintedDark, ClearLight, ClearDark.
- It landed as **two** vector layers (tail, body) plus a document gradient
  `fill`, not the three SVG layers the task title assumed. The background has to
  be the document fill because only a document fill is substituted for the Dark,
  Tinted and Clear appearances; drawn as a foreground group it rendered the mark
  nearly invisible, which the first ictool render showed outright.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole) rather
  than a dark layer, so it survives the recoloured appearances. Confirmed on all
  six renditions.
- `AppIcon.appiconset` retired: the `.icon` emits the legacy sizes too
  (`WAFishMap60x60@2x.png` etc.), and Info.plist now carries
  `CFBundleIconName = WAFishMap`. The flat raster moved to `icon/icon_1024.png`,
  outside the app target. `.ios-build/` added to `.gitignore` (2,419 untracked
  files that were never ignored).
- Observed: `Assets.car` in the device build carries the `IconImageStack`,
  both `IconGroup` rows and the Any/Dark/Tintable renditions; the app is
  installed on Daniel's iPhone (iOS 27.0), confirmed by
  `devicectl device info apps`, not by the install log. Still NOT observed: the
  icon on a home screen. Simulator springboard navigation needs injected
  gestures, which remain unreliable here, and DeviceHub exposes no accessibility
  window to drive "View Screen" from a script.

### 2026-09-01 (layered icon layers)
- `scripts/make_icon.swift` now also emits `icon/background.svg`,
  `icon/tail.svg` and `icon/body.svg` from the same constants and the same
  CGPaths as the flat PNG, so the layered icon and `icon_1024.png` cannot
  describe different shapes. The PNG is byte-identical across the change.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole), not
  its own dark layer: the system recolours foreground layers for the tinted and
  clear appearances, where a dark dot would vanish but a hole still reads.
  Layers are background / tail / body so the system gives the tail its own
  depth instead of the flat icon faking it.
- The script reads the SVGs back, rasterises them through NSImage and asserts
  against the bitmap. First attempt was a check that could not fail: it sampled
  through `svgPlace`, the same transform that drew the file, so removing the
  y-flip moved drawing and sample together and passed. Rewritten to measure the
  drawn bboxes and the *enclosed* transparency, compared against `expectedX`/
  `expectedY` derived from `markBounds`/`scale` rather than the transform.
  Known-bad runs now fail as they should: no flip (eye centre y 520 vs 504),
  no eye subpath ("the eye is filled, not punched through"), swapped gradient
  stops.
- `icon.json` is NOT hand-authored. Its schema is Apple's, undocumented, absent
  from disk, and `icrtool` has no CLI; a guessed document can compile and still
  render wrong. The `.icon` bundle comes from Icon Composer.
- Open: `WAFishMap.icon` not yet assembled, so nothing is wired into the build
  and the app still ships the flat icon.

### 2026-09-01 (app icon)
- The icon had no vector source - only a hand-made PNG from 4edb1e1 - so the
  three known defects (tail meeting the body at a point, mark off-centre, eye
  half outside the head) were unfixable without redrawing it. Added
  `scripts/make_icon.swift`, which draws the mark with CoreGraphics and
  regenerates icon_1024.png. Swift over an SVG pipeline because this Mac has no
  rasterizer (rsvg/inkscape/magick/cairosvg all absent) while the Xcode
  toolchain is already required.
- Composition is derived, not nudged: one transform centres the union bbox of
  body+tail on the canvas at 62% width. The tail's apex sits 145pt *inside* the
  body, so the two white fills merge instead of touching.
- The script checks its own bitmap before writing and exits non-zero on
  failure: a ring outside the eye must be all body, a flood fill from the tail
  must reach the nose, and the mark's bbox must be centred at the intended
  width. Each check was exercised against a known-bad input (eye pushed out,
  overlap negative, transform offset, width 80%) and observed to fail, and
  against the good geometry and observed to pass.
- Still open: the layered OS27 icon (3 SVG layers, Icon Composer) is a separate
  item and needs vector layers this script does not emit.

### 2026-09-01 (waterbody-scoped notes)
- Executed the waterbody-scoped-notes plan: NoteScopeTests gate committed
  failing (b630fa7), data fixed (d26c4ca), rule recorded in CLAUDE.md
  (82ac5e7). The gate caught 16 offenders, not the 2 the plan expected - the
  whole 2026-08-30 county seed named its waterbodies.
- Reworded 14 county notes to county-true prose; removed 4 entries instead:
  Chelan/Snohomish/Whatcom Kokanee (duplicated the statewide default once the
  lake name was gone; the county merge inherits it) and Whatcom Sockeye (only
  true of Baker Lake - out of the file until a waterbody tier exists; the
  seasonRisk "Sockeye" row stays for its return).
- Widened the gate regex with "Woods" (Rufus Woods slipped it); "Potholes"
  cannot be prose-matched, fixed as data, noted in CLAUDE.md.
- Grant walleye rewording tripped the date-guard by reintroducing
  "(spawn is Apr-May)" from an older text - the guard works; date dropped.

### 2026-09-02 (TestFlight: external chosen first)

- Decided: put the brother in the `insideout` **external** group rather than
  invite him as an App Store Connect user with a `DEVELOPER` role. External
  costs a one-time Beta App Review; internal would have cost him an account
  seat, given him visibility into the account, and required him to accept a
  user invitation. Every later build now reaches him without another review.
- Test Information: `Sign-in required` left **unchecked**. The app has no
  accounts, so there are no reviewer credentials to supply; leaving it checked
  blocks the form and invites a rejection for credentials that do not work.
- Recorded because it retires the old Next Up item, which described the
  internal route and the `POST /v1/userInvitations` call that was never made.
- Open question deliberately not answered: TestFlight builds expire at 90 days,
  so keeping the app on his phone means re-uploading before each expiry. The
  App Store alternative stays gated on verifying `fisheries.json` against WDFW.

### 2026-09-02 (TestFlight: nobody was a tester)

- "I don't see it in the TestFlight app" was not a build problem. Build 1 was
  `VALID`, `READY_FOR_BETA_TESTING`, export compliance already answered. The app
  had zero beta groups, the account had zero beta testers, and the build was
  attached to nothing. Nothing was wrong; nothing had been asked for.
- **Being the Account Holder does not make you a TestFlight tester.** An internal
  tester is a `betaTester` record whose email matches an App Store Connect user,
  in an internal `betaGroup` the build is attached to. Creating that chain is
  three POSTs, so the previous entry's "the rest is browser-only" was wrong.
- The tester email is the Apple Account on the developer account,
  `danieldecena@icloud.com`, not the address used elsewhere for this work. A
  TestFlight signed in to the other account would show nothing however correct
  the server state is.
- `isInternalGroup` is settable on `POST /v1/betaGroups`, confirmed against the
  schema Apple publishes for `BetaGroupCreateRequest.Data.Attributes` before the
  write, not after. The script still deletes the group if Apple hands back an
  external one, because an external group routes the build to App Review.
- **A swallowed 403 reads exactly like an empty relationship.** The first pass
  asked `GET /v1/builds/{id}/betaGroups`, defaulted the error body to `[]`, and
  reported "attached to no groups" — the right conclusion by luck. Apple refuses
  that direction outright (`the relationship 'betaGroups' does not allow
  'GET_RELATED'`); the edge is only readable as `GET /v1/betaGroups/{id}/builds`.
- The confirmation is Apple's own state change, not the absence of an error:
  `internalBuildState` moved `READY_FOR_BETA_TESTING` -> `IN_BETA_TESTING` across
  the writes.
- A tester at state `INVITED` is invited, not testing. TestFlight lists nothing
  for them until the emailed invitation is accepted, so a fully correct server
  state — internal group, tester, build attached, `IN_BETA_TESTING` — still
  shows an empty TestFlight. `POST /v1/betaTesterInvitations` re-sends it, and
  the state went `INVITED` -> `INSTALLED` once it was accepted. **The tester
  state is the only field that answers "can they run it".**
- The App Store Connect key is a **team** key: its JWT carries `iss`. Signed as
  an individual key (`sub: "user"`, no `iss`) it returns a bare 401 identical to
  a revoked key, which cost a detour re-deriving credentials that were fine.

### 2026-09-02 (TestFlight: build 1 uploaded)

- Archive and upload must use the **release** Xcode. App Store Connect rejects a
  beta toolchain with `90534: Unsupported SDK or Xcode version`. Set
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for those commands
  only — switching `xcode-select` globally would drag the device script with it,
  and that one wants the beta.
- Xcode 26.6 shipped with no iOS platform; `xcodebuild -downloadPlatform iOS`
  fetched 8.5GB before it could build for iOS at all.
- `altool` reported failure while the shell pipeline reported success, because
  `tail` was the last command. The only thing that caught it was
  `GET /v1/apps/{id}/builds` returning zero. An upload receipt is not evidence a
  build arrived; the build list is. Confirmed `version=1 state=VALID` two minutes
  after the successful upload.

### 2026-09-02 (root cause: two WeatherKit capability type strings)

- **Fixed.** The App ID carried a legacy `WEATHERKIT` capability record. The
  portal minted profiles from it, so `codesign -d --entitlements` showed the
  entitlement present on the installed binary and every check we ran looked
  green, but `weatherkit.apple.com/v3/token` would not honour it. Re-registering
  the capability produced a second record, `WEATHER_KIT`, and the token issued on
  the first attempt. The device test went from failing in 68-79s to passing in
  7.7s.
- Corroboration, found only because the write failed: the App Store Connect API
  will *read* `WEATHERKIT` back but rejects it on `POST`, and its accepted enum
  does not contain it at all. That is a legacy value which can still exist on an
  identifier and can no longer be issued.
- Why this took four sessions: every individual check was green. Entitlement in
  the profile, capability visible in the portal, licence accepted, quota active,
  service reachable. The failure lived in the *disagreement* between two
  representations of the same capability, which no single check could see. What
  finally localised it was the REST control — same service, different credential
  path, returning 200 with real data while the device got 401 — which proved the
  fault was neither the app nor the service but the binding between them.
- Mistake worth keeping: the re-registration was run as DELETE-then-POST without
  first verifying the POST would be accepted. The DELETE succeeded, the POST was
  refused, and the capability sat removed until it was restored by hand in the
  portal. Read enum and write enum were not the same set. Verify the reverse
  operation before running the irreversible half.

### 2026-09-02 (the REST control: WeatherKit works, the device path does not)

- Finding: WeatherKit serves team 877MLS29T9. `GET /api/v1/availability` returned
  200 with `forecastHourly` among the datasets, and the weather endpoint returned
  25 real hours for Boston Harbor — 7 mph at 194 degrees, which is the `SSW 7 mph`
  the app's wind row would have drawn. The device path returned a bare 401 for the
  same coordinate minutes earlier.
- Decided: the control had to sit on the surface that failed. MapKit JS was
  considered and rejected — its auth is unrelated, so a green MapKit would have
  said nothing about WeatherKit. The REST API is the same host and the same
  service, differing only in credential path, which is what makes the contrast
  mean something.
- Refused to guess the Service ID. A token whose `sub` is not a registered
  Services ID is rejected with the same bare 401 as the bug, so trying candidates
  would have manufactured exactly the false confirmation the control exists to
  prevent. Same reason the pre-existing `AuthKey_5Z2966W5U2.p8` was not used: a
  `.p8` carries no record of which service it belongs to, and every Apple key is
  P-256, so the file cannot answer it.
- The signer was proved before it was aimed at Apple: signed with a throwaway
  P-256 key and the output decoded to check the documented header
  (`alg`/`kid`/`id`), the four claims, and a 64-byte raw r||s signature. A
  malformed token would also have produced a 401.

### 2026-09-02 (WeatherKit fault localised to token issuance)

- Tried and failed: the device-side entitlement cache reset. Rebooted the phone,
  deleted the app (absence confirmed via `devicectl device info apps`, not
  assumed), rebuilt and re-ran 2026-09-02. Identical result: the sheet renders
  "Wind and rain unavailable right now." and all three assertions fire. The
  documented remedy for a correct server side does not apply here.
- Noted: the run immediately after the delete proved nothing and was discarded.
  Its label dump held only map chrome — no sheet, no `Wind & rain` — because a
  fresh install re-prompts for location, so `PlanWeatherView` never rendered and
  no fetch was attempted. A failure count alone would have read as confirmation;
  the dump is what showed it was a different failure entirely.
- Finding: every layer below token issuance is green;
  `https://weatherkit.apple.com/v3/token` still returns a bare 401 for
  `com.danieldecena.WAFishMap`.

  **The capability is already enabled — do not re-do it, and do not wait on
  propagation.** The signed profile Apple issued and embedded in the device build
  carries the entitlement:

      $ security cms -D -i ~/Library/Developer/Xcode/DerivedData/WAFishMap-*/ \
          Build/Products/Debug-iphoneos/WAFishMap.app/embedded.mobileprovision \
        | plutil -extract Entitlements xml1 -o - -
      <key>com.apple.developer.weatherkit</key><true/>

  The portal cannot emit a profile containing that entitlement unless WeatherKit
  is enabled on the identifier, so that step is verified complete by artifact.
  The ~30-minute propagation window has therefore also already elapsed.

  **The licence agreement is not it either.** Checked in the portal 2026-09-02:
  Apple Developer Program License Agreement issued 2026-08-18, **accepted
  2026-09-01**. No banner, nothing pending. The Paid Apps Agreement does read
  "Pending User Info", but that gates *payouts* — it wants a bank account and a
  W-9 — and the Free Apps Agreement is Active. Do not submit banking details to
  test this; it does not gate service entitlements.

  **Every layer visible from a browser is green.** Certificates, Identifiers &
  Profiles → Services → WeatherKit shows an active plan: 500,000 calls/month,
  **0 used, 0 calls in the last 30 days**, "You don't have any calls within this
  period." A team without WeatherKit provisioned has no plan page at all. So the
  service is provisioned, the quota is untouched, the entitlement is in the
  signed profile, and the agreement is accepted.

  That localises the fault precisely: **the failure is at token issuance**, not at
  capability, quota, or agreement. Nothing has ever authenticated, which is why
  usage is zero — a 401 dies before it reaches the quota.

  Remaining hypothesis is propagation, and the dates support it: the membership
  renewed 2026-09-01 (renewal date 2027-09-01), the PLA was accepted 2026-09-01,
  and the failing device run was 2026-09-02. The account's current agreement is
  one day older than the bug. Forum thread 807586 describes this exact shape —
  entitlement present in the profile, key created, still 401s, survives clean
  builds and reinstalls.

  Next, in order:

  1. Device-side cache reset — reboot the iPhone, delete WAFishMap, rebuild to
     device, re-run `./scripts/verify_weatherkit_device.sh`. Entitlement data
     caches on the phone, and this is the documented fix when the server side is
     already correct. Five minutes.
  2. If it still returns a bare 401, this is Apple's to fix. File code-level
     support (included with the membership) with: Team ID `877MLS29T9`, bundle
     `com.danieldecena.WAFishMap`, entitlement present in the embedded profile,
     PLA accepted 2026-09-01, WeatherKit plan active with 0 calls, bare 401 from
     `https://weatherkit.apple.com/v3/token` on a signed device build. That is
     not a "did you enable it" ticket.

  Do not re-check the capability or the agreement. Both are verified, by artifact
  and by portal respectively, and re-checking them has already cost two rounds.
  A pass is also the first known-GOOD input this test has ever had.

Everything else open lives in `TASKS.md`.

### 2026-09-02 (WeatherKit narrowed to token issuance; two hypotheses killed)

- Corrected: "Authorise the App ID for WeatherKit" had sat in Next Up as work to
  do. It was already done, and a local artifact proved it — Apple's portal cannot
  emit a provisioning profile carrying `com.apple.developer.weatherkit` unless the
  capability is enabled, and that profile was already embedded in the device build
  on disk. One `security cms -D -i ... | plutil -extract Entitlements` closed the
  item and skipped a documented ~30-minute propagation wait. Rule added to
  CLAUDE.md: check what local artifact would already be different before filing an
  action item that lives in someone's browser.
- Killed: the licence-agreement hypothesis, which this file had named as the live
  branch. The Program License Agreement was accepted 2026-09-01. The Paid Apps
  Agreement reads "Pending User Info", but that gates payouts, not services, and
  chasing it would have meant submitting bank and tax details to test a guess.
- Narrowed: the WeatherKit service page shows an active 500,000-call plan with
  0 calls in 30 days. Service provisioned, quota untouched, entitlement in the
  signed profile, agreement accepted — so the fault is specifically at token
  issuance. Nothing has ever authenticated.
- Live hypothesis is now propagation since the 2026-09-01 renewal, the failing run
  being one day later. Next step is a device-side entitlement cache reset; after
  that it is a code-level support ticket, not local debugging.
- Method note: three rounds of this were spent re-checking things that were
  already verifiable. The evidence was on disk and in the portal the whole time.

### 2026-09-02 (WeatherKit answered: Apple returns 401)

- Finding: WeatherKit fails on hardware for the same reason it fails on the
  simulator, and neither reason is the one assumed. The simulator's ad-hoc
  signing was a real obstacle, but removing it changed nothing: the token
  endpoint returns 401 with an empty body on a correctly-entitled, correctly-
  signed device build. The question "does the live path work on a phone" is now
  answered — no — and the remaining work is an account-level authorisation, not
  code. Nine sessions of this being filed as "needs a device" ended in one run.
- Decided: keep the swallowed-error Logger permanently. It is what turned a mute
  "unavailable" into a 401 with a URL in under a minute, on a device where no
  debugger was attached. Reading the daemon's own subsystem out of the same
  archive gave the status code the app never sees.
- Corrected: the 2026-09-02 simulator control run proved less than first claimed.
  Two of its three assertions used `staticTexts.containing(predicate)`, which
  filters by *descendant*; a StaticText is a leaf, so those two could never have
  matched anything and would have "failed correctly" against any input at all.
  Sourced from the SDK, not from memory — `XCUIAutomation.framework/Headers/
  XCUIElementQuery.h`: `containingPredicate:` is "elements that contain a
  descendant matching the specification", `matchingPredicate:` "applies the
  specified attributes or predicate to the receiver".
  Only the third, an identifier lookup, was sound. Fixed to `matching(...)`, and
  the failure message now dumps every label on screen — which is the only reason
  the device run could be diagnosed from its output. The valid known-bad
  observation is now the device run itself, where all three fired and the dump
  showed "Wind and rain unavailable right now.".
- Noted: a device run that failed at 67s showed two failures and one at 79s
  showed three, because at 67s the section was still spinning. A fixed timeout
  around a live fetch makes the failure count itself unstable; the label dump,
  not the count, is what identifies the state.

### 2026-09-02 (device signing, WeatherKit diagnosability)

- Decided: scope `CODE_SIGN_ENTITLEMENTS` to the app target instead of the
  project. It sat on the two PBXProject-level configs, so all three targets
  inherited it and both test bundles claimed `com.apple.developer.weatherkit`
  under bundle ids whose App IDs have no such capability. Ad-hoc simulator
  signing hides this completely, which is why it survived every green run to
  date. `xcodebuild build-for-testing -destination 'generic/platform=iOS'`
  reproduces it with no hardware attached and was the whole diagnosis:
  `error: Entitlement com.apple.developer.weatherkit not found and could not be
  included in profile ... (in target 'WAFishMapUITests')`. A device
  `xcodebuild test` had therefore never been possible — the verification had no
  route that did not end in reading a screenshot.
- Decided: the success sentinel for the weather section is the "not an
  observation" footer, not the `planWeatherSection` identifier. That identifier
  is on the header `Text`, so it renders in every state including the spinner and
  the failure string; asserting on it would have passed while nothing had loaded.
  The footer renders only when a `PlanWeather` exists.
- Decided: log the error `PlanWeatherView.load()` was discarding. The `catch`
  bound `error` and threw it away, and the app had no logging at all, so a JWT
  refusal and a dropped network rendered the same single string and were
  indistinguishable afterwards. One `Logger` line now attributes the failure from
  the app's own subsystem rather than from WeatherDaemon's.
- Decided: `verify_weatherkit_device.sh` refuses ambiguity rather than picking a
  device. It filters `devicectl` to physical devices and exits if there are zero
  or more than one, then checks pairing and Developer Mode before building. The
  2026-09-01 attempt was lost precisely to an iPad silently standing in for the
  iPhone and then dropping out mid-build.
- Noted: `xcodebuild ... | tail -60` reports the exit status of `tail`, so the
  first device-signing run looked like a success (exit 0) while the log said
  `TEST BUILD FAILED`. Only the text was the observation. Later runs use
  `set -o pipefail`.


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
