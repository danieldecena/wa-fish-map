# Lake facts on the launch sheet

Date: 2026-09-16. Status: approved design, not implemented.

## Goal

When a launch sits on a lake WDFW catalogues, show that lake's official facts on
the launch detail sheet: acres, elevation, boat ramp, shoreline access,
management type, and the species WDFW lists for it. No new map pins.

## Source (verified 2026-09-16)

`https://geodataservices.wdfw.wa.gov/arcgis/rest/services/ApplicationServices/FishWA_2014_AllLakes_PROD/MapServer`

- Layer 2 "Lowland Lakes": 653 **points** (not polygons). Fields `LakeName,
  CountyName, ELEV, SurfaceAcres, PublicManagementType, ShorelineAccess,
  BoatRampAvailable, WebsiteURL`. 2 rows have null acres. `WebsiteURL` is
  empty on the rows sampled.
- Layers 4-18: one per species (Rainbow Trout 510 lakes ... Bluegill), same
  attribute shape, point geometry.
- The service is named 2014. Treat it as a static snapshot and say so on screen.

## Data: `scripts/build_lakes.py` -> `WAFishMap/Resources/lakes.json`

Follows `build_rivers.py`: stdlib only, deterministic output (lakes sorted by
name then coordinate, coordinates rounded), byte-identical on unchanged upstream.

- Species join by **exact point geometry** (after rounding), not name + county:
  name + county repeats for 4 pairs (Phillips Lake/Stevens, Blue Lake/Okanogan,
  Echo Lake/Snohomish, Trout Lake/King).
- Species rows with null `LakeName` (3 seen: layers 4, 8, 10) are skipped and
  counted in the script's output. Any other unjoined species row fails the build.
- Expected-count guard before writing (lakes >= 600, every species layer
  non-empty), same reason `EXPECTED_RIVERS` exists: a silently thin output looks
  healthy.
- Per lake: `name, county, lon, lat, acres?, elevationFt?, management?,
  shorelineAccess?, boatRamp?, websiteURL?, species[]`. Empty strings become
  absent.

## Matching: `WAFishMap/Models/Lake.swift`

Pure, no clock or network. `Lake.match(site:in:)` returns one `Lake` or nil.

1. **Distance.** Radius from acreage as a circle, `r = sqrt(acres * 4046.86 / pi)`.
   A lake qualifies if the launch is within `1.5 * r + 400 m` of its point.
   Lakes with null acres never qualify.
2. **Ambiguity.** More than one qualifying lake -> nil.
3. **Name check.** If the launch name contains `Lake`, `Lakes`, `Pond`, `Ponds`
   or `Reservoir`, its name must agree with the lake's, else nil. Agreement:
   lowercase, `'s` and `’s` dropped, `saint` -> `st`, trailing `s` trimmed on
   tokens over 3 chars, then drop the words `lake lakes pond ponds reservoir the
   upper lower north south east west of`. Names agree if any token pair is equal
   or (both >= 3 chars) within one edit. If either side has no tokens left, compare
   the full normalized names instead (`North Lake` vs `North Lake`).
4. Launches already inside a marine area are not matched.

A miss shows nothing and is always safe. A wrong match puts another lake's facts
on the sheet, which breaks the scope promise in `CLAUDE.md`.

Live probe against WDFW layer 0 (477 launches) with steps 1-3: 205 matches kept,
19 ambiguous, 3 dropped by the name check (Lyle Lake -> Herman Lake, Corral Lake ->
Potholes Reservoir, and North Lake -> North Lake before the empty-token fallback).

Known limitation: the name check passes `Silver Lake -> North Silver Lake`
(792 m). Whether that launch is on North Silver Lake is unverified; flag it in
STATUS rather than special-case it.

## Model wiring

`FishingMapModel` loads `lakes.json` once, the same way it loads `rivers.json`,
and computes each launch's lake alongside the existing area index
(`indexSitesToAreas`). No new async loader.

## Sheet: `SiteDetailSheet.swift`

New `LakeFactsSection`, shown only when a lake matched, after the facility
section:

- Title "Lake facts (WDFW)" and the lake name.
- Acres, elevation, boat ramp, shoreline access, management type; omit absent rows.
- "WDFW lists: ..." species, in WDFW layer order.
- `websiteURL` link when present.
- Footnote: "From WDFW's lowland lakes map (2014). Species listed are not a
  stocking or season guarantee."

Species here come from WDFW per lake, so they are true of the whole lake and do
not go through `fisheries.json` or `NoteScopeTests`.

## Tests: `WAFishMapTests/LakeTests.swift`

- Decodes bundled `lakes.json`; count >= 600; Lake Dolloff present with species.
- Matching on real pairs from the probe: Lake Dolloff launch -> Lake Dolloff;
  Steel Lake -> Steele Lake; Lyle Lake -> nil; Corral Lake -> nil;
  North Lake -> North Lake.
- Synthetic: two overlapping qualifying lakes -> nil; null acres -> nil;
  a launch far from any lake -> nil.
- Name check unit cases: Tim Ponds/Tims Ponds, Lake Saint Clair/St. Clair Lake,
  Devils Lake/Lost (Devil’s) Lake agree; Lyle/Herman do not.
- Each matching test is first run against a deliberately wrong expectation and
  seen to fail, per the runbook rule that an assertion must be watched going red.

## Out of scope

Lake pins on the map, lake outlines, replacing `waterbodySites`, fish-plant data
(separate task), live fetching.
