# Washington Fishing Year

A published page: calendar, river map and migration timing for the Seattle-area
fishing year, October 2026 to November 2027. It is not part of the iOS app, and
the app never reads its data. Dated seasons and rules here are artifact-only
guidance sourced from WDFW notices; the app shows month ratings from
`fisheries.json` and nothing else.

Live: the URL in `artifact.json` (with the current and previous version ids).

## Files

| File | What it is |
| --- | --- |
| `seasons.json` | **The only place to edit.** `updated`, `about`, `seasons` (15, each with a `source`), `milestones`, `migration` and `rivers` (5, with lines and access stops). |
| `data.js` | Generated from `seasons.json` by `scripts/build_fishing_year.py`. Do not hand-edit. |
| `index.html` | The built page. Holds no data. |
| `check.mjs` | Browser check at 400 px and 720 px, light and dark, every tab and river: type scale, 4.5:1 contrast, no sideways scroll, 44 px targets, no console errors. `--selftest` proves the detectors fire. |

## Change something

```zsh
# 1. edit seasons.json
/opt/homebrew/bin/python3 scripts/build_fishing_year.py --check   # validate only
/opt/homebrew/bin/python3 scripts/build_fishing_year.py           # write data.js and salmon-rivers/seasons-data.js
cd Artifacts/fishing-year && node check.mjs                       # needs playwright-core + Chrome
```

The build stops on bad data: an unknown `site_id`, a stop with both a `site_id`
and coordinates, a manual stop without a `place_check` against OpenStreetMap, a
river line more than 1.5 km off `rivers.json`, a season ending before it
starts, or a missing value. Its report also lists stops still marked
unconfirmed (as of 2026-10-26: Two Rivers Point, which OpenStreetMap does not name). A confirmed place records the OSM name, or the OSM id (`osm`, for example `node/9727835924`) when the feature is unnamed.

## Publish

1. Read the live artifact first. On 2026-10-18 the Skagit emergency rule
   (WSR 26-21-045) and the Snohomish closure were published straight to the
   page and had to be copied back into `seasons.json`.
2. Publish `index.html` with `files={data.js}`, **passing the URL from
   `artifact.json`**. Leaving it out mints a second artifact.
3. Record the new version id in `artifact.json`.

## Rules that bind this page

- Guidance, not regulation: every season carries its WDFW source and as-of date,
  and the page routes people to WDFW to confirm.
- Pink salmon has no source yet: WDFW sets odd-year (2027) pink seasons around
  April 2027. Until then the page says why, rather than guessing.
