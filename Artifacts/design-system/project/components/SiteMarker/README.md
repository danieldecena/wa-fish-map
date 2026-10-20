The map pin, and the cluster badge that stands in for a group of them.

Hand-written from `WAFishMap/Map/AnnotationViews.swift` (`SiteMarkerView`,
`SiteClusterView`, `AreaLabelView`).

A pin carries three signals at once: the balloon's colour is the rating, the
glyph is the kind of spot (`sailboat.fill` launch, `figure.fishing` shore,
`fish.fill` pier), and the treatment is the season's legal state — solid when
open, pale with the colour moved to the glyph when a closure is plausible,
faded to `pin-closed` when closed but still tappable.

A cluster takes the colour of its best-rated member and draws a fixed step
larger than a single pin. It is outlined only when every member carrying its
colour is outlined.

**Size.** Both draw scaled down from `MKMarkerAnnotationView`'s own size —
`marker-pin` (0.8) and `marker-cluster` (0.95) — because at full size the
balloons covered the place labels they are meant to sit beside, and a regional
view read as a map of pins rather than a map with pins on it. The class has no
size property, so the scale is a transform applied at both `layoutSubviews` and
`prepareForDisplay`: a dequeued view is not always laid out again before MapKit
shows it. Scaling is about the centre, so each is translated by half the height
change to keep the balloon's tip on its coordinate.

**Glyphs.** `sailboat.fill`, `figure.fishing` and `fish.fill`, set as
`glyphImage`. Worth knowing: `anchor.fill` — the glyph the original SwiftUI
`Marker` used — is not a real SF Symbol. It resolves to nil and MapKit silently
falls back to a default pin, which is how a wrong glyph ships without an error.
The preview draws stand-ins; the symbol names are the contract.

**Consumer supplies:** the site's rating, kind, and closure state; for a
cluster, its members.

Marine-area labels ("MA 9") are a separate annotation on a material pill,
deliberately outside the cluster group — a label must never merge into a site
badge.
