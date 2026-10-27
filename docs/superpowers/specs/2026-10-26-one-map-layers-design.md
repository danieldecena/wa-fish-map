# Washington Fishing Map: one map, with Week, Year, Spots and Counts as layers

Design spec, 2026-10-26. Scope is the published web page at
https://claude.ai/artifact/9oA145toRsmFcDYurdJbey only. The iOS app is untouched.

## Why

The site is five pages behind one tab bar (Week | Map | Year | Spots | Counts).
Daniel wants one page: the Map, with what the other four pages show drawn on it as
map data. The map stays the main view: the page opens on it, full screen, exactly as
today, with every layer off. The tab bar goes; the map's own controls stay.

## What ships

1. The page tab bar is removed from the map. The toolbar becomes:
   `[logo] Reports v | All species v | Near me | <notice> | Rivers | Layers v`.
2. A **Layers** menu with three switches: **Seasons**, **Spot guides**,
   **Creel counts**. Each draws on top of whichever mode (Reports, Typical,
   Spawning) is showing.
3. `season-places.js`: a hand-maintained table tying each season in
   `year/data.js` to places on the map.
4. The `week/`, `year/`, `spots/` and `counts/` page folders are deleted. Their
   data files move next to `index.html` (`year/data.js` becomes `seasons-data.js`,
   `week/tides-data.js` becomes `tides-data.js`, `counts/data.js` is dropped, see
   section 4). Git history keeps the pages.
5. The one-bar layout (commit ed2ecb4) is removed: it existed only to fit the page
   tabs into the map bar.
6. Tests and the page check updated for one page.

Not in scope: new data sources, new spot guides, any change to ratings, colours or
`fisheries.json`.

## 1. Seasons layer (replaces Week and Year)

Week and Year both read `year/data.js` (15 dated seasons). One layer covers both,
so they are not two switches.

- **Month slider.** When Seasons is on, a month slider sits at the bottom of the
  map, defaulting to the current month (`?today` respected). Spawning mode already
  has a month control; when Spawning is the mode, the layer uses that control
  instead of adding a second one.
- **Drawing.** Every place of a season open in the chosen month gets an outline
  (rivers: a halo along the river line; areas and points: a ring). Outlines use one
  neutral token, never a rating colour, so they can sit over Reports colours without
  reading as a rating. Fill is never used.
- **Ends soon.** In the current month, a season ending within 7 days gets an
  "ends soon" tag at its first place, the same chip Week uses today. A season
  opening within 14 days gets an "opens <date>" tag.
- **Sheet.** Tapping an outline or tag opens a Season sheet: name, dates, where (the
  `where` text verbatim), the note, the WDFW source link and its checked date, and
  the "Guidance, not regulation" line. Several seasons on one place list in one
  sheet, ending soonest first.
- **Deep link.** `?layers=seasons&month=N`. `year/index.html#<id>` links become
  `?layers=seasons&season=<id>`, which opens that season's sheet.

### season-places.js

`window.SEASON_PLACES = { "<season id>": [ place, ... ] }`, where a place is one of:

- `{ river: "<id>" }`: an id in `rivers-tap.js` or a `reports.js` site id.
- `{ site: "<id>" }`: a `typical.js` site (beaches, launches, lakes).
- `{ point: [lon, lat], label: "..." }`: for places with no geometry, such as
  "Westport charter".

Each entry carries `evidence`: the `where` phrase it was mapped from. Vague `where`
text ("south Sound rivers not checked", "some Puget Sound rivers") maps only the
places it names; the unnamed rest stays in the sheet text, never guessed onto the
map. Hand-maintained, like `rules.js`; it is not generated.

## 2. Spot guides layer (replaces Spots)

- Three Friends Fishing Hole becomes a pin at its access point on the Green River
  in Kent, near the S 212th St line. The Spots page carries no coordinates, so the
  point is looked up and recorded with its source in `docs/research/` before it lands.
- The pin uses a distinct guide glyph, not a rating colour.
- Its sheet carries the Spots page content: the Chinook closure banner, "When the
  fish are in" table, "Best times to go", "Rules for the lower Green", updated date.
- Data moves out of `spots/index.html` markup into `spots.js`
  (`window.SPOTS = [ { id, name, lat, lon, updated, closure, timing, tips, rules } ]`)
  so a second guide is one more entry.
- Deep link `?layers=spots&spot=<id>`.

## 3. Creel counts layer (replaces Counts)

- Each river in `counts.js` (newest week, already shown on Reports sheets) gets a
  small count badge beside its label: fish kept that week ("124 kept"), summed
  from the "All sections combined" rows when the river has them, else from every row;
  "0 kept" when the survey found no catch.
- Badges are text on the neutral glass style, never coloured by the number.
- Tapping a badge opens the river's existing sheet scrolled to its counts section.
- Deep link `?layers=counts`.

## 4. What is lost, on purpose

- **The multi-year creel table** (`counts/data.js`, 6,000+ rows back to 2019) has no
  place on a map; it is dropped. The newest week stays via `counts.js`.
- **The 7-day tide table for any of 26 stations** on Week is dropped; marine site
  sheets keep "Tides today" from the same bundle.
- **Week's "catch reports from the last 7 days" list** is already the Reports mode
  with its freshness rule; nothing new is drawn for it.
- **Week's "WDFW rules from the last 14 days"** are already the notice button
  (`rules.js`); nothing new is drawn for them.

## 5. Old links

The publisher serves the old paths only if files exist there, so each deleted
folder keeps a one-line `index.html` that redirects:
`week/` to `../?layers=seasons`, `year/` to `../?layers=seasons` (hash becomes
`season=`), `spots/` to `../?layers=spots&spot=three-friends`, `counts/` to
`../?layers=counts`. These are the only files left in those folders.
The project CLAUDE.md table rows for `fishing-year/` and
`three-friends-fishing-hole/` are updated to say their content now lives in the
map's Seasons and Spot guides layers.

## 6. Layers and modes together

- Layers are independent switches, off by default, remembered in the URL
  (`layers=` is a comma list), not in storage.
- Layers never change pin colours, the legend's rating rows or the ranking. The
  legend gains one line per active layer explaining its mark.
- On phones the Layers menu is a popover like the mode menu; the month slider
  sits above the legend and the legend collapses while the slider is shown.

## 7. Testing

- Retire `test/tabs.test.js` and `test/onebar.test.js`.
- `test/season-places.test.js`: every season id in `seasons-data.js` has an entry;
  every river, site id exists; every point is inside the state box; every entry has
  evidence.
- `test/layers.test.js`: open-in-month logic (season crossing a month boundary,
  year end), ends-soon and opens-soon windows, `layers=` read and write in
  `links.js`, no rating token used by any layer mark.
- `test/spots.test.js`: `spots.js` shape, the pin inside the state box, the
  content matches what `spots/index.html` showed (fixture copied before deletion).
- `check-week.mjs` becomes a one-page check: each layer on and off at 320, 390 and
  1024 in light and dark, no horizontal scroll, the redirects land on the right
  state, no request leaves the page.
- Existing honesty tests ("not season dates", WDFW link on every sheet) extend to
  the Season and Spot sheets.

## Order

1. Remove the tab bar and one-bar layout; Layers menu with nothing in it.
2. Spot guides layer (smallest, proves the layer pattern).
3. Creel counts layer.
4. `season-places.js`, then the Seasons layer and month slider.
5. Delete the four page folders, add redirects, update README and the page check.
6. Publish to the same URL and record the version in `artifact.json`.
