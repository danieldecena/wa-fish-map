# Washington Fishing Map (salmon-rivers page)

The published page "Washington Fishing Map" (first published as "SW Washington Salmon Rivers"; the folder keeps the old name) is one map on one URL. Until 2026-10-26 it was five tabs (Week | Map | Year | Spots | Counts); those four pages are now **layers** on the map, and their old paths redirect into it. It is not part of the iOS app.

**Map** (`index.html`) has three modes behind one thin control bar (one 56 px row; on phones the mode switch is a menu and species a filter icon). On a window 1024 px or wider with a mouse (`hover: hover` and `pointer: fine`) the bar is one 44 px row with 36 px controls; phones and touch screens keep 44 px targets. The bar ends in **Layers**, which switches on any of three layers over any mode:

- **Recent reports** (the default): eight southwest Washington salmon fisheries (Cowlitz, Lower Columbia, Lewis, Wind, Klickitat, Drano Lake, Kalama, Washougal) and, since 2026-10-26, the Skagit (a stale Fair rating from one shop report; see `docs/research/2026-10-26-puget-river-reports.md`), with a species dropdown, a ranked Rivers list and a detail sheet. Every other named river is tappable (`rivers-tap.js`) for its typical flow and WDFW notices (`rules.js`). It shows recent catch reports, not season dates, and routes people to WDFW to confirm rules.
- **Typical season**: about 540 WDFW piers, boat launches and shore access sites, each coloured by the WA Fish Map app's own seasonal rating for the chosen species in the current month. Typical timing, not a catch report and not a claim that a fishery is open. Marine sites (those in a WDFW marine area) also show a compact "Tides today" section on the sheet: the nearest bundled tide station with its distance, and today's highs and lows as text. Freshwater sites show none, and tides never colour anything.
- **Spawning**: 75 WDFW salmon viewing sites (`sites.js`) coloured by each run's typical spawning status in the chosen month.

The modes never share a map view: switching swaps the pin set, the legend, the species list and the sheets. Catch-report colours and seasonal colours are never drawn together.

**The default view (2026-10-26)** is Recent reports with two more layers on: **Typical season** and **Spawning**, drawn as neutral ink shapes (square a boat launch, diamond a pier, circle shore access, triangle a salmon viewing site), solid when in season (Prime or Good) or spawning (Peak or Active) in the month, hollow otherwise, with the word beside each shape once zoomed in. They carry no rating colour, so the colour rule above still holds. Each steps aside in its own mode, and a tap opens that mode on the site. While Typical season is on, Piers and shore steps aside (it draws the same sites). Under the bar, a month card sums up the month (report ratings with their colour and word, seasons open, spawning sites active, prime-season sites; each one a button) over a neutral heat strip of the same counts across the year; tapping a month moves the layers to it. Report rivers draw thicker for better ratings, a second cue beside colour and word.

**Deep links** (`links.js`): `?mode=reports|typical|spawning`, `month=1-12` (Spawning), `species=<exact name>`, `site=<id>` (Typical, Spawning), `river=<id>` (Recent reports) open that exact view, and the address bar follows what is on screen (`history.replaceState`, never `pushState`). `?today=YYYY-MM-DD` is read for testing and never written.

