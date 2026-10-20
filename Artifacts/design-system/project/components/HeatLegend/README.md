The cold-to-hot key shown while the density overlay is drawing.

Hand-written from `WAFishMap/FishingMapView.swift` (`private struct HeatLegend`).

Four discrete 20×8 swatches — one per band of `overlay-density` at
`density-band-0` … `density-band-3` — clipped to `radius-swatch`, with "Fewer"
and "More" either side and the qualifier *"· density of well-rated spots"* in
`text-tertiary`.

Discrete, not a gradient: a continuous ramp promises a precision the banded
fills do not have, and the first band draws nothing at all so the basemap stays
clean where there is nothing to say.

**Consumer supplies:** nothing.

This legend replaces `RatingLegend` whenever the overlay is actually drawn —
including zoomed out, where the overlay is forced on. A rating legend over a
heat map lies.
