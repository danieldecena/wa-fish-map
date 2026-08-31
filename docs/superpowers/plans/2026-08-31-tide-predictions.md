# Tide Predictions Implementation Plan

> **For agentic workers:** implement task-by-task. Steps use checkbox syntax.

**Goal:** Marine launch and pier sheets show that day's NOAA high/low tides for the nearest bundled station.

**Architecture:** Offline WA station index + one CO-OPS `hilo` fetch per sheet via existing `HTTPGet`. Pure decode/nearest/highlight, tested without the network.

**Tech Stack:** Swift, Swift Testing, NOAA CO-OPS REST, SwiftUI.

## Global Constraints

- Guidance, not a tide book. NOAA link on failure and as the station caption destination.
- No new dependencies. Reuse `HTTPGet`.
- Inland (`isMarine == false`) never fetches.
- Fail open: tides error does not blank the rest of the sheet.
- Rating logic never reads the clock; tides take `planDate` from the view.

---

## Files

| File | Role |
|---|---|
| `WAFishMap/Resources/tide-stations.json` | Bundled station index |
| `WAFishMap/Models/TideStation.swift` | Station, extreme, table, nearest, next-index |
| `WAFishMap/Services/NOAATideLoader.swift` | URL, decode, fetch |
| `WAFishMap/TidePredictionsView.swift` | Sheet section |
| `WAFishMap/SiteDetailSheet.swift` | Insert view; take `planDate` |
| `WAFishMap/FishingMapView.swift` | Pass `planDate` |
| `WAFishMapTests/TidePredictionTests.swift` | Decode, nearest, highlight, catalog, fetch stub |

## Tasks

- [x] 1. Catalog + models + tests (RED then GREEN)
- [x] 2. Loader URL/decode/fetch tests then implementation
- [x] 3. `TidePredictionsView` + wire sheets
- [x] 4. Full suite (73 tests) + signed install on the 16 Pro
