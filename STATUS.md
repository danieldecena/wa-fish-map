# WAFishMap — Status

## Confirmed working

- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; only
  the "Oregon" polygon is unseeded) plus 11 freshwater counties. WDFW-checked
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

- **Phase 1 of the App Store plan:** the waterbody river tier and the USGS flow-stat
  check are done; next is the Oregon polygon.

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

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
