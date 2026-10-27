# Map language

The map is the product. These are the rules that keep it readable at a glance,
all of them enforced somewhere in `WAFishMap/Map/` or `FishingMapView.swift`.

## A pin says three things at once

**Colour** is the rating for the picked month and species. **Glyph** is the kind
of spot: a boat for a launch, an angler for a shore site, a fish for a pier.
**Treatment** is the season's legal state.

| State | Balloon | Glyph | Why |
| --- | --- | --- | --- |
| Open, rated | rating colour | white on Prime and Slow, black on Good and Fair | The normal case. Ink is whichever clears 3:1, white first. |
| Season may be closed | rating colour | as above | A small `exclamationmark.circle.fill` badge sits at the balloon's top right. A shape, so colour still does one job. |
| Closed | rating colour at `pin-closed` | as above | Faded, still tappable — the details stay one tap away. |
| No season data | `rating-unrated` | white | A real state, not a failure. |

## Clusters carry the signal, not just the count

A cluster takes the colour of its **best-rated member**, so a dense area still
reads as worth going to instead of collapsing to one flat red. It draws a fixed
step larger than a single pin — `marker-cluster` against `marker-pin` — so a
count never reads as one spot.

A cluster carries the closure badge only when *every* member carrying its
colour does. One unflagged member at that rating is a spot worth going to. The
badge is a subview, not the glyph, because a cluster's glyph is its count.

Marine-area labels ("MA 9") sit outside the site cluster group on purpose — a
label must never merge into a site badge.

## Markers stay smaller than the labels they sit beside

`MKMarkerAnnotationView` at its own size is too big for this map: at regional
zoom the balloons covered the place names a person navigates by, and the screen
read as a map of pins rather than a map with pins on it. Both marker classes
draw scaled down — `marker-pin`, and `marker-cluster` a step above it — as a
transform, since the class exposes no size. Apply it in both `layoutSubviews`
and `prepareForDisplay`; a dequeued view is not always laid out again before
MapKit shows it, and `layoutSubviews` alone leaves reused markers at full size
on screen.

Scaling happens about the view's centre, which walks the balloon's tip off its
coordinate. Translate by half the height change to put it back — the term is
negative when shrinking, positive when growing, so one helper serves both.

## The legend follows what is drawn, not what is toggled

Zoomed out, the heat overlay is forced on. A rating legend over a heat map lies,
so the chrome swaps to `HeatLegend` whenever the overlay is actually drawing.

The heat key uses four discrete swatches, one per band, because that is exactly
what the map draws. A continuous gradient promised a precision the banded fills
do not have.

## Chrome floats

Control bars and the legend sit on a `radius-chrome` card — Liquid Glass on
iOS 26, `ultraThinMaterial` before it — rounded on both size classes so they
float over the map instead of spanning edge to edge. Detail opens as a bottom
sheet on iPhone and a trailing inspector on iPad, never a stretched phone sheet.

**A sheet is a layer over the map, not a window onto it.** At the medium detent
the sheet's default background let the live basemap and the heat wash through,
and body rows were read against green-blue mottling. It takes
`.presentationBackground(.thickMaterial)`: opaque enough to read on, still
clearly floating above the map.

**And the bar is opaque.** Each sheet's first row is a rating badge and a
subtitle, directly under an inline navigation title. With a transparent bar the
title drew straight through that row — "Public fishin*Les Davis Pier*g pier".
`.toolbarBackground(.visible, for: .navigationBar)` gives the content something
to scroll under instead of into.

## The line the map must not cross

Overlays are geography, not the rulebook. Every detail sheet ends with "Before
you go", a WDFW link and *"Not for navigation or safety decisions."* No colour,
badge or ranking in this system is permitted to imply a season is open.
