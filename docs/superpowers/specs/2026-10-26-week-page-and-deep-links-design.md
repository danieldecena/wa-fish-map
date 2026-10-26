# Washington Fishing Map — "This week" page and deep links

Design spec, 2026-10-26. First of four web-page sub-projects agreed in brainstorming
(this one; then live conditions; then spot-guide template; order chosen by Daniel).
Scope is the published web page at https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
only. The iOS app is untouched.

## Why

The page is four tabs (Map, Year, Spots, Counts) that each answer one question.
Nothing answers "what should I do this week?" — which seasons are open and ending,
which rivers have a fresh report, which WDFW rules landed, what opens next. All of
that data is already published on the page: `year/data.js` (dated seasons and
milestones), `reports.js` (dated per-species reports with a 7-day freshness rule),
`rules.js` (dated WDFW notices). This spec composes it into one page and makes every
card land on the exact map state it describes.

Audience: Daniel planning his own trips, friends on a phone with no explanation,
and anyone judging the app from the link. Guidance, not regulation, on every surface.

## What ships

1. `week/index.html` + `week.js` — the "This week" page, a fifth tab.
2. `links.js` — URL state for the map page (`index.html`), read on load and
   written on change.
3. The tab bar on all five pages becomes **Week | Map | Year | Spots | Counts**.
4. `tides.js` — a 7-day NOAA tide table on the Week page for one chosen
   station (added by Daniel mid-brainstorm; map-sheet tides stay in the
   live-conditions sub-project).
5. Node tests for `week.js`, `links.js` and `tides.js`; a page check over the
   published site.
6. A `/design:design-critique` pass over the five pages whose top three findings
   become the final tasks of the implementation plan.

Not in scope: USGS river flow, tides inside map site sheets, favourites, more
spot guides, any change to `fisheries.json`, any change to the iOS app.

## 1. The Week page

### Files and loading

`week/index.html` is a plain page in the Spots page's grouped-panel style (Artifact
Kit tokens, rating colours from WA Fish Map), with the shared tab bar. It loads, in
order: `../year/data.js` (sets `window.FY`), `../reports.js` (`window.Reports`),
`../rules.js` (`window.Rules`), then `week.js` (`window.Week`, UMD like `reports.js`
so Node tests can `require` it), then an inline script that calls
`Week.build(FY, Reports, Rules, today)` and renders the result.

`today` is `?today=YYYY-MM-DD` when present (the same override `index.html`
honours), else the local calendar date. It is only ever read.

### Header

Title "This week". Subtitle: the Monday–Sunday range containing `today`, e.g.
"Mon Oct 26 – Sun Nov 1". Under it the site's standing guidance line: "Guidance,
not regulation. Confirm seasons, limits and closures on WDFW before you go."

### Sections, in order

Each is a captioned grouped panel. A section with nothing to show still renders,
with one muted row "Nothing this week", so the page keeps its shape.

**Open now.** `FY.seasons` where `start ≤ today ≤ end` (inclusive, by calendar
date), sorted by `end` ascending, then by name. Row: `name` (bold), `where`,
a date line "ends Oct 31 · 5 days" (0 days = "ends today"; 1 = "1 day"), the
`flavor` mark as Year draws it, and the source label(s) with their `checked`
date. If `end − today ≤ 7` the date line is a chip on the advisory wash
(`--warn-wash` / `--warn`), never a rating colour. `note` is shown in full as
muted text — these notes carry closures and limits and are the point of the row.

**Reported this week.** For each site in `Reports.SITES`, each species report
whose `asOf` is within `Reports.STALE_DAYS` (7) days of `today` (inclusive;
`asOf` of `null` never qualifies). One row per site, species rows inside it
ordered by `Reports.SPECIES`. Site row: river name, `sub`, and per species the
rating badge drawn with the same token and label the map uses
(`Reports.LABEL[r]`, "release only" suffix when `release`), `Reports.describeAge`
for the date, the report sentence `d`, and `src.label` as a link when present.
Only sites with at least one fresh report are listed, ordered by their best
fresh non-release rating (`Reports.RANK`, highest first; a site whose fresh
reports are all release-only sorts after one with a keepable report), then by
name. Each site row links to the map:
`../index.html?mode=reports&river=<id>`.

