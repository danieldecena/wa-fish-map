# Tide predictions in site detail — design

**Date:** 2026-08-31
**Status:** approved
**Feature:** a marine launch or pier sheet shows that day's NOAA high/low tides.

## Problem

`SiteDetailSheet` already tells you what is biting and that "incoming tide" is
often the time to go, but it never says *when* the tide turns. `site.coordinate`
is on the model and unused in the sheet. The map already has a plan date.

## Constraint

Same product boundary as everything else: this is guidance, not a tide book.
Predictions come from NOAA CO-OPS. We do not scrape, do not claim a station sits
on the ramp, and we fail open so a NOAA outage never blanks the rest of the sheet.

## Decisions

1. **Day's high/low table**, not live stage. Follows the map date. If that date
   is today, highlight the next extreme after the map time.
2. **Nearest bundled station**, not a runtime 3,500-station catalog (NOAA's
   `state=WA` filter is ignored and returns the full US list) and not a
   one-station-per-marine-area map (wrong at the edges).
3. **Marine only.** `isMarine == false` skips the section. Lakes have no CO-OPS
   tide station.
4. **One live call per sheet.** High/low for one day (`product=predictions`,
   `interval=hilo`). Station identity is offline.

## Architecture

### Data

`WAFishMap/Resources/tide-stations.json` — id, name, lat, lng for Washington
tide-prediction stations plus Columbia-mouth Oregon (Area 1). Extracted from
NOAA MDAPI `type=tidepredictions`. Bump `updated` when refreshed.

CO-OPS request:

```
datagetter?begin_date=yyyyMMdd&end_date=yyyyMMdd
  &station=<id>&product=predictions&datum=MLLW
  &time_zone=lst_ldt&interval=hilo&units=english
  &format=json&application=WAFishMap
```

Heights in feet, times in Pacific civil time. NOAA may return HTTP 200 with
`{"error":{"message":"..."}}` — treat that as failure.

### Model

- `TideStation` — id, name, `LonLat`. `nearest(to:in:)` by `CLLocation` distance.
- `TideExtreme` — time, heightFeet, high/low.
- `TideTable` — station + extremes. `indexOfNext(after:)` for highlight.
- `NOAATideLoader` — bundle stations, build URL, decode, fetch via existing
  `HTTPGet`. No new dependencies.

### UI

`TidePredictionsView` on marine `SiteDetailSheet` and `PierDetailSheet`, between
amenities and "What's biting". Caption is the station name. Rows: High/Low,
time, height. Quiet failure line + NOAA station link. Sheets take `planDate`
instead of only `month`.

### Tests

Decode a fixture, nearest-station pick, next-extreme highlight with an injected
calendar. Load the shipped catalog. No live NOAA in CI.
