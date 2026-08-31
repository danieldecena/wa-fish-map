# WAFishMap

Native MapKit app. Geography overlay + curated seasonal guidance.

## Slice

v1 is Marine Area 13 + Thurston County launches. Edit
`WAFishMap/Models/MapScope.swift`:

- `marineAreaNames` — add `"11"`, `"10"`, `"12"` for Tacoma / Seattle / Hood Canal
- `countyNames` — add `"Pierce"`, `"Mason"`
- then widen `cameraSpanDegrees` or the camera will stay zoomed on Olympia

Do not paste new `where=` strings into the view.

## Seasonal guidance

`WAFishMap/Resources/fisheries.json` holds hand-curated, per-area species and
their best/good months. It drives:

- the red→yellow→orange→green marker/rating (`FishingRating`, computed by month in
  `Fishery.swift` — pure and unit-tested; the *view* injects `Calendar` month, the
  logic never reads the clock)
- the tap-a-launch detail sheet (`SiteDetailSheet.swift`): what's biting now, best
  months, and the "Before you go" alerts block.

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