**New rules.** `Rules.RULES` with `published` within 14 days of `today`,
newest first. Row: the river names joined with ", ", "WDFW · published Oct 16",
the notice sentence `d`, and a link "Read the rule" to `url`. Plain notice
styling; no rating colour, no status word. A line under the caption: "WDFW's
own wording. Checked <Rules.CHECKED>."

**Coming up.** The union of `FY.milestones` (date, label, note) and seasons with
`start > today` (as "opens <start>"), sorted by date, first three. Date line
"Nov 1 · in 6 days". Season rows carry `where`; milestone rows carry `note`.

**Tides.** Placed after Coming up, not before New rules, so closures come first on phones. A 7-day table of NOAA high/low predictions for one station (see
"Tides" below). Caption "Tides · Seattle" with a station picker (a `<select>`,
44 px tall) to its right. One row per day of the Week range, Monday to Sunday, today's row
marked; each extreme as "H 7:12 am · 11.3 ft" / "L 1:40 pm · 2.1 ft" in
tabular numerals; the next extreme after the current time is bold. A muted line
under the table: "NOAA predictions, MLLW, local time. Not observations." While
the request is in flight the rows show "—"; on failure the section shows one
row, "Tide predictions unavailable right now", and a link to the station's NOAA
page. The page never waits on this section.

**Spots.** One row per spot guide. Today that is Three Friends Fishing Hole:
title, "Green River · Kent", link to `../spots/index.html`. The list is a
constant in `week.js` (`Week.SPOTS`) until the spot-guide template sub-project
replaces it with data.

### Footer

The standard guidance footer: the disclaimer sentence and links to WDFW
emergency rules and the WDFW fishing regulations page, plus "Seasons from
Washington Fishing Year, updated <FY.updated>."

### `week.js` contract

```
Week.build(FY, Reports, Rules, today) -> {   // Reports and Rules are the loaded modules (SITES/LABEL/RANK/describeAge; RULES/CHECKED)
  range: { start: 'YYYY-MM-DD', end: 'YYYY-MM-DD' },   // Monday..Sunday containing today
  open:     [{ id, name, where, end, daysLeft, soon:boolean, flavor, note, sources:[{label,url,checked}] }],
  reported: [{ id, name, sub, href, species:[{ name, r, label, release, asOf, age:string, d, src }] }],
  rules:    [{ rivers:[...], published, d, url }],
  upcoming: [{ kind:'season'|'milestone', date, daysUntil, label, detail }],  // max 3
  spots:    Week.SPOTS
}
Week.render(result, doc) -> HTMLElement   // pure DOM builder, no globals
```

Date arithmetic reuses `Reports.ageDays`/`parseDay` semantics (UTC day
numbers, so no DST drift). `build` throws on a malformed date, as `reports.js`
does, rather than rendering a wrong day.

### Tides (`tides.js`)

UMD, loaded by `week/index.html` after `week.js`. The only network call on the
site.

```
Tides.STATIONS   -> [{ id:'9447130', name:'Seattle', lat, lon }, …]   // ~10 stations, see list
Tides.nearest(lat, lon)            -> a station (haversine; pure)
Tides.url(station, range)           -> the CO-OPS predictions URL (pure)
Tides.parse(json, range)           -> [{ date:'YYYY-MM-DD', extremes:[{ t:'HH:MM', type:'H'|'L', v:number }] }]
Tides.load(station, range, fetchFn) -> Promise of parse()'s result; rejects on HTTP error, bad JSON or a NOAA error object
Tides.render(days, now, doc)       -> HTMLElement
```

- Source: `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter` with
  `product=predictions&datum=MLLW&interval=hilo&units=english&time_zone=lst_ldt&format=json`,
  `begin_date`/`end_date` as `YYYYMMDD` for the Week range. Keyless; NOAA sets
  CORS headers. Times are used as NOAA returns them (station local time,
  daylight-adjusted) and never converted, so DST is NOAA's problem, not ours.