**Layers** (`layers.js`; on in the URL as `layers=seasons,spots,counts`; `typical` and `spawn` are on when a link names no layers, and `layers=none` turns every layer off; they never change a pin colour, the legend's rating rows or the ranking):

- **Seasons** (`seasons-data.js`, `season-places.js`): the Washington Fishing Year seasons (what Week and Year listed). A month slider under the bar (Spawning lends its ribbon month instead) picks the month; waters open that month get a dotted halo (rivers) or a dashed ring (named places), in ink, never a rating colour. In the current month a season ending within 7 days or opening within 14 gets a tag. Tapping one opens a season sheet: dates, where, note, source, and WDFW. Links: `month=`, `season=<id>`.
- **Spot guides** (`spots.js`): Three Friends Fishing Hole (was Spots) as a white guide pin in Kent with its own sheet. Link: `spot=<id>`.
- **Creel counts**: last week's fish kept (from `counts.js`) as a text badge beside each surveyed report river, Recent reports only; it opens the river's sheet at its creel section.

Dropped with the old pages, on purpose: the multi-year creel table (Counts) and the 7-day tide table with its 26-station picker (Week). Marine site sheets keep "Tides today".

`week/`, `year/`, `spots/` and `counts/` each hold one redirect page: Week and Year open the Seasons layer (`year/index.html#<season id>` opens that season), Spots opens the guide, Counts opens the counts layer.

Live: https://claude.ai/artifact/9oA145toRsmFcDYurdJbey (binding and versions in `artifact.json`).

## Files

| File | What it is |
| --- | --- |
| `index.html` | Page source: CSS, markup, map and sheet code. No doctype or head; the publisher wraps it. |
| `reports.js` | The rivers' report data (`SITES`; Washougal has no report, only counts) plus pure logic: rating pick, freshness, ranking, date text. Runs in the browser and in Node. |
| `counts.js` | WDFW weekly creel counts per river (newest week only). Generated by `scripts/build_salmon_counts.py` from the salmon table. Do not hand-edit. Shown in a sheet section; never read by rating logic. |
| `creel.js` | Recent WDFW angler-survey (creel) counts for map sites, shown on Typical season sheets only. Generated by `scripts/build_creel_sites.py` from the Puget Sound creel page. Do not hand-edit. Counts, never ratings: nothing in `reports.js`, `season.js`, `cluster.js` or the pin code reads it, and the page still works if it fails to load. |
| `typical.js` | Statewide snapshot for Typical season: sites, the guidance rows each resolves to (months copied verbatim from `fisheries.json`), the season-risk table, and the water, land and outline paths of the shared basemap. Generated by `scripts/build_typical_sites.py`. Do not hand-edit. The page never reads `fisheries.json`; only tests do. |
| `season.js` | Port of the app's rating (`FishingRating`, `SpeciesSeason.rating`, `AreaFishery` in `Fishery.swift`): peak, good, shoulder, season-risk cap, odd/even-year rows, exact-species and All-species (mean of the best three) ratings. Pure; runs in the browser and in Node. |
| `cluster.js` | Grid pin clustering, the same groups as the old all-pairs rule at a cost that grows with the number of pins, and `look`, the rule for how a group is drawn: neutral in Typical season, coloured in Recent reports only when every member agrees. |
| `geo.js` | Map geometry. Generated elsewhere (the generator is not in this repo). Do not hand-edit. |
| `test/reports.test.js` | Node tests for `reports.js`. |
| `test/season.test.js` | The rating port, with expected values taken from the named Swift tests in `WAFishMapTests/FisheryTests.swift` and `SeasonRiskTests.swift`. Fails if one of those Swift tests is renamed or removed. |
| `test/typical.test.js` | The generated file (header and date, unique ids, months 1-12, species names exact in `fisheries.json`, area ids, verbatim rows, tier resolution, size), the honesty text in `index.html`, and the mode split: catch-report files carry no timing and still match `baseline-pins.json`. |
| `test/creel.test.js` | `creel.js`: generated header, site ids exist in `typical.js`, counts are non-negative integers or null, real ISO windows inside the filter, source species only, exact-name or high-crosswalk matching held, counts kept out of ratings; the crosswalk file (every `site_id` is in `sites.json`, every entry has evidence, medium entries never applied); plus the matching rules (exact match, crosswalk match, near misses and medium entries that must not match, many-to-one sums, nulls, malformed crosswalk stops the build) run through the generator on `test/creel-fixture.json`. |
| `test/creel-fixture.json` | Small fixture for the matching tests. |
| `test/cluster.test.js` | Grid clustering equals the all-pairs rule, and stays fast at 5,000 and 20,000 points. |
| `test/counts.test.js` | Node tests for `counts.js` (generated header, dates, integer counts, no steelhead, Columbia sums against the table, counts kept out of ratings). |
| `test/design.test.js` | Design-system pins: the rating tokens equal the app's system colours in both appearances, the app source still draws the ramp from `DS.Rating`, the two dark token blocks agree, glass-card and legend spacing, colour-blindness simulation of the page's own tokens, and the pin label words. |
| `test/basemap.test.js` | The land tint and outline in `typical.js`: one closed polygon in the state box, the north and east edges are the straight borders, the south edge lies on `geo.js` river geometry, the closure through the water never touches Canadian ground, and both modes draw the same basemap from tokens. |
| `test/hint.test.js` | The "Most sites rate the same this month" hint: more than 80 percent of rated sites in view, unrated ignored, at least 10 rated sites, computed from the bundled data and shown only in All species. |
| `test/controls.test.js` | The control bar: one species dropdown for every mode (its accessible name says which species), Rivers in the one-row bar, the visually hidden title names the mode, 44 px targets, keyboard and focus handling. |
| `test/species-vocab.test.js` | Every name in `reports.js` `SPECIES` is an exact species name from the app's `fisheries.json` (near-misses rejected, no duplicates), and the catch-report files never carry seasonal timing. |
| `test/baseline-pins.json` | Pin colours per species filter from the page as first published; a Task 2 check that nothing changed visibly. |
| `links.js` | Deep-link state for the map: `Links.read(search)`, `Links.toQuery(state)`, `Links.write(state, history, location)`. Pure; runs in the browser and in Node. |
| `tides.js` | Tide helpers for the map's marine site sheets, reading the bundle `window.TIDES`: `stationsOf`, `nearest`, `miles` (haversine), `days` (bundled extremes for a range; days after the bundle's end carry a "Beyond the bundled predictions" note), `fmtExtreme`, `footnote`. A static list of the first 11 stations is the fallback for Node tests and a page whose bundle did not load. Makes no request. |
| `tides-data.js` | NOAA CO-OPS high/low predictions (MLLW, feet, station local time) for 26 Washington stations, 45 days from the day it was built. Test oracle only; the map does not load it. Generated by `scripts/build_tides.py`. Do not hand-edit. |
| `tide-harmonics.js` | NOAA harmonic constants and subordinate-station corrections for the same 26 stations; what the map's tide sections compute from. Generated by `scripts/build_tide_harmonics.py`. Do not hand-edit. |
| `tide-predictor.js` | The Neaps tide engine (@neaps/tide-predictor 0.11.0, MIT), vendored unchanged by `scripts/vendor_tide_predictor.py`. Do not hand-edit. |
| `layers.js` | Layer names and the rules the layers draw by: `parse`, `toggle`, `keptText` (a count badge), `openIn` (season open in a calendar month), `tagFor` (ends within 7 days, opens within 14), `monthLabel`. Pure; runs in the browser and in Node. |
| `seasons-data.js` | Byte copy of `Artifacts/fishing-year/data.js` (generated by `scripts/build_fishing_year.py`); `test/season-places.test.js` fails if they differ. The build writes both, so rebuild rather than copy. |
| `season-places.js` | Hand-maintained: where each season goes on the map. Only places the season's own `where` text names, each with that phrase as evidence; vague text stays in the sheet. |
| `spots.js` | Hand-written spot guides, verbatim from the old Spots page (`test/fixtures/spots-page.html`); the Kent point is sourced in `docs/research/2026-10-26-three-friends-location.md`. |
| `week/`, `year/`, `spots/`, `counts/` | One redirect page each (see above); `test/redirects.test.js`. |
| `rivers-tap.js` | Tappable river geometry in the `geo.js` projection, with each gauge's monthly flow range. Also `siteRiver`: each freshwater Typical-season site on a gauged river (the app's 150 m nearest-river distance, curated lake sites excluded, and only the river run that owns the gauge) mapped to that river, so its sheet shows the same flow range and "Today's flow on USGS" link as the river sheet. Generated by `scripts/build_rivers_tap.py` from `WAFishMap/Resources/rivers.json`, `river_stats.json` and `typical.js`. Do not hand-edit; no header comment. Rerun after any input changes. |
| `test/rivers-tap.test.js` | `siteRiver`: keys are `typical.js` sites, values are gauged rivers, Sedro-Woolley is on the Skagit and Soos Creek Drift on the gauged Green, no saltwater site is linked, and the site sheet reads it. |
| `rules.js` | WDFW emergency-rule notices (dated, linked, never colour anything), hand-written from WDFW's own rule pages; sources in `docs/research/2026-10-20-river-reports-and-rules.md`. |
| `sites.js` | Spawning-mode viewing sites from WDFW's Salmon Viewing list. Generated by `scripts/build_spawning_sites.py` (the sites are typed into the script). Do not hand-edit. |
| `check-week.mjs` | Playwright page check of the map with and without its layers: console errors, no tab bar, 36/44 px bar targets, no horizontal scroll at 320/390/1024 in light and dark, the layers on (button label, slider, legend lines), map deep links, the four redirects, "Tides today" on a marine site sheet and not a freshwater one, and that no request leaves the page. Needs Playwright (not installed on the Mac mini). The static server refuses paths outside the folder (403); unknown `--flags` print usage and exit 2. `--shots <dir>` saves captures. |
| `test/tides.test.js`, `test/links.test.js`, `test/layers.test.js`, `test/spots.test.js`, `test/season-places.test.js`, `test/redirects.test.js` | Unit tests for tides, deep links, the layer rules, the spot guide, the season places and the redirects. `test/fixtures/noaa-seattle.json` is a saved NOAA response (used by `scripts/test_build_tides.py`). `test/tides.test.js` also checks that `tides-data.js` parses and covers 30+ days, and that no page code file contains `fetch(`, `XMLHttpRequest`, `sendBeacon`, `WebSocket`, `EventSource` or `import(` (none do, so the per-file allowlist is empty). |
| `baseline.html` | The page as first published, single file. The rollback source. |
| `serve.js` | Local static server that wraps `index.html` the way the publisher does. |

