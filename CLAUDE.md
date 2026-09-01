# WAFishMap

Native MapKit app. Geography overlay + curated seasonal guidance.

## Scope

**Statewide, live.** `WAFishMap/Models/MapScope.swift` queries WDFW for *all* marine
areas (`where=1=1`, layer 6) and *all* launches (`where=Launch=1`, layer 0) — no
county/area filter. The camera opens auto-fit (`position = .automatic`), then eases once to a regional
span around the user's first location fix — but only if that fix is inside the
Washington bounding box and the user has not already moved the camera. A fix
elsewhere keeps the statewide framing, since the data is Washington-only.
`cameraCenter` is only a pre-load fallback. Do not paste `where=` strings into
the view.

Launches carry no marine-area code, so each is matched to its area by point-in-polygon
(`MarineArea.contains(_:)`, indexed in `FishingMapModel.indexSitesToAreas`). Inland/lake
launches match no area → **neutral (gray) rating**, by design.

## Seasonal guidance

`WAFishMap/Resources/fisheries.json` holds hand-curated, per-area species and
their best/good months. It drives:

- the blue→amber→orange→red marker/rating (`FishingRating`, computed by month in
  `Fishery.swift` — pure and unit-tested; the *view* injects `Calendar` month, the
  logic never reads the clock)
- the tap-a-launch detail sheet (`SiteDetailSheet.swift`): NOAA high/low tides
  for the nearest station, what's biting now, best months, and the "Before you go"
  alerts block.

Editing rules:

- It is **guidance, not regulation.** Every screen that shows it carries the
  disclaimer and a WDFW deep link (`wdfwURL`). Keep both.
- Bump `updated` when you change the data.
- v1 seed is a first pass from general South-Sound knowledge — **treat species/month
  facts as unverified until checked against WDFW.**

## Not this app

Fish Washington is still the rulebook; this app defers to it. No scrape, no
**live** bag limits, no season/closure dates presented as authoritative, no public
catch heatmap. The rating is editorial seasonal *timing*, not a claim that a
fishery is open — always route the user to WDFW to confirm.

## Notes are scoped, and the scope is a promise

`fisheries.json` carries notes at three tiers, and a note is shown at every
site in its tier:

- `areas[]` — one WDFW marine area. Naming a place here is correct; area 10's
  "Elliott Bay / Central Sound spring selective fishery" is true of area 10.
- `freshwater.byCounty` — a whole county. King County holds Lake Washington,
  Lake Sammamish, Lake Dolloff and the Green River, so a note naming one of
  them is wrong at the other three.
- `freshwater.species` — the entire state.

`WAFishMapTests/NoteScopeTests.swift` fails the build when a county or
statewide note names a waterbody. It shipped catching a real defect: Lake
Dolloff's Yellow Perch card read "Lake Washington; huge population" because
the note sat on the King County override. The regex is prose matching —
"Potholes"-style names without a Lake/River noun slip it, so the rule binds
the editor, not just the test.

If a claim is only true of one lake, it does not belong in this file at all
until the data model has a waterbody tier.
