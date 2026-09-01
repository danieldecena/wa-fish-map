# Species-first mode — design

**Date:** 2026-08-31
**Status:** approved
**Feature:** picker recolours the map by one species; the date picker is unchanged.

## What & why

Default rating is the best species in that area this month. An “All species”
menu on the chrome lets you pick one exact name from the guide so every pin,
cluster, heat cell, and marine-area fill uses that species’ rating, or gray
if the area does not list it.

## Decisions

1. **Recolor, do not hide.** Sites without the species stay on the map, gray.
2. **Exact name match.** `Chinook Salmon` is not `Chinook Salmon (ocean)`.
3. **Reuse the date picker.** No 12-month strip.
4. **Nil species is All.** Same max-across-species rating as today.

## Surface

- `AreaFishery.rating(inMonth:species:)`
- `FisheryGuide.speciesNames`
- `FishingMapModel.rating(for:month:species:)`
- `FishingMapView` menu + thread `selectedSpecies` through color, clusters, heat
