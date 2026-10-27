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
- The App Store screenshots predate the 2026-10-14 design pass; refresh them
  at the next submission.

## Next Up

- 1.0 is public in the App Store (apps.apple.com/us/app/wa-fish-map/id6807799974,
  seen 2026-10-27 01:22). Next: refresh the App Store screenshots.
- Fishing Year: pink seasons once WDFW sets the 2027 odd-year rules (Apr 2027).
- 1.0 (9) carries the pin VoiceOver fix and is with both TestFlight groups,
  `Internal` and `insideout`, beta review approved (read from Apple 2026-10-09).

Everything else open lives in `TASKS.md`; run `~/bin/tasks-box.sh` for the
current counts rather than trusting a number written here.

## Decision log

### 2026-10-27 (VoiceOver probe off Known broken; Figma library icons)
- `PinVoiceOverProbe` passed 3 of 3 with `-test-iterations 3` on the iPhone 18 Pro simulator against live data (xcodebuild rc=0, `** TEST SUCCEEDED **`; each run read 28 of our pin labels, e.g. "Edmonds Pier, Fishing pier, rated Fair"). With the two earlier single passes that is five in a row since the snapshot rewrite, so its Known broken line is removed. The pin device checks are still not run: the iPhone was wired, paired and in developer mode but locked (`passcodeRequired: true`) at 02:49.
- Figma library: the placeholder circles became eight vector icon components (`Icon/sailboat.fill`, `figure.fishing`, `fish.fill`, `exclamationmark.circle.fill`, `xmark.octagon.fill`, `water.waves`, `flame.fill`, `flame`), 25 instances keeping each placeholder's color variable. Site Marker has a `Glyph` instance-swap property; shore and pier were swapped in on the review frame and drew. Also fixed against the code: Good pins and the Good cluster count drew white ink; the app draws dark on Good (white measures 2.31:1), so both now use `ink/on-fair`. Checked by screenshot of each component set and the review frame.
- App Store screenshots not taken: still night (the plan card reads the real clock), and the app has no clock override; adding one would put the on-screen time out of step with the live tide and weather data.

### 2026-10-27 (web map on the app's colors; version 38)
- Published the Washington Fishing Map as version 38 (1793093361-13fb) with the iOS 26 rating colors the app draws; live index.html read back equals the repo file plus the publisher's wrapper. Before publishing, live 1793089848-ed42 was compared with the repo and matched. `baseline.html` keeps the old colors on purpose: it is the first-published rollback copy.
- The page's color-blindness test failed on the new colors, and the failure was real: red vs orange under simulated deuteranopia is ΔL* 11.1 (dE76 19.5 light, 21.1 dark), under the page's lightness-only gate of 12. The app measures the same numbers on device (`CVDSeparationTests`, 2026-10-06) and passes because the pin glyph ink differs, white on red and dark on orange. The web pins already use that same ink rule (`glyphColor`), so the web test now applies the app's criterion (lightness, or dE76 30, or different ink) to every adjacent pair. Proven to fire: giving orange white ink failed both tests; restored, they pass. The old orange/yellow control no longer holds (12.7 light now), so the control is the red/orange pair instead.
- Checks: Node 198/198; `check-week.mjs --today 2026-10-27` all checks passed. Design system page republished as version 14 to drop its now-closed web map divergence.

