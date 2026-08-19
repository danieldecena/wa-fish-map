# WAFishMap

Native MapKit app. Geography overlay only.

## Slice

v1 is Marine Area 13 + Thurston County launches. Edit
`WAFishMap/Models/MapScope.swift`:

- `marineAreaNames` — add `"11"`, `"10"`, `"12"` for Tacoma / Seattle / Hood Canal
- `countyNames` — add `"Pierce"`, `"Mason"`
- then widen `cameraSpanDegrees` or the camera will stay zoomed on Olympia

Do not paste new `where=` strings into the view.

## Not this app

Fish Washington is the rulebook. This overlay is not. No scrape, no live
bag limits, no public catch heatmap.
