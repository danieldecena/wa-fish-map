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

### 2026-10-31 (catch reports refreshed; not yet published)
- Reports pass recorded in `docs/research/2026-10-31-river-reports.md`. Wind River and Drano Lake coho are Good on The Guide's Forecast's Oct 29 SW Washington summary ("Wind River/Drano still good for coho"); the newest report moves from Oct 17 to Oct 29. "Klickitat River mouth excellent" in the same summary names no species, so it gives no rating (the Washougal rule).
- Wind River is release only from Nov 1 (pamphlet: release all salmon), so both its species are marked `release: true` and the river ranks after the keepable ones. Klickitat's pair and Drano's Chinook gain the Oct 15 Guide's Forecast summary as their source: its words match those ratings exactly. LEGACY is down to 7.
- Kept, not dropped: the Skagit coho rating. WDFW extended the Skagit coho season through Nov 15 (rule of Oct 30). Cowlitz, Lower Columbia, Lewis and Kalama have no newer report with a rating word: Northwest Sportsman's Oct 26 relay of WDFW's creel summary is counts only.
- Found, not fixed: `rules/river-rules.json` still ends the Skagit coho rule and the Wind River rows on Oct 31.

### 2026-10-30 (depth shading, version 50)
- Built: a ninth layer, Depth shading, on by default. 70 WebP tiles (660 KB, about 20.5 m a pixel) from NOAA NCEI CUDEM, generated by `scripts/build_depth_shading.py` into `depth-shading.js`, drawn as SVG images in `#vp` right after the base map, so the NOAA contours, rivers and pins stay on top and water focus blurs and dims them. Puget Sound only: WDFW areas 8-1, 8-2, 9, 10, 11, 12, 13, masked to the outlines and to DEM water, which keeps the lakes out. The Key says where it covers, that it is a model and not a survey or sonar, cites CIRES / NCEI, doi:10.25921/ds9v-ky35, and carries a depth ramp in feet below low tide.
- Decided: the datum is NOAA VDatum (2.2 km grid, region `westcoast`) plus a smooth local correction fitted to the ENC soundings. VDatum alone fixed South Sound (1.87 to 0.35 ft) and nothing else; Seattle-Bremerton, Tacoma-Vashon, Admiralty Inlet and Hood Canal stayed 1.1 to 2.4 ft deeper than the chart. VDatum's separation is within 0.1 m of the CO-OPS station values, so the gap is not the datum; the cause was not found. Median DEM minus sounding, scored on 0.2 degree blocks left out of the fit: within 0.3 ft in every area. Mean absolute error 3.1 ft, 75 percent within 3 ft; Hood Canal 9.3 ft. The Key states that figure.
- Decided: the shading holds rather than vanishing at the closest zoom (a raster pixel is 3.7 CSS px on a laptop, 1.2 on a phone): full strength to 2.5 px, then down to 60 percent at 4 px. Opacity .8 in light (was .9; lightened 2026-10-30, heavy on phones), .5 in dark, 1 under reduced transparency. Smoothed DEM contours were left out.
- Published as version 50 (1793408448-f2dd); `depth-shading.js` is in `artifact.json`'s `files`. Read back: live index.html equals the repo file plus the publisher's wrapper; depth-shading.js, layers.js and links.js are byte-identical. Checks: 259 Node tests, 419 page checks, 100 Python tests (5 need the numpy venv and skip under system python). Version 51 (1793409834-80e2) lightened the light-mode opacity to .8 (PR 138); read back equal.


