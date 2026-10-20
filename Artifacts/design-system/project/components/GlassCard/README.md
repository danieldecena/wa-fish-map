The floating card that every piece of map chrome sits on.

Hand-written from `WAFishMap/FishingMapView.swift` (`private struct GlassCard`).

Liquid Glass (`glassEffect(.regular, in: .rect(cornerRadius: 14))`) on iOS 26,
`ultraThinMaterial` on a `radius-chrome` rounded rectangle before it. Rounded on
both size classes on purpose, so the bars float over the map instead of spanning
edge to edge on iPhone.

Content is padded `space-10` vertically and the platform's horizontal inset, and
the card itself is inset `space-12` on regular width, `space-8` on compact. On
regular width it is capped at 460px so it does not stretch across an iPad.

**Consumer supplies:** the chrome content — controls, a legend, a status line.

A translucent card over a live map is the reason the basemap is muted while the
heat overlay is on; see the overlay note in the brand book.