### 2026-10-27 (design system page synced to the app's colors; version 13)
- Published the WA Fish Map design system as version 13 (1793092916-2856), from live 1793092690-fd1b, and read `tokens.json` and the pin preview back from live. The rating ramp now holds what `DS.Rating` resolves to on iOS 26 (prime #ff383c / #ff4245, good #ff8d28 / #ff9230, fair #ffcc00 / #ffd600, slow #0088ff / #0091ff). Those values were not taken from memory: they reproduce all six adjacent-stop ΔL* figures `RampLightnessTests` recorded on device (27.29 / 14.40 / 13.30 light, 27.27 / 15.79 / 13.25 dark); the older iOS 18 values the page's `-system` tokens held miss them by 1.5 to 3.8. Gray and the system fills are Apple's published values, not measured.
- Also stale and fixed on the page: badge labels are primary ink, not the rating color; "season may be closed" is a corner badge on a full-color balloon, not a pale balloon; Good and Fair pins draw a black glyph; fine print is `secondaryLabel`; Closed badge and the Rivers/Heat toggle fills added. The old "known divergences" (two ramps, yellow footer) are resolved in code and were removed.
- Found, not fixed: the published web map (`salmon-rivers/index.html`) still draws the iOS 18 palette (#ff3b30, #ff9500, #ffcc00, #007aff). Recorded on the page and in TASKS.md. Not checked by eye: the page was not screenshotted after publish.

### 2026-10-27 (Figma component library; design system page is stale on rating colors)
- Built a Figma component library from `DesignSystem.swift` (link in CLAUDE.md). Screenshot of its review frame checked: every state renders, badges show the 0.2 wash with a full-color stroke. Two Figma quirks cost a pass each: SF Pro listed by `listAvailableFontsAsync` but drew at zero width (`hasMissingFont`), so the styles use Inter; and paint opacity on a variable-bound fill was ignored, so washes are a separate layer at node opacity.
- Found: the published design system (Artifacts/design-system, synced 2026-09-20) lists the rating ramp as fixed literals (`rating-prime #f01c0d` "does not shift by appearance"), but `DS.Rating` has used `Color.red/orange/yellow/blue` since 2026-09-01, which do shift. It also predates the Rivers/Heat toggles and the Closed badge. Code is the source of truth; the page needs a sync (TASKS.md).
- Code Connect refused on both student teams: "You need a Dev or Full seat on an Organization or Enterprise plan".

### 2026-10-27 (Puget river reports re-checked: nothing new; PR 99 merged)
- Re-checked the Puget river sources at 01:45, a day after the first pass. Confluence Fly Shop's newest report is still Oct 10 (Atom feed), Pacific Fly Fishers' still Oct 7, The Guide's Forecast covers no Puget river, and Avid Angler's newest Skagit entry is still 9/10 (its only newer entry is Yakima trout, 10/20). Avid Angler refuses automated fetches (403); it was read in Daniel's own Safari. No change to `reports.js`; the Skagit entry stands, dashed. Its Oct 10 report passes 21 days on Oct 31, which matters only for adding, not for keeping.
- PR 99 merged at Daniel's instruction (merge commit `9265631`).

### 2026-10-27 (App Store screenshots: not retaken yet, and why)
- A /goal run built 1.0 on the iPhone 18 Pro simulator and captured the live set's six frames (Tacoma, Boston Harbor sheet, Seattle, San Juans, Spokane, Hood Canal, a location fix per region, 1206x2622). None were kept. The plan card's date chip reads the device's real clock, so at 01:36 every map frame said "Oct 27, 1:36 AM" with a Night badge; and the `-uiTesting` sheet loads the offline fixture, which has no protected-area layer, so the Boston Harbor sheet showed "Protected-area check unavailable". Retake in daylight, and get the sheet frame from the live app (tap a pin) rather than the seam. Resize with `sips -z 2778 1284` for the 6.5" slot.
- `scripts/run_sim.sh` stopped at its open-the-window step (Xcode 27 has no Simulator.app; `set -e` ended the run before the build). It now warns and carries on headless; the rebuilt app was confirmed on the device by its 01:35 binary.

### 2026-10-27 (old marketing page links fixed; version 10)
- `Artifacts/app-store-listing` republished as 1793090014-02d2 in a /goal run: Privacy and Support now go to the github.io pages App Store Connect uses (both answered 200), "Try It Here" is a plain link to the interactive preview artifact (an iframe of another claude.ai artifact was never going to load, and the probe for `demo/index.html` always failed), and the TestFlight "Flight" button and "In App Review" text became the public App Store link and "released Oct 27, 2026". Live read back equals the source plus one publisher wrapper.

### 2026-10-27 (overlapping guide pins grouped; map version 37)
- Guide pins closer than 30 px now draw as one pin with a count ("2 spot guides"); a tap opens a sheet listing them plus "Zoom in here", which fits them at 2x to 8x. It follows the Figma mockup's content but uses the page's sheet, not a popover, so it matches every other tap on the map. Guide pins moved to their own `#guides` layer above `#over`, so marks built later cannot cover them.
- New page check (guides, 390 and 1280 px) failed 4 on the old page (Kent under Codiga Park at both widths, and Fox Island under Browns Point on the phone) and passes on the new: 173 checks, 198 Node tests. Published as map version 37 (1793089848-ed42) on Daniel's go; the live page read back equals `index.html` plus the publisher's wrapper.

### 2026-10-27 (1.0 public in the App Store)
- Confirmed live at 01:22: the iTunes lookup by bundle id returns WA Fish Map 1.0, id 6807799974, released 08:12 UTC, and the store page answers 200. The same lookup with `country=us` still returned 0 at that moment while the lookup by id with `country=us` returned 1, so the empty result at release was cache lag, as the release entry read it.

### 2026-10-27 (1.0 (10) released; pin checks wait on an unlocked phone)
- Released on Daniel's explicit "Release now" (asked in session, recommendation was to hold for the stale screenshots and dead listing links). Read first through `app-ship`'s key: exactly one iOS version pending, 1.0 build 10, release type MANUAL. `POST /v1/appStoreVersionReleaseRequests` returned a release-request object with the version id (a 2xx: the client raises on any error status), and the version read back READY_FOR_SALE at 01:12:16. The public iTunes lookup by bundle id returned 0 results right after; that is propagation lag until shown otherwise, not a failed release. `ship.py` has no release command; the scratch call reused its client.
- Device pin checks not run: the iPhone was paired, developer mode on, but locked (`passcodeRequired: true`) and its Wi-Fi tunnel came and went. `scripts/verify_pins_device.sh` now does the run in one command. Device signing is proven: `build-for-testing` for `generic/platform=iOS` succeeded and the app is signed for team 877MLS29T9 with WeatherKit. Its pass detector was checked on the other session's real passing simulator log (accepted) and a copy with one test turned to failed (refused); its unlocked branch has not run.
- A `build-for-testing` aimed at the locked phone by id sat with a 245-byte log; aim at `generic/platform=iOS` to build, and let the test run name the phone.
- `PinVoiceOverProbe` passed once on the iPhone 18 Pro simulator in another session (00:59). Known broken still says it fails every run; one pass does not overturn an intermittent failure, and a repeat run was refused here because three simulators were booted.

### 2026-10-27 (one-map page looked over in a browser; link quirks closed)
- The one-map look-over was done by machine, not by hand: `check-week.mjs --today 2026-10-27` passed 163 checks at 320, 360, 390 and 1024 px, light and dark (Layers menu, month slider, three legend lines, 44 px targets, no horizontal scroll, the four old-page redirects). A scratch click-through at 390 and 1280 px then opened the Layers menu, turned on Seasons, Spot guides and Creel counts (link carries them), found 8 "N kept" count badges and 26 season shapes and tags, with no console errors. Screenshots showed the Skagit coho tag and the Kent guide pin drawn. The phone summary chips run off the right edge by design (`.dsum` scrolls sideways). Not covered: how touch feels on a real phone.
- Finding, not fixed: at the opening zoom the Kent guide pin (`three-friends`) is under the Codiga Park guide pin and the Duwamish spawning site. `elementFromPoint` at the pin's centre returns Codiga Park (390 px) or the Duwamish site (1280 px), and a real click there opened their sheets. Zooming toward Kent separates them (one wheel step on desktop, three on a phone), keyboard and VoiceOver reach the pin directly, and pin names are drawn apart from the pins, so they are not tappable. Separating or grouping overlapping guide pins is a design change to the live page, so it is a task, not an edit made here.
- Deep-link quirks closed: `Links.write` only calls `replaceState`, and loading `?mode=spawning`, `?mode=spawning&species=Chum` and `?mode=typical` in Chromium left `history.length` unchanged from its value at first script run, including the run that appends `&month=10`. The first version of that check counted the browser's own about:blank entry and failed on the unrewritten typical link too, which is how it was caught as a broken check rather than a page bug.

### 2026-10-27 (Artifacts organized; live pages stay one level down)
- PR 95: the seasons source moved into `Artifacts/salmon-rivers/seasons/`; the build writes only `seasons-data.js` (byte-identical), and `test/season-places.test.js` now rebuilds the full expected data, rivers included (seen to fail on a stale stop). The retired Fishing Year and Three Friends pages went to `Artifacts/archive/`. The three still-published pages were first archived too, then moved back: `~/bin/artifact-refs.sh` (invariants 28 and 29) only finds `Artifacts/<slug>/artifact.json`, so a deeper binding drops out of the checks with no error.

### 2026-10-27 (1.0 (10) approved)
- Read from the App Store Connect API with `app-ship`'s key, read-only: App Store version 1.0, build 10, `appStoreState` PENDING_DEVELOPER_RELEASE, release type MANUAL; review submission `4cef16a5` state COMPLETE, submitted 2026-10-10 02:28 UTC. So 5.2.5 is cleared: the "reply to Apple if rejected" and "check the recording shows the far-date state" tasks are closed, and the Known-broken review line is removed. Releasing is not done: it makes the app public and is Daniel's to trigger.

### 2026-10-27 (page check serves the live wrapper; month names fit at 360)
- The page check's screenshots showed the "Tap the map where you are" banner and the species panel open on load. Live never does: the publisher wraps the page in a doctype and `[hidden]{display:none!important}`, and the local server served the bare file, so `.metip`/`.sppanel` display rules beat `[hidden]` only locally. Ruled out first: PR 84's brace fix (the pre-fix page showed the same). `check-week.mjs` now prepends the wrapper copied from live 1793083287-e7f9, to `index.html` only, as the publisher does.
- On phones under 390 px the month names in the month card touched ("May"/"Jun" overlapped 1.8 px at 360, 0.4 at 375), breaking the 360 px fit promise. Fixed keeping 12 px text (`design.test.js` floor): 40 px label column, -0.03em tracking, 8 px card sides. The check now runs at 360 and asserts a 1 px gap; it failed on the old page and passes on the new. 320 px still crowds, below the promise.
- Published as map version 36 (1793084530-99d6) from main after PR 93; live index.html read back equals the repo file plus the wrapper. Seen in the desktop capture, not fixed: the Fox Island Fishing Pier label sits partly under a neighbouring spot pin.

### 2026-10-26 (monthly tide refresh retired)
- Decided: the `[you]` task to re-run `build_tides.py` monthly is retired, not automated. The map stopped loading `tides-data.js` when it moved to computing tides in the page (`tide-predictor.js` over `tide-harmonics.js`, node corrections from the date), so it never runs out; checked in `index.html`, which loads only those two. `tides-data.js` stays as the engine's test oracle. README updated to match.

### 2026-10-26 (map critique applied, version 34)
- Seven findings from phone and desktop captures, all applied and measured in a browser (`docs/design/2026-10-26-map-critique.md`). The worst was a blank Key button on phones: a desktop rule after the phone block won on source order. A test now pins the order.
- Decided: on phones the age line under the bar opens the stale-report notice and the bar drops its duplicate icon; Rivers becomes an icon. That keeps every control at 44 px with no scrolling from 360 px up.
- Decided: layer symbols draw at 55 percent so the coloured report rivers lead; full strength on focus.

### 2026-10-26 (river flow on site sheets is a link, not a fetch)
- Decided (Daniel's pick): live river flow reaches the map as a link to the gauge's USGS page, not a fetch or a bundled snapshot. The claude.ai frame blocks requests outside claude.ai, a snapshot would go stale within hours, and a Claude-app browser route would reach only desktop-app viewers.
- 99 launch and shore sites sit on a gauged river by the app's 150 m nearest-river distance (full-resolution lines, curated lake sites excluded; split rivers compete but only the run rivers.json marks gauged links); `build_rivers_tap.py` writes them as `siteRiver`. No saltwater site matched, and the curated-lake exclusion currently removes none, so it mirrors the app rather than changing today's output. Published as map version 33; checked in a local browser (Sedro-Woolley shows the Skagit gauge, a Hood Canal pier shows none, the Wynoochee river sheet unchanged).

### 2026-10-26 (Two Rivers Point confirmed by Sumner's parks plan)

- Decided: a stop OpenStreetMap lacks may be confirmed by a government plan that names and maps it (`place_check.plan`, label + https url); Daniel chose this over leaving the stop unconfirmed or editing OSM. Two Rivers Point is the first: Sumner's 2024 parks plan lists it as a natural area where fishing is allowed, its trail map puts the south-end trailhead at the White and Puyallup confluence, and TrailLink says the south-end parking is at Two-Rivers Point. The build refuses a plan without a label or with a non-https url (both checked). Sources: `docs/research/2026-10-26-fishing-year-stops.md`.

### 2026-10-26 (Fishing Year stops checked against OpenStreetMap)
- The Kent "Green River Boat Ramp" stop is an unnamed public concrete slipway in OSM (node 9727835924), 3 m from the point, so it is now confirmed and gets directions on the page. Two Rivers Point is not in OSM by any name; it sits at the White and Puyallup confluence, so it is plausible, but it stays "Location unconfirmed". Sources: `docs/research/2026-10-26-fishing-year-stops.md`.
- Decided: a confirmed place may record the OSM id (`osm`, `node|way|relation/<n>`) instead of a name when the feature is unnamed. An id names one exact feature, which is stronger than a name match. Shown to work: the real data passes `--check`; a bare number in `osm` and a confirmed place with neither name nor id both fail it.

### 2026-10-26 (marker edge-tap test lands, and what it cannot prove)
- The edge-tap test and its finding sat unmerged on `origin/test/marker-edge-tap-outside` (e750258, d3a8c57) while `main` still read "geometry only"; a fresh attempt today re-derived the same result. Landed that branch's test file as-is instead of a second version.
- Re-confirmed on the iOS 27.1 SDK simulator: with `SiteMarkerView.point(inside:with:)` returning `false` for every touch (compiled into the app, checked in the build log), a tap 0pt from the pin's centre still opened its sheet; a tap past the drawn 30pt frame did too, with the override returning `bounds.contains(point)`. MapKit selects by its own slop. So the planned control ("must go red with the rect removed") cannot be built in the Simulator.
- The branch's 2026-10-18 finding, carried here since it never reached `main`: on the iOS 27.0 simulator, `minimumTapTarget` at 1pt, at 140pt, and `point(inside:)` returning `false` all left the measured reach and the test unchanged. A lone pin's reach is MapKit's own: out to 50pt either side and 54pt above its centre, 25pt below.
- Decided: the test guards that a pin stays selectable from all four edges, not that `hitRect` makes it so. Whether hardware honours the rect is a device run, filed as a `[you]` task.
- Full UI target on the same simulator: 18 tests, 2 skipped (device-only), 0 failures, xcodebuild rc=0. `PinVoiceOverProbe` passed this once; one green run does not retire its Known broken line.