### 2026-10-29 (water focus for marine areas, version 49)
- Built: the river focus now has a kind, `river` or `area`. Tapping open water inside one of the 16 WDFW marine area outlines, or a pier, launch or shore site whose `site.area` is that area, fits the whole area in the free map area (phones: above the 42 percent card), blurs and dims the rest the same way, and draws the outline as an accent line on a halo over a very faint fill. The area's sites stay sharp with their names. The card is "Marine Area 11" over "Tacoma - Vashon Island", how many piers, boat launches and shore sites it holds, "In season now" (the page's own compact species rows from the area guide), the tides for the nearest NOAA station to the area's centre, "Piers and launches in this area (N)", "Before you go" and the WDFW link. A site's sheet in the focus gains "Back to Marine Area 11" and an "In Marine Area 11" list. Outlines are `marine-areas.js` (about 56 KB, generated by `scripts/build_marine_areas.py` from `.cache/wdfw/marine-areas.geojson`, the Oregon polygon dropped as the app does). No new URL key: `?mode=typical&site=<id>` already reaches it.
- Decided: the water tap does not switch modes. The card is the same in Recent reports, Typical season and Spawning; outside Typical season the rating in its species rows is a word in a plain chip, so catch-report colours and seasonal colours never share a view. Tapping a Typical-layer marker still switches to Typical season, as before. A tap on any water is now an area tap, so tapping the Sound with a river sheet open opens the area instead of closing the sheet.
- Decided: `bbox` and `centroid` are measured on the outline clipped to the pan window (state box plus 12 units), because the four ocean areas (1 to 4, no sites, no seasonal guidance) run out to -129 degrees; the drawn path is not clipped. Areas 1 to 4 are tappable and open a card with no species rows and no site list.
- Not built: lakes (no outlines in the repo). Not done: keyboard entry to an area other than through its sites; the hit polygons are not focusable.

### 2026-10-29 (water focus for rivers, version 48)
- Built and published: tapping a river (any of the 434 with a path), a report pin or list row on a river, or a launch or shore site linked to a river (99 are) fits the whole river in the free map area and puts the rest of the map out of focus: base and heat layers blurred 3.5 px under a faint wash, other markers dimmed to .3 (and blurred 2 px on a mouse), while the river, its pin, its launches and their labels stay sharp. The river card gains "Access on this river (N)" and the river length; a launch opened from it shows "Back to <river>". Done, Escape or a tap on empty map ease back to the camera held before the first focus. Reduced motion: no blur, instant; reduced transparency: dim only; touch screens dim markers only (blur cost was within noise in headless Chromium, but there is no real iPhone GPU test). Tokens: `--wf-dim`, `--wf-blur`, `--wf-mblur`, `--wf-scrim`.
- Decided with Daniel: the look is a defocused background with a sharp subject (like a game title screen), not only a dim; and it applies to places with an extent (rivers now; lakes, bays and marine areas later), not to a lone pier, spot or shore pin, which keep the plain neighbourhood zoom and card.
- Phone follow-up in the same PR: with a river in focus the card is at most 42 percent of the screen (it was 66, leaving a 130 px strip), checked by a page check and by eye at 390x844.
- Not built, and what it needs: marine areas (17 WDFW outlines are in the gitignored build cache, 7,520 points, about 60 to 70 KB baked in the page projection, linked to sites through `site.area`); lakes (653 in lakes.json have a point and no geometry; NHD or WDFW outlines, about 100 to 200 KB). Marine areas are the next candidate.
- Checks on main plus this: 229 Node tests, 324 page checks.

