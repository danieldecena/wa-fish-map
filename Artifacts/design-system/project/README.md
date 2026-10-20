# WA Fish Map

The design system of a native iOS map of Washington's fishing water — every WDFW
marine area, the statewide water-access launches and the public piers, each pin
coloured by what is biting there this month.

It is small on purpose. The app is read outdoors, at arm's length, often in rain,
by someone deciding whether a drive is worth it. Everything below serves one
sentence: **a colour tells you how good the spot is right now, and every other
element gets out of its way.**

## Two rules the code holds itself to

**1. A view names a role, never a raw value.** `DS.Rating.prime`, not
`Color(red: 0.94, …)`; `DS.TypeScale.legend`, not `.caption2`. When a decision
changes it changes in `DesignSystem.swift`, once, instead of being hunted across
three view files.

**2. Defer to the platform wherever the platform is already right.** Apple
defines a complete light *and* dark value for every system colour, and they
follow the appearance for free. A hardcoded RGB cannot. That is why so few
tokens here are literals — a token that forwards to a system colour is not
indirection for its own sake, it names *why* this app uses that colour.

## Colour

### The rating ramp

Four stops, cold to hot: `rating-slow` → `rating-fair` → `rating-good` →
`rating-prime`, plus `rating-unrated` for a spot with no curated season data.

The stops are stated explicitly rather than sampled off a continuous blue-to-red
line: sampling runs the midtones through magenta, which reads as some other
scale rather than as heat.

Use the ramp for one thing only — how good a spot or species is in the picked
month. A pin, a legend dot, a `RatingBadge`. Never for status, emphasis or
decoration; the moment a second meaning borrows a ramp colour, the map's only
signal gets noisy.

`rating-unrated` is a normal state, not a failure. Inland launches match no
marine area by design.

### The overlay hue

`overlay-density` is the one genuinely custom colour in the system, and it is
violet for a reason the ramp created: blue, amber, orange and red are spoken
for, so the heat overlay takes the hue the ramp gave up and cannot be misread as
a rating.

It ships as one hue at four opacities (`density-band-0` … `density-band-3`),
and it only works because the basemap is muted while the overlay is on. A
translucent fill takes its apparent colour from whatever is under it: over the
normal basemap one band read pink over city, brown over forest and violet over
water — the same band looking like three, and different bands looking alike.
The muting and the hue are a pair. Do not ship one without the other.

### Surfaces and text

`surface-advisory` and `surface-species-row` are neutral system fills. The
advisory block used to be a flat yellow wash, which collided head-on with
`rating-fair` — both appear on the same sheet, so a reader had no way to tell a
caution from a rating. The shield glyph and the heading carry the caution now.

`text-primary` / `text-secondary` / `text-tertiary` map to `label`,
`secondaryLabel` and `tertiaryLabel`. Tertiary is for stamps and attribution
only.

## Type

SF Pro, at the platform's own Dynamic Type steps — no font files ship with the
app and none are needed. Every call site names a role from `DS.TypeScale`, and
each role is bound to the step the app draws today, so adopting a role is a
rename with no visual change. That is the point: moving a role up the ramp later
is one edit rather than twenty.

Worth knowing before that edit: of 48 type calls in the app, 31 sit on the two
smallest steps, and `body` — the step the whole ramp is built around — is never
used. `control` and `legend` are the roles most likely to want promoting; they
label things a person reads outdoors, at arm's length, in the wind.

## Space and shape

One radius per surface, and they descend with the surface's importance:
`radius-chrome` (14) for floating map chrome, `radius-advisory` (12) for the
"Before you go" block, `radius-species-row` (10) for a card inside a sheet.
Capsules (`radius-pill`) are reserved for the rating badge and the "MA n" map
label.

Spacing is not a formal scale in the code — it is the set of values the views
actually use. `space-10` carries most of the layout; `space-18` separates the
major blocks of a detail sheet.

## Iconography

The app icon is a white fish — body and tail as two flat shapes — knocked out of
a vertical gradient from `brand-icon-start` (shallow teal) to `brand-icon-end`
(deep blue). Nothing else in the product uses that gradient; it belongs to the
icon.

Inside the app, glyphs are SF Symbols, chosen so a pin says what kind of spot it
is before you tap it: `sailboat.fill` for a launch, `figure.fishing` for a
shore-only site, `fish.fill` for a pier.

Species get hand-drawn silhouettes (`FishSilhouette.swift`) — body plans, not
species. Every finfish in the guide draws as one of ten forms so a salmon and a
halibut read differently at a glance. Recognisable outline, never a field-guide
illustration.

## Accessibility

- Every pin and cluster is one accessibility element with a spoken summary:
  `"13 fishing spots, best rated Prime, season may be closed, verify with WDFW"`.
- Colour is never the only carrier. A rating always ships with its word — Prime,
  Good, Fair, Slow, No data — in the badge and in the legend.
- A closure-plausible spot is *outlined*, not merely recoloured: the balloon
  goes pale and the rating colour moves to the glyph, so the state survives for
  a colour-blind reader.
- `rating-fair` (#ffc700) on white is about 1.7:1 — it is a fill and a dot
  colour, never text on the page ground. `RatingBadge` draws the label in the
  rating colour on a 20% wash of itself, which does not reach 4.5:1 for Fair; it
  is carried from the source unchanged and is the one contrast pair to fix
  first.
- `text-tertiary` at 11px is below 4.5:1 in both themes. It is confined to
  timestamps and attribution.

## Known divergences in the source

Three of these are live in `main@b9cdd9b` and worth resolving before anything
new is built on the ramp:

1. **Two rating ramps exist.** `DS.Rating` in `DesignSystem.swift` anchors on
   Apple's system colours and gains dark-appearance variants; the views still
   draw the literals in `ColorRamp.swift` via `FishingRating.color`. Both are
   in `tokens.json` — `rating-*` is what renders, `rating-*-system` is what the
   design intends. The migration is a find-and-replace, not a redesign.
2. **A third palette is specified for the web demo** in `docs/web-demo-spec.md`:
   prime `#E4572E`, good `#EE8C2B`, fair `#EFC050`, slow `#3D8BCD`, none
   `#9AA8A7`. Warmer and lower-chroma than either app ramp. Not built yet, and
   not carried into these tokens; if the demo ships with it, the app and the
   demo will disagree on the product's most important signal.
3. **`GuidanceFooter` still draws `.yellow.opacity(0.12)`** rather than
   `DS.Surface.advisory`, so the yellow/Fair collision the token was created to
   remove is still on screen.

## Not synced

- **Fonts:** none. The app uses the platform face; there is nothing to copy.
- **Components:** the library is SwiftUI, so nothing was built or bundled. Each
  component below is a *static rendition* — hand-written HTML and CSS bound to
  these tokens, from the Swift source named in its README — for reading and for
  checking colour and spacing, not for import.
- **Assets not carried:** the Xcode `AccentColor` colourset is empty in the
  repo (it declares no colour), and the map's basemap muting is a MapKit
  configuration rather than a token.
