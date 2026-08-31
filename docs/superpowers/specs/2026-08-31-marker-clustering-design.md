# Marker clustering at low zoom — design

**Date:** 2026-08-31
**Status:** approved
**Feature:** 477 pins become numbered clusters when zoomed out; heat stays a toggle.

## Problem

Statewide, every access site and pier is its own annotation. At the 150 km
cutoff they already collapse to 11 pt dots, but hundreds still overlap. The
heat overlay answers "where is it good" as a wash; it does not let you pick a
place.

## Decisions

1. **Keep heat.** Clusters replace overlapping pins, not the overlay.
2. **Same grid as heat.** `heatCellDegrees(cameraDistance)` so a cluster sits
   on the cell the wash is already using.
3. **Tap zooms** the camera into that cell. No cluster-member list.
4. **Color by best rating** in the cell. Count is the number. Matches the
   thermal legend.
5. **No MKMapView.** Reuse `HeatMap.GridKey`. SwiftUI `Map` stays.

## Behaviour

- Camera distance > 150 km: bucket sites + piers. Count 1 → existing
  `RatingDot` with the site/pier tag. Count 2+ → numbered `ClusterMark`; tap
  sets `position` to a region ~2.5× the cell.
- Camera distance ≤ 150 km: individual `Marker`s, unchanged.
- Inland and marine share the same buckets.