### 2026-10-29 (opening view on the fishing, motion shipped, depth spike result; version 47)
- Shipped in version 47: the opening view fits where the fishing is (PR 130). On a portrait phone it opens on the west side, at 1.76 times the old scale, 5 report rivers in view instead of 2, 70 percent of sites in view; a laptop view is unchanged (height-limited); zooming out still reaches the whole state. Also the Figma-designed motion (PR 125, 274 page checks on main plus motion): sheet, popovers, pin select, disclosures, heat and depth fade, layer switch and a distance-scaled camera, all inside prefers-reduced-motion: no-preference. Figma Motion page 23:175 and `docs/design/motion-spec.md`; get_motion_context loops everything and gives no transform-origin, so the durations, stagger and reduced-motion rules are written by hand.
- Depth-shading spike (PR 131, not merged, docs only): worth integrating. CUDEM 1/9 arc-second (public domain, 2.3 by 3.4 m, NAVD88) baked as a WebP relief plus smoothed contours; Puget Sound fits about 1.1 to 1.2 MB, the Strait, San Juans and outer coast do not at that pixel size. Against about 4,000 ENC soundings the median error is 1.6 to 1.9 ft deeper (82 to 87 percent within 3 ft once the bias is removed). Needs a proper NAVD88 to MLLW shift (Seascape's z13 tiles do it, CC BY 4.0, credit "(c) Open Waters"), lakes need their own surface height and Lake Union is wrong, the raster is mush at pier-level zoom (4x and up), and it would look more authoritative than it is. Decision still Daniel's: whether to build a Depth shading layer (build script, generated depth-shading.js, SVG image in depthBuild, credit text, tests).
- Apple docs survey (PR 127, merged): top web items are the unified Maps directions URL, a working sheet grabber with swipe-down, double-tap zoom and live Reduce Motion; top app items are WeatherKit gusts, pressure trend and alerts, an approximate-location label and VoiceOver custom actions. MapKit JS and the WeatherKit REST API cannot run in the published frame.
- Still open: the spotlight on a selected river and its linked launches (not built), a read-through of the river rules, and the depth shading decision.

### 2026-10-29 (rules re-verified and corrected, name-only labels, pan limit; versions 45 and 46)
- A second agent re-read WDFW's pamphlet and emergency rules for all 43 river rule rows: 32 matched, 11 differed (end dates stopping at Oct 31 while the rule runs to Dec 31, a Wind River end point, one Washougal night closure date, per-species adult limits where WDFW gives one combined limit). All fixed in PR 126 and published as version 45; Lower Columbia coho restored from the Sept 24 emergency rule and the pamphlet; four missing closed stretches added. Still out: Wind River Chinook below Highway 14 in October (WDFW has not said in writing that wild Chinook may be kept; phone WDFW Southwest Region 360-696-6211 first) and Lewis Colvin Creek to the power lines. Daniel has not read the rows himself.
- Name-only layer labels (PR 124, version 45): the rating word is gone from the map label, kept in the accessible name and the sheet. Stacking the word under the name was tried and measured worse (32 labels fit against 40), so it was not used.
- Pan limit (PR 128, version 46): zoomed in, the screen's edges stop at Washington's border plus 2.5 percent; the old clamp let a drag leave 79 of 125 map units empty. A merge of the check script once dropped a closing brace and was committed unparsed; it was caught before pushing and repaired, and commits now gate on node --check, the tests and the page check.
- Fisheye distortion declined (it makes shorelines and distances wrong where they matter). Instead: spotlight a selected river and its linked launches (99 launches are already linked to a river in the data), depth shading from the spike, water drawn stronger than land. The spotlight is not built yet.
- Open: motion PR 125 (Figma-designed), depth-shading spike, Apple docs survey PR 127.
### 2026-10-29 (Apple developer docs survey: mapping, weather, design, behavior; nothing built)
- Decided: research only, no code. `docs/research/2026-10-29-apple-docs-map-weather-design.md` ranks what to adopt. Top five: (1) the web page's Directions links move to unified Maps URLs (`maps.apple.com/directions?destination=lat,lon&mode=driving`, iOS 18.4 and later); (2) the app's plan weather adds gusts, pressure trend, moon phase and government alerts from one WeatherKit call (`.hourly, .daily, .alerts`), no tides or water temperature exist in WeatherKit so NOAA stays; (3) the app reads `accuracyAuthorization` and Daniel decides whether the location prompt leaves launch; (4) the web sheet gets a working grabber with swipe-down dismiss, double-tap zoom and a live Reduce Motion listener, and the app gets Reduce Motion on camera moves and VoiceOver custom actions on pins; (5) `MKTileOverlay` (iOS 7.0, confirmed) carries the baked depth raster only after the `spike/depth-shading` branch reports. MapKit JS and the WeatherKit REST API cannot run in the published frame (network, token, secret key). No MapKit symbol renders bathymetry. Not confirmed in the docs: bundled-file tile loading, MapKit JS from a sandboxed frame, WeatherKit simulator limit, any HIG spring or duration numbers (the Motion page has none).

### 2026-10-29 (map tools: what to integrate, decided after the depth spike)
- Decided, saved for after the spike: integrate nothing new until the depth-shading spike (branch `spike/depth-shading`) reports. The only candidate is depth shading baked into a file like `depth-data.js`, because the published page runs in a frame that blocks all network requests, so no map library, live tile source or Fishbrain-style feed can run there. If the spike shows an open bathymetry source beats the current NOAA contours at Puget Sound scale, bake it (generated file plus a build script and tests); the same baked raster could be offered to the iOS app as a custom tile overlay (believed supported by MapKit, not checked), which would avoid moving the app to MapLibre Native.
- Decided against: scraping or reusing Fishbrain data (its terms could not be read, and CLAUDE.md rules out a public catch heatmap); moving the web page to MapLibre (large rewrite, no gain while it cannot fetch tiles); forking any open fishing app (the ones found were small hobby projects). Repos found: prozessor13/seamap (MIT), openwatersio/gebco-tiles (licence unclear), cameronbodine/pingmapper (MIT, for sonar logs). Fish Deeper's 2D and 3D depth maps and bottom hardness maps are the feature targets; its real-time sonar needs hardware.
- The "people actually go here" signal already in the page is WDFW's weekly creel counts; WDFW's boat and bank-angler flight counts are the next legitimate source. A private on-device fishing log is the safe form of user data if wanted later.

### 2026-10-29 (river rules published, version 44; open items closed)
- Decided: PR 118 shipped the nine report rivers' rules as text with three rows left out before merge: Lower Columbia coho (a 3 versus 2 adult limit between the Sept 24 emergency rule and the Oct 5 pamphlet, and October rows assumed for the Puget Island to Bonneville reach) and the Wind River Chinook row below Highway 14 (inferred). The Cowlitz coho row was spot-checked against WDFW's pamphlet page and matches. Every other row is the agent's direct reading of WDFW pages on 2026-10-29, expires on its `through` date, and sits under the "Confirm on WDFW" line. Daniel asked to finish the list; he did not review the rows, so a read-through is still owed.
- Closed: PR 117 (version 41 record) as superseded by 120; the "artifact alias" request was dropped by Daniel.
- Still open: the motion PR (Figma-designed animation) and the depth-shading spike (open bathymetry, baked into files because the published page cannot fetch).

### 2026-10-29 (web design pass: sheets, bar, fish names; Figma now follows the web)
- Decided: design edits happen on the real web page first; Figma is for motion, diagrams and the component library afterward. PR 119 (version 42) made the side sheets compact and consistent: one thin-line icon row (Directions, WDFW rules, Timing or Site info), a sheet that grows from 380 to 520 px, species listed one line each with a 12-month strip (Good and Prime shown, Fair and Slow folded), four long fish names shortened for display only (exact names stay in the tooltip, accessible name, data and filters, which the species-vocab rule requires), toolbar controls 28 px drawn and 44 px to click, and the month card's "at a glance" heading and report tally removed. My calls, not asked: heat circles and bars moved to violet because red, orange and amber already mean Excellent, Good and Fair reports and every layer is now on by default; Layers has All on and All off; creel bars carry a kept and released key.
- Checked: 202 Node tests and 242 page checks; each new check was shown to fail on the page it targets. A commit once went in with a failing test because the commands were chained without stopping on the failure; the next commit fixed it and gates on the test exit status.
- Verified: version 42 read back, live index.html equals the repo file plus the wrapper. Not verified: the published page was not clicked through; the heat violet and sheet width were seen only in headless captures.
- FigJam boards made from the page: sheet skeleton https://www.figma.com/board/EOtUYTxcQWQQSj3J38qiaA and interaction states https://www.figma.com/board/0FYQ7iQtEkhQWngY4sGYUz. Open: PR 118 (river rules from WDFW, with five stated uncertainties) needs Daniel's read before merge; PR for motion (Figma-designed) is in progress.
### 2026-10-29 (river rules as text on the web map's sheets)
- Decided: the web map's report-river sheets show WDFW's rules as text (a "Rules for <water>" card list under the creel section), from `rules/river-rules.json` built into `river-rules.js` by `scripts/build_river_rules.py`. Web page only: the iOS app keeps its guidance-not-regulation stance and never reads the file. No per-rule source label or link on the sheet; the sources are in `docs/research/2026-10-29-river-rules.md`. The sheet shows a "Checked Oct 29" line, the existing WDFW link and the unchanged "Confirm this water's rules on WDFW before you fish" line.
- Read from WDFW on 2026-10-29: the emergency-rules list (only the Lower Columbia update of 2026-09-24 and the Cascade/Skagit rule of 2026-10-15 touch these waters) and the "Fishing in Washington" pamphlet pages WDFW publishes on eRegulations (all marked updated 2026-10-05). Rows are written for salmon only (coho, Chinook, and gear, permit and closed-water rules that apply to salmon) on all nine report waters: Cowlitz, Lower Columbia (Tongue Point line to Bonneville), Lewis (North Fork), Wind (mouth to Shipherd Falls), Klickitat (mouth to Fisher Hill Bridge), Drano Lake, Kalama, Skagit, Washougal.
- Not covered: Wind River above Shipherd Falls (no fall salmon rule found in the table), anything past each row's `through` date (the page drops an expired row rather than show it; Nov 1 changes on the Columbia, Lewis, Wind and Drano are not written), steelhead, trout and sturgeon. The Lower Columbia emergency rule says 3 adults for Tongue Point to Puget Island while the printed pamphlet still says 2; the row follows the emergency rule. `rules.js` (hand-written emergency notices) is unchanged.

### 2026-10-29 (Figma library reconciled to DesignSystem.swift; map panels critiqued; all layers on by default)
- Decided: Figma changed to match code. `scripts/figma_ds_diff.py` found 10 drift rows (rc 1): seven rating colors were still the iOS 17/18 system values (slow, fair dark, good, prime) and three `DS.TypeScale` roles (fineprint, mapLabel, tideValue) had no text style. Edited in place: the seven variables set to the iOS 26 resolved values, three text styles added (11 total). Re-exported and re-diffed: `[ok] no drift, 14 not covered`, rc 0. The 14 are Figma-only variables (accent, ink, surface, fill/tertiary, radius cell and pill, spacing 3-12, tap target) that each match a literal in the views; accepted, recorded in `docs/research/2026-10-27-figma-library-drift.md`. Decided by Claude, not asked, since each is reversible in Figma.
- Checked: 0 detached instances on Components (71) and Screens (112); 2 text nodes without a style, both the "Closed" label, which Swift draws as `.caption.weight(.semibold)` with no `DS` role. Rating Badge screenshot shows all five states drawing. Not checked by screenshot: the other components.
- Code Connect cannot be used: the mapping call is refused on these plans. The Swift line numbers cited in the component descriptions were re-read against the code and match.
- Map: PR 110 opens the page with all six layers on (`layers=none` still turns them off). Cost seen at 390 px: the month card opens fully and its chips run off the edge. `docs/design/2026-10-29-panels-critique.md` critiques the Layers menu, Key and site sheet; findings 1-5 are open. Whether Typical season and Spawning should be one mode is Daniel's call (finding 6).

### 2026-10-27 (pin checks pass on the iPhone)
- `scripts/verify_pins_device.sh` ran on Daniel's iPhone (unlocked, `passcodeRequired: false`) at 03:54: `MarkerEdgeTapUITests` passed (24.4 s) and `PinVoiceOverProbe` passed (14.5 s), `** TEST SUCCEEDED **`, xcodebuild exit 0, read from the log, not the wrapper. The 44pt tap target's Known broken line is removed: hardware, unlike the simulator, consults `hitRect`, and the edge tap landed there. Not done: the test was not run on device with `hitRect` broken, so it has been seen to pass on hardware, not seen to fail there.

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

