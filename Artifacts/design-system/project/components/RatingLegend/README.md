The map's colour key: one dot and one word per rating, in a single row.

Hand-written from `WAFishMap/FishingMapView.swift` (`private struct RatingLegend`).

Ordered hot to cold — Prime, Good, Fair, Slow, No data — because a reader scans
for the best spots first. Dots are 8px circles at `space-3` from their label;
entries sit `space-10` apart. Labels use the `legend` type role in
`text-secondary`.

**Consumer supplies:** nothing. It is a fixed key.

The whole row is one accessibility element with a spoken label that also
explains the two pin treatments colour cannot convey: *"A pin with a small
warning badge means the season may be closed, verify with WDFW; a faded pin is
closed."*

Shown only while the heat overlay is off — see `HeatLegend`.