## Run and test

```bash
node Artifacts/salmon-rivers/serve.js          # http://127.0.0.1:4173/
node --test "Artifacts/salmon-rivers/test/*.test.js"
node Artifacts/salmon-rivers/check-week.mjs     # page check (Playwright; set PLAYWRIGHT_CORE if needed)
```

No dependencies to install. Add `?today=2026-10-26` to the local URL to see how the page looks on another date (the stale-reports banner appears once the newest report is more than 7 days old; Typical season uses that date's month and year, so `?today=2026-07-15&mode=typical` shows July).

## Tides

The map computes tides in the page: `tide-predictor.js` (the Neaps engine) applies NOAA's harmonic constants from `tide-harmonics.js` for any date, node corrections included, so nothing runs out and there is no monthly refresh. Rebuild the constants only to add a station or if NOAA revises a station's datums:

```bash
/opt/homebrew/bin/python3 scripts/build_tide_harmonics.py           # fetch NOAA constants, rewrites tide-harmonics.js
/opt/homebrew/bin/python3 scripts/build_tide_harmonics.py --check   # validate the existing file, no network
```

`tides-data.js` is not loaded by the map. It is NOAA's own published high/low predictions for a fixed 45-day window, kept as the oracle `test/tide-engine.test.js` checks the engine against. Rebuild it (`scripts/build_tides.py`, then `--check`) only when the oracle itself needs new stations or dates:

```bash
/opt/homebrew/bin/python3 scripts/build_tides.py           # 45 days from today (America/Los_Angeles), rewrites tides-data.js
/opt/homebrew/bin/python3 -m unittest discover -s scripts -p "test_build_tides.py"
```

Eight of the 26 stations are NOAA subordinate stations (offset predictions that NOAA publishes as hilo predictions; shown like reference stations). "Tides today" on the map uses the nearest station and shows its distance; there is no distance cap (the farthest marine site is about 16 mi from its station).

`build_tides.py` fetches CO-OPS hilo predictions (MLLW, english, `lst_ldt`) for each station in its `STATIONS` list and fails (non-zero, nothing written) on an HTTP error, a NOAA error object, an empty station or times that do not increase. To add a station, pick a Washington id from NOAA's `stations.json?type=tidepredictions`, check its metadata, and add it with NOAA's coordinates to 4 decimals and a short name.

## Refresh Typical season

```bash
/opt/homebrew/bin/python3 scripts/build_typical_sites.py            # rewrites typical.js
/opt/homebrew/bin/python3 scripts/build_typical_sites.py --refresh  # fetch WDFW marine areas again first
```

Sites come from `site/data/sites.json` (WDFW MajorFishingArea layers 0 and 1, written by `scripts/build_web_data.py`; 477 access sites and 63 piers, the app's own counts). Marine areas come from layer 6 with the URL `MapScope.swift` uses, cached in `.cache/wdfw/` (gitignored). Each site is matched to guidance the way `FishingMapModel` does it: marine area by containment, else the nearest edge within 150 m; a matched area that `fisheries.json` lists uses its rows; everything else uses the freshwater table (statewide, then county, then waterbody, then the lake species WDFW lists for the ramp). Matching constants are read from the Swift source. A site where the app shows nothing is drawn gray, "No seasonal guidance". Rerun after `fisheries.json` or `sites.json` changes; the tests compare against both. The file must stay under 1.5 MB (the script refuses to write more).

Both modes share one basemap, drawn from `typical.js`: a very light land tint (`--land`) inside Washington, the WDFW marine areas as salt water over it, the state outline (`--state-line`), then the rivers from `geo.js`. The outline is the 49th parallel, the 117.04 W meridian and the 46th parallel plus the Columbia, which the generator finds in `geo.js` rather than typing in; the Idaho line below Lewiston is left open because `geo.js` has no Snake River there. The tint polygon is closed through marine-area water that the page paints over, so it only shows on land; the generator refuses to build if a leg of that route leaves the WDFW water polygons, and `test/basemap.test.js` checks it again. No Oregon, Canada or Idaho shape is drawn.

## Refresh creel counts

```bash
/opt/homebrew/bin/python3 scripts/build_creel_sites.py            # rewrites creel.js and docs/research/2026-10-18-creel-site-matching.md
/opt/homebrew/bin/python3 scripts/build_creel_sites.py --refresh  # fetch every WDFW page again first
```

Source: https://wdfw.wa.gov/fishing/reports/creel/puget (server-rendered HTML, one table per sample day, `?sample_date=1|2|3` for the last 15|30|60 days, `?page=N`). The default window is 30 days (`--window`). Pages are cached in `.cache/wdfw/creel/` (gitignored). Raw data: WDFW changes it after QA/QC, so regenerate before each publish.

## Rebuild river geometry and viewing sites

```bash
/opt/homebrew/bin/python3 scripts/build_rivers_tap.py      # rivers-tap.js
/opt/homebrew/bin/python3 scripts/build_spawning_sites.py  # sites.js
```

Both were recovered on 2026-10-26 from the unmerged `feat/one-app-2026-10-20` branch; run against the files on `main`, the first rebuilt `rivers-tap.js` byte for byte and the second changed only the header line naming the script.

- A blank cell is null, never 0; a window total is null if any sampled day in it is blank; a row that will not parse is listed in the review file, not dropped.
- A WDFW ramp becomes a map site by exact normalized name, else by a `high` entry in `scripts/creel_crosswalk.json` (and within 1 km if the source ever gives coordinates; the Puget page gives none). Shared names are ambiguous and stay unmatched unless a high entry resolves them. 9 of 41 ramps sampled in the last 30 days match (John Wayne Marina by name, 8 by crosswalk); most of the rest are city and port ramps that are not in the WDFW access layer. No fuzzy matching: a near name that is not in the crosswalk does not match.
- The crosswalk holds reviewed entries `{wdfw_ramp_name, site_id, confidence, evidence, note}`. `high` needs two independent signals (name plus an independent coordinate or a page naming the same facility) and is applied; `medium` entries are candidates for the owner to approve (change `confidence` to `high`) and are never applied. A ramp attached to a pier means WDFW counts boat and shore interviews at the facility; the sheet keeps the source ramp name. The build stops on a malformed entry or a ramp name that is no longer in WDFW's dropdown. The review file lists every ramp sampled this season with its match type and evidence.
- Ramps that map to one site are summed only if sampled on exactly the same days.
- Not used: Buoy 10 and Willapa Bay (one fishery-wide table, no site column) and the north coast page (per river, not per ramp). The review file records what each page really provides.
- The sheet shows the window as first to last sampled day and says so when it ended more than 14 days ago. The `puget-annual` page is for older years and is not used while the recent window has data.

## Refresh the reports

Edit `SITES` in `reports.js`. Each species entry has `r` (`prime`, `good` or `fair`), `asOf` (the date of the report it comes from, `YYYY-MM-DD`) and `d` (the sentence shown). Rules:

- Never invent a date. If the source does not date a statement, use `asOf: null` and the page says "Date not given".
- Keep dates out of the sentence; the date chip shows them.
- Run the tests; one of them rejects a bad date or a date left in the prose.

A river beyond the original eight (spec: `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md`) is one more `SITES` entry with three extra fields: `tap` (a river id in `rivers-tap.js`; its path is the highlighted line), `ll` (`[lat, lon]` of the pin, a named access point on that river) and `added` (the day the entry was added). For these entries, `test/reports.test.js` also requires:

- `src: { label, url }` (https) on every species report: a named shop, guide, guide service or agency, never a social-media post;
- a dated report at most 21 days old on the `added` day (one older than 7 days shows as a dashed, stale rating from the first day);
- `slow` only with the source's `phrase`;
- a pin inside the state map's bounds (a bounding box test) and a `tap` that exists.

The report must be true of the whole river the line draws: a new site colours the entire tappable river, mouth to headwaters, so a report about one reach is not added.

Rate from the source's own words: hot, excellent → `prime`; good, very good, solid → `good`; fair, some fish, spotty → `fair`; slow, poor, tough → `slow`. A report about rules, flows, trout, forecasts or effort with no catch read gives no rating, and a river WDFW has closed for the species gets none. Each pass is recorded in `docs/research/` first.

## Publish and roll back

Publishing replaces the live page. Read the live artifact first (it refuses a stale base, and pages have been edited outside the repo), then publish `index.html` to the same URL with whichever files changed. Files left out stay as they are on the live page; the full list is `files` in `artifact.json`.

```
Artifact  file_path=Artifacts/salmon-rivers/index.html
          url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
          files={ "layers.js": "Artifacts/salmon-rivers/layers.js", ... }
```

Record the new version id in `artifact.json`. To roll back, republish a previous version id. Never pass `force`.

## Rules that bind this page

- Guidance, not regulation. The advisory, the WDFW link and the "not season dates" line stay on every sheet and on the list. Season and spot sheets say "Guidance, not regulation." and link WDFW.
- Rating is always also written as text; colour alone is not enough (orange and yellow fail this repo's colour-blind gate for deuteranopia). In Typical season every single pin carries its rating word beside it: the full label where it fits, else the word alone (`Season.SHORT`). `test/design.test.js` simulates deuteranopia and protanopia on the page's own tokens.
- Text 4.5:1, pins 3:1, buttons at least 44 px, light and dark.
- No network requests from the page. Tides are computed in the page from bundled NOAA harmonic constants (`tide-harmonics.js`), because the published page runs in a frame whose CSP only allows claude.ai connections, so a live NOAA fetch is blocked there. If the engine or constants did not load, the map shows no tide section. Tide heights are never turned into a rating or a "good time to fish" word, and nothing is coloured by tide.
- Typical season: the legend, the notice, every sheet and the footer say "Typical timing from WA Fish Map guidance, not a catch report and not a claim a fishery is open", keep the WDFW rules link and "Before you go", and never present season dates as authoritative. Colours are the same four tokens plus gray. Slow is blue; in Recent reports it appears only where the source itself says slow or poor (Kalama, with the phrase and a link recorded), never from a count. Species names are the app's exact names. Notes are shown exactly where the app shows them (area, county, statewide), never moved to a narrower or wider place.
- Clusters never carry a rating they do not share. Typical season clusters are neutral (`--cluster`) with the count; colour is on single pins only. A Recent reports cluster is coloured only when every member has the same rating and release-only state.
- `reports.js`, `counts.js`, `creel.js`, `geo.js` and `index.html` never contain seasonal timing fields (a test enforces it). Timing lives only in `typical.js` and is read only by `season.js`.
- Pier sheets claim nothing about where on a pier to fish: no source supports it (`docs/research/2026-09-16-pier-species-position.md`).
