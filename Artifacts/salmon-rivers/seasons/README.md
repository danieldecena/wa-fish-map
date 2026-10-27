# Seasons (the map's Seasons layer)

The dated seasons, key dates, migration months and river guides behind the
Washington Fishing Map's Seasons layer, October 2026 to November 2027. They
began as the Washington Fishing Year page, retired on 2026-10-26 and kept as
published in `Artifacts/archive/fishing-year-page/`. The app never reads this
data. Dated seasons and rules are artifact-only guidance sourced from WDFW
notices; the app shows month ratings from `fisheries.json` and nothing else.

## Files

| File | What it is |
| --- | --- |
| `seasons.json` | **The only place to edit.** `updated`, `about`, `seasons` (15, each with a `source`), `milestones`, `migration` and `rivers` (5, with lines and access stops). |
| `published-in.json` | History of the retired Washington Fishing Year page: its last version ids and the deleted standalone artifact. Not a binding; the main map's `../artifact.json` owns the url. |

The generated file is `../seasons-data.js`; `../season-places.js` says where each
season goes on the map.

## Change something

Run from the repo root:

```zsh
# 1. edit seasons.json
/opt/homebrew/bin/python3 scripts/build_fishing_year.py --check   # validate only
/opt/homebrew/bin/python3 scripts/build_fishing_year.py           # write ../seasons-data.js
node --test "Artifacts/salmon-rivers/test/*.test.js"              # season-places.test.js checks the rebuild
```

A new season also needs an entry in `../season-places.js`. Then refresh the main
map from its own binding (`../artifact.json`) with `seasons-data.js` in `files`.

The build stops on bad data: an unknown `site_id`, a stop with both a `site_id`
and coordinates, a manual stop without a `place_check` against OpenStreetMap, a
river line more than 1.5 km off `rivers.json`, a season ending before it
starts, or a missing value. Its report also lists stops still marked
unconfirmed (none as of 2026-10-26). A confirmed place records the OSM name, or the OSM id (`osm`, for example `node/9727835924`) when the feature is unnamed. When OpenStreetMap lacks the place, a government plan that names and maps it can confirm it instead: `plan` with its `label` and https `url` (Two Rivers Point, from Sumner's 2024 parks plan, 2026-10-26).

Read the live map before publishing. On 2026-10-18 the Skagit emergency rule
(WSR 26-21-045) and the Snohomish closure were published straight to the page
and had to be copied back into `seasons.json`.

## Rules that bind this data

- Guidance, not regulation: every season carries its WDFW source and as-of date,
  and the map routes people to WDFW to confirm.
- Pink salmon has no source yet: WDFW sets odd-year (2027) pink seasons around
  April 2027. Until then the map says why, rather than guessing.