- Stations, chosen for where the page's sites are: Seattle 9447130, Tacoma
  9446484, Everett 9447659, Port Townsend 9444900, Friday Harbor 9449880,
  Cherry Point 9449424, Port Angeles 9444090, Neah Bay 9443090, La Push
  9442396, Westport 9441102, Toke Point 9440910. The plan's first tides task
  checks each id and name against NOAA's station list and fixes any that are
  wrong before anything else is built.
- Default station: Seattle. If the map's "You" point is in localStorage (the
  map's `ME_KEY`, same origin), the default is `Tides.nearest` of it. The
  picker's choice is saved under its own key (`wafish.tideStation`) in a
  try/catch, like the map does; a stored id that is not in `STATIONS` is
  ignored.
- One request per station per page load; switching stations fetches again.
  No caching beyond the page.
- Spike first: the plan's first task publishes a one-line probe page to a
  scratch artifact (not the main URL) that fetches one day of Seattle
  predictions and prints the count, to prove the published origin can reach
  NOAA. If it cannot (CSP or CORS), the fallback is a bundled
  `week/tides-data.js` of 14 days for every station, produced by
  `scripts/build_tides.py` and refreshed with the page, and the picker loses
  nothing; the spike's answer is recorded in `STATUS.md` either way.

## 2. Deep links (`links.js`)

Loaded by `index.html` before the inline script. UMD, exports:

```
Links.read(search)  -> { mode, month, species, site, river }   // each null when absent or invalid
Links.write(state, history, location)                          // history.replaceState with the new query
Links.toQuery(state) -> '?mode=…&month=…'                       // pure; omits nulls; keeps `today` when present in state
```

Parameters:

| key     | values                                        | applies in mode      |
|---------|-----------------------------------------------|----------------------|
| mode    | `reports` (default, omitted) · `typical` · `spawning` | all          |
| month   | 1–12                                          | spawning (Typical season has no month control; it always shows the current month) |
| species | exact species name, URL-encoded               | reports, typical, spawning |
| site    | a site id from `typical.js` or `sites.js`     | typical, spawning    |
| river   | a site id from `reports.js`                   | reports              |
| today   | `YYYY-MM-DD` — read only, never written       | all                  |

Rules:

- `read` validates: unknown mode → null; month outside 1–12 → null; ids are
  returned as strings and the map checks them against what it loaded; an unknown
  id is ignored silently (no error UI).
- Apply order on load, after all data scripts ran: mode, then month (spawning
  only) and species, then `site`/`river` (which opens the sheet and centres as
  a tap would). This replaces the two existing `?mode=` regex checks. A `river`
  id that is one of the eight reported waters opens its report sheet; any
  other id is looked up in the tappable rivers (`rivers-tap.js`) and opens that
  river's sheet.
- The map calls `Links.write` from `setMode`, `setMonth`, the species change
  handler, `openSite`, `openRiver`, and when the sheet closes (clearing
  `site`/`river`). Always `replaceState`, never `pushState`, so Back leaves the
  site instead of walking through map taps.
- `write` carries `today` through unchanged if it was in the query; it never
  invents one.
- Keys that do not apply to the current mode are dropped on write (e.g. `river`
  is dropped when switching to typical).

Year links from the Week page go to `../year/index.html` (page top). Checked
2026-10-26: the built Year page has no element ids for seasons and no hash
handling (the `hashchange` string in its bundle is React's internal event
table), so a `#season-id` link would do nothing. A follow-up is filed in
`TASKS.md` to add season-row ids to the Year source and switch these links to
anchors; the Parcel build is not patched outside the repo.

## 3. Navigation

- The `.apptabs` block (already in `index.html` and `spots/index.html`) is the
  single tab bar. It gains a first link, Week, and is copied verbatim into
  `week/`, `year/` and `counts/` so every page shows the same five tabs.
- `aria-current="page"` is set on the page's own tab; hrefs are relative
  (`../index.html`, `../year/index.html`, …) so the artifact serves them without
  a base path.
- A Node check (`Artifacts/salmon-rivers/test/tabs.test.js`, run with the other
  page checks) extracts the tab bar from each of the five HTML files and fails if
  any copy differs from `index.html`'s, ignoring only the `aria-current`
  attribute.
- Five labels at 15 px fit a 320 px track; if any label wraps in the page check,
  the existing `@media (max-width:389px)` rule drops the labels to 14 px.

