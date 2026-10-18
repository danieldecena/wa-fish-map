# Washington Fishing Map page vs the app's design system

Checked 2026-10-18 for `Artifacts/salmon-rivers/index.html`.

Sources compared:

- The page: `:root` tokens and component CSS in `index.html`.
- The published design system (https://claude.ai/artifact/VA1Zg6mdxPkiukUD6bxDuc, version 1792362268-e369): `project/tokens.json`, `map-language.md`, `README.md` and the component notes.
- The app itself: `WAFishMap/DesignSystem.swift` and `WAFishMap/ColorRamp.swift` on this branch.
- The app's own colour-blindness checks: `docs/design/ramp-check/*.png`.

Status words: **match**, **drift fixed** (changed in this pass), **drift kept** (differs on purpose, reason given), **no system value** (the system has no number for it, so nothing to compare).

## The rating colours: the page matches the app, so they were not changed

`tokens.json` carries two ramps. `rating-*` (`#f01c0d`, `#ff7300`, `#ffc700`, `#0073ff`) is labelled "what renders". `rating-*-system` (Apple's system red, orange, yellow, blue) is labelled "what the design intends, declared, not yet drawn".

That label is out of date. The design system was synced from `main@b9cdd9b` on 2026-09-20. The same day, commit `3eec27a` ("Draw the rating ramp from DS.Rating instead of four literals") made `FishingRating.color` return `DS.Rating.*`, and `ColorRamp.swift` now says "the stops themselves live in `DS.Rating` and nowhere else". No Swift file still contains the four literals (grepped). So the app draws the system ramp, and the page's values are exactly the system ramp in both appearances.

Decision (option a): leave the page's rating colours alone and record this. Option (b), switching to the literals, would move the page away from what the app draws. The design system does not say the page's colours are wrong; its `rating-*-system` rows say the page is right.

`test/baseline-pins.json` stores token names (`var(--prime)` and so on), not hex values, so a hex change would not have gone red there anyway. The ramp test added with this pass (`test/design.test.js`) pins the hex values against the app's system colours.

Recommendation for the design-system owner: update `rating-*` to the system values, or mark them stale.

## Token table

| Token | Page value (light / dark) | System value (light / dark) | Status |
| --- | --- | --- | --- |
| prime | `#ff3b30` / `#ff453a` | `rating-prime-system`, `DS.Rating.prime` = Color.red: `#ff3b30` / `#ff453a` | match |
| good | `#ff9500` / `#ff9f0a` | `#ff9500` / `#ff9f0a` | match |
| fair | `#ffcc00` / `#ffd60a` | `#ffcc00` / `#ffd60a` | match |
| slow | `#007aff` / `#0a84ff` | `#007aff` / `#0a84ff` | match |
| unrated | `#8e8e93` / `#8e8e93` | `#8e8e93` / `#8e8e93` | match |
| rating literals in tokens.json | not used | `#f01c0d`, `#ff7300`, `#ffc700`, `#0073ff` | drift kept: stale in tokens.json, the app no longer draws them (see above) |
| ink | `#000000` / `#ffffff` | text-primary `#000000` / `#ffffff` | match |
| ink2 | `rgba(60,60,67,0.78)` / `rgba(235,235,245,0.74)` | text-secondary `rgba(60,60,67,0.6)` / `rgba(235,235,245,0.6)` | drift kept: 0.6 on `#f2f2f7` is 3.3:1, below the page's 4.5:1 rule; 0.78 gives 5.3:1 |
| ground | `#f2f2f7` / `#1c1c1e` | surface-grouped `#f2f2f7` / `#1c1c1e` | match |
| surface | `#ffffff` / `#000000` | surface-background `#ffffff` / `#000000` | match |
| fill-advisory | `rgba(120,120,128,0.16)` / `0.32` | surface-advisory same | match |
| fill-row | `rgba(116,116,128,0.08)` / `rgba(118,118,128,0.24)` | surface-species-row same | match |
| fill-toggle | `rgba(118,118,128,0.14)` / `0.26` | none in tokens.json | no system value |
| on | `#007c9e` | `DS.Chrome.riversOn` `#007C9E` (in the Swift, not in tokens.json) | match |
| brand-a, brand-b | `#1797ae`, `#004a79` | brand-icon-start, brand-icon-end | match |
| on-text, river, halo, pin-edge, glass, glass-line, lift | web-only values | none | no system value |
| radius, glass card | 14 px | radius-chrome 14 | match |
| radius, advisory | 12 px | radius-advisory 12 | match |
| radius, species row | 10 px | radius-species-row 10 | match |
| radius, badge and chips | 999 px | radius-pill 999 | match |
| radius, sheet top | 18 px | none (iOS sheet corner is the platform's) | no system value |
| badge fill and stroke | 20% wash plus 1 px stroke | badge-fill 0.2, 1 px stroke | match |
| badge text colour | ink | the rating colour at full strength | drift kept: the design system itself flags Fair-on-wash as failing 4.5:1 and "the first pair to fix"; ink on the wash passes |
| badge padding | 5 px 10 px | 5 px vertical, 10 px horizontal | match |
| badge padding inside a species row | was 3 px 8 px | 5 px 10 px | drift fixed |
| pin-closed opacity | 0.55 | 0.55 | match |
| pin scale | 0.8 | marker-pin 0.8 | match |
| cluster scale | 0.95 | marker-cluster 0.95 | match |
| pin shape | teardrop balloon with the fish brand glyph on every kind | MapKit balloon with a per-kind glyph (boat, angler, fish) | drift kept: per-kind glyph art does not exist for the page; the design system's own previews draw stand-ins. Recommend adding the three glyphs |
| closure-plausible pin treatment | whole pin faded to 0.55 | pale balloon with the rating colour on the glyph; faded is for "closed" | drift kept: needs a pin redraw, outside this pass. Recommend adopting the pale-balloon treatment so the state survives for a colour-blind reader |
| cluster colour | best member's colour | best member's colour (map-language) | match now; changes in Typical season in commit 4, on purpose (see that section when it lands) |
| glass card inset | 16 px both widths, was | 8 px compact, 12 px regular | drift fixed (8 and 12) |
| glass card padding | 10 px vertical, 12 px horizontal | 10 px vertical, platform inset horizontal | match |
| glass card max width | 460 px | 460 px | match |
| glass blur and saturation | `blur(20px) saturate(1.8)` on `rgba` fill | Liquid Glass / `ultraThinMaterial` (no numbers) | no system value |
| sheet background | 97% opaque plus blur | opaque enough to read on (`thickMaterial`) | match in intent |
| legend order | prime, good, fair, slow, unrated, then the faded note | hot to cold, same | match |
| legend dot size | was 10 px | 8 px | drift fixed |
| legend dot to label gap | was 4 px | 3 px (space-3) | drift fixed |
| legend entry gap | was 12 px | 10 px (space-10) | drift fixed |
| legend words, Typical season | Prime, Good, Fair, Slow, No seasonal guidance | Prime, Good, Fair, Slow, No data | drift kept: "No seasonal guidance" says what the gray means |
| legend words, Recent reports | Excellent, Good, Fair | none (not an app concept) | no system value |
| legend text size | 11 px / 13 px | legend 11 / 13 | match now; raised to 12 px in commit 5 on purpose (the design system README names `legend` and `control` as the roles to promote) |
| footer text size | 11 px / 14 px | fineprint 11 / 13 | drift, raised to 12 px in commit 5 |
| title | 17 / 22, 600 | sectionTitle 17 / 22, 600 | match |
| item title | 15 / 20, 600 | itemTitle 15 / 20, 600 | match |
| supporting | 15 / 20 | supporting 15 / 20 | match |
| meta | 12 / 16 | meta 12 / 16 | match |
| map label | 11 / 13, 600 | mapLabel 11 / 13, 600 | match |
| cluster count | 11 / 13, 700 | clusterCount 11 / 13, 700 | match |
| badge text | 12 / 16, 700 | badge 12 / 16, 700 | match |
| control text | 12 / 16, 600 | control 11 / 13, 600 | drift kept: larger, on 44 px targets, in the direction the README recommends |
| font family | system sans stack | same stack | match |
| sheet block gap | 18 px | space-18 | match |
| species row padding and gap | 10 px | space-10 | match |
| footer stack gap | 8 px | space-8 | match |
| advisory padding | 12 px | space-12 | match |
| sheet side padding | 16 px | space-8 compact, space-12 regular | drift kept: 16 px matches the platform list margin; a web sheet at 8 px reads cramped and sits closer than the 44 px targets want |
| "Before you go", WDFW link, not-for-navigation line | present on every sheet | required on every sheet | match |

## Tally

59 rows. Counted by hand from the table: each row once, the five rating rows light and dark together.

- 40 match.
- 5 drift fixed in commit 1 (glass card inset, in-row badge padding, legend dot size, dot gap, entry gap).
- 1 drift to be fixed in commit 5 (footer text size, raised to 12 px).
- 8 drift kept, each with its reason in the table.
- 5 no system value (nothing to compare).

Headline: of the 54 rows the system has a value for, 40 match, 6 drift and were or will be fixed, 8 drift on purpose. The rating colours all match the app.

## Notes for the design-system owner

- `GuidanceFooter` in the app still drew `.yellow.opacity(0.12)` at the time of the sync (README, "Known divergences", item 3). The page already uses the neutral advisory fill, so the page is ahead of that component there.
- The web-demo palette in `docs/web-demo-spec.md` (`#E4572E` and friends) is not what the page uses and not what the app draws. The page follows the app.

## Colour-blindness check of the Typical season pins (commit 2)

The app's own checks are `docs/design/ramp-check/ramp-*-deuteranopia.png` and `*-protanopia.png`. They show the same thing the numbers below do: under deuteranopia red turns dark olive, orange and yellow turn two nearby golds, blue stays blue.

Lightness steps (L*) between ramp stops after a Machado severity 1.0 simulation (`test/design.test.js` computes these from the page's own tokens):

| Pair | Normal (light) | Deuteranopia (light / dark) | Protanopia (light / dark) |
| --- | --- | --- | --- |
| prime vs good (red vs orange) | 14.7 | 12.3 / 13.3 | 20.0 / 20.9 |
| good vs fair (orange vs yellow) | 12.8 | 11.3 / 11.7 | 15.4 / 15.6 |

The app's gate is 12 L* between adjacent stops. Red vs orange clears it, narrowly under deuteranopia. The weak pair is orange vs yellow, which falls just under it, as the README already said. So the fix is not new hues. Every single pin in Typical season now carries a word: the full "Name, rating" label where it fits, otherwise the rating word alone (`Season.SHORT`), the way Recent reports labels pins. The glyph already switches between white (prime, slow) and dark (good, fair), a free second cue between red and orange.
