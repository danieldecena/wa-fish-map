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

Each stop is an Apple system colour (`Color.blue`, `.yellow`, `.orange`,
`.red`, `.gray`), so the ramp has a dark-appearance value for free. The hex
values in `tokens.json` are what iOS 26 resolves, confirmed against the
lightness gaps `RampLightnessTests` measured on device; they are not the older
iOS 17/18 values (`#ff3b30` and friends). Every adjacent pair clears ΔL* 12 in
both appearances, and the test fails the build if a change closes that gap.
`rating-unrated` and the system fills are Apple's published values, not
measured here.

Glyph ink on a pin is chosen per stop: white unless white falls under 3:1, so
Prime and Slow carry a white glyph and Good and Fair a black one.

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

`text-primary` / `text-secondary` map to `label` and `secondaryLabel`. Fine
print (stamps, attribution, axis words) is `ink-fineprint`, which is also
`secondaryLabel`: `tertiaryLabel` measured about 1.7:1 on white and once
carried a season-risk reason, so size, not lightness, now separates fine print
from supporting text. `text-tertiary` stays in the tokens only so older notes
resolve.

### Layer toggles

The Rivers and Heat switches in the control bar draw a solid fill with a white
label when on (`chrome-rivers-on`, `chrome-heat-on`) and a neutral
`chrome-toggle-off` capsule under primary ink when off. Both on-fills are
literals in both appearances because each has to carry white text: system
teal does not, and the overlay's dark violet is too light. The system button
toggle style drew a pale wash with tinted text, nearly unreadable in dark, so
the app draws the fill itself and `ToggleTintContrastTests` measures it.

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
- A closure-plausible spot keeps its full rating colour and gains a small
  `exclamationmark.circle.fill` badge at the balloon's top right: a shape, so
  the state survives for a colour-blind reader and colour does one job. (It used
  to be a pale balloon with the colour moved to the glyph, which put Fair's
  glyph at 1.51:1.)
- `rating-fair` is a fill and a dot colour, never text. `RatingBadge` and
  `ClosedBadge` draw their label in `text-primary` on a 20% wash of the colour,
  with the stroke at full strength. The label used to be the rating colour,
  which failed 4.5:1 in light for every state and reached 1.38:1 for Fair;
  `RatingBadgeContrastTests` holds the measurements.
- Prime and Slow are within half an L* of each other, so red and blue pins
  differ by hue alone, with unrated gray between them. The word in the badge
  and the legend is what separates them for a colour-blind reader.

## Known divergences in the source

Synced from `main@05760bf` on 2026-10-27. The two app-side divergences listed
here before are gone: the views draw `DS.Rating` (the literal ramp in
`ColorRamp.swift` was removed, so there is one ramp), and `GuidanceFooter`
fills with `DS.Surface.advisory`, not yellow.

One remains, outside the app:

1. **The web map draws the older iOS palette.** The published Washington
   Fishing Map uses `#ff3b30`, `#ff9500`, `#ffcc00`, `#007aff` (and the matching
   dark values), the iOS 17/18 system colours. The app on iOS 26 draws the
   values in `tokens.json`. Same hues, slightly different stops. The palette in
   `docs/web-demo-spec.md` (prime `#E4572E` and so on) was never built.

## Not synced

- **Fonts:** none. The app uses the platform face; there is nothing to copy.
- **Components:** the library is SwiftUI, so nothing was built or bundled. Each
  component below is a *static rendition* — hand-written HTML and CSS bound to
  these tokens, from the Swift source named in its README — for reading and for
  checking colour and spacing, not for import.
- **Assets not carried:** the Xcode `AccentColor` colourset is empty in the
  repo (it declares no colour), and the map's basemap muting is a MapKit
  configuration rather than a token.