## 4. Guidance rules

- Rating colours and the words Prime/Good/Fair/Slow appear only where the site
  already produces them: report badges from `reports.js`. Seasons, rules and
  milestones are dates and text. "Ends soon" uses the advisory wash.
- Every dated item shows where it came from (`source.label`, `checked` date, or
  "WDFW · published <date>") and links out when a URL exists.
- Nothing on the Week page is computed from a number into a rating. Counts stay
  on the Counts tab, and tide heights are never turned into a rating or a
  "good time to fish" word.
- Tides are labelled as NOAA predictions, not observations, with the datum.
- No new data file except the tide fallback if the spike fails. The Week page
  otherwise reads only what Year, Map and Rules already publish, so refreshing
  `seasons.json` or `reports.js` refreshes it.
- The disclaimer and WDFW links stay in the footer of every page.

## 5. Testing

Node (`node --test`, alongside the existing 134 page tests):

- `week.test.js`: Open now at boundaries (today = start, = end, day after end,
  day before start); `soon` flips at exactly 7 days; ordering by `end` then name;
  Reported this week includes an `asOf` exactly 7 days old and excludes 8,
  excludes `null`; species order follows `Reports.SPECIES`; rules cutoff at 14
  days; Coming up merges seasons and milestones, sorted, capped at 3; every
  section present and empty when given no data; range is Monday–Sunday across a
  month boundary and a year boundary; malformed date throws.
- `links.test.js`: read/toQuery round-trip for each key; defaults omitted;
  invalid month and unknown mode read as null; `today` preserved by write and
  never added; mode switch drops non-applicable keys.
- `tides.test.js`: `url` builds the documented query for a range; `parse` on a
  saved NOAA fixture groups extremes by day, keeps H/L order within a day,
  reads `v` as a number, and drops days outside the range; a NOAA error object
  (`{"error":{"message":…}}`) rejects `load`; `nearest` picks Seattle for a
  Ballard point and Westport for a Grays Harbor point; the render marks the
  next extreme after `now` and only that one; an unknown stored station id
  falls back to the default.

Page check (Playwright, the pattern of `Artifacts/fishing-year/check.mjs`),
against the local files before publish and the published URL after:

- Five pages load with no console errors in light and dark; the Week page's
  tide table fills (seven rows with at least one extreme each) on the
  published URL, and shows the unavailable row when the request is blocked
  (route intercepted in the check).
- Tab bar: identical across pages (also enforced by `test/tabs.test.js`), 44 px
  targets, contrast ≥ 4.5:1 for labels.
- Week page at 320, 390 and 1024 px: no horizontal scroll, every section
  rendered, "ends soon" chip visible with `?today=` pinned 3 days before a
  season end.
- Deep link `index.html?mode=spawning&month=11&site=<a sites.js id>` opens that
  site's sheet with November selected; `?mode=reports&river=cowlitz` opens the
  Cowlitz sheet; an unknown id loads the map normally.

Then `/design:design-critique` over captures of the five pages (phone and wide,
light and dark). Its top three findings are fixed as the last plan tasks, as in
the 2026-10-14 pass; the rest are filed in `TASKS.md`.

## 6. Delivery

- Branch `week-page-and-deep-links` off `main`; one PR; Daniel merges.
- Source lives in `Artifacts/salmon-rivers/` (`week/`, `week.js`, `links.js`,
  `tides.js`, the edited `index.html` and the four subpage HTML files).
  `artifact.json` stays bound to the main URL.
- Republish by passing the main URL with
  `files={week/index.html, week.js, links.js, tides.js, index.html,
  spots/index.html, year/index.html, counts/index.html}` after reading the live version first (the
  page has been edited outside the repo before, most recently version
  `1792491424-046f`, which is newer than the 2026-10-20 repo snapshot — the plan's
  first coding task is to capture that live version into the repo so the branch
  starts from what is actually published).
- Blocker: attaching the repo from this session was denied by the permission
  classifier on 2026-10-26. Step one of the plan is Daniel allowing the
  `add_repo` call or linking the Mac with `~/developer/wa-fish-map`.
- Afterwards: `pages/fish-pages.md` and `STATUS.md` note the fifth page and the
  deep-link parameters.
