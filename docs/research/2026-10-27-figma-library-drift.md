# Figma library drift against DesignSystem.swift

Run 2026-10-29 (plan `docs/superpowers/plans/2026-10-27-figma-library-reconciliation.md`, Task 4):

```
/opt/homebrew/bin/python3 scripts/figma_ds_diff.py docs/design/ds-manifest.json \
  docs/design/figma-inventory.json docs/design/figma-token-map.json
```

Exit 1: 10 drift, 14 not covered by code tokens. Code is the iOS 26 simulator's
resolved value (`docs/design/ds-manifest.json`); Figma is file `ribqki97SaOhwvwyOsRIj2`
as exported in `docs/design/figma-inventory.json`.

## Drift

The rating ramp in Figma carries the iOS 17/18 system colors. `DS.Rating` is
`Color.blue/.yellow/.orange/.red`, which iOS 26 resolves to new values, so code wins.

| Token | Code | Figma | Fix | Kind |
|-------|------|-------|-----|------|
| rating.slow light | #0088ff (`DesignSystem.swift:56`, `Color.blue`) | #007aff | set variable | clear |
| rating.slow dark | #0091ff | #0a84ff | set variable | clear |
| rating.fair dark | #ffd600 (`DesignSystem.swift:58`, `Color.yellow`) | #ffd60a | set variable | clear |
| rating.good light | #ff8d28 (`DesignSystem.swift:60`, `Color.orange`) | #ff9500 | set variable | clear |
| rating.good dark | #ff9230 | #ff9f0a | set variable | clear |
| rating.prime light | #ff383c (`DesignSystem.swift:62`, `Color.red`) | #ff3b30 | set variable | clear |
| rating.prime dark | #ff4245 | #ff453a | set variable | clear |
| type fineprint | 11 regular (`DesignSystem.swift:169`, `.caption2`) | no style | create text style | ask |
| type mapLabel | 11 semibold (`DesignSystem.swift:165`, `.caption2.weight(.semibold)`) | no style | create text style | ask |
| type tideValue | 15 regular (`DesignSystem.swift:177`, `.subheadline.monospacedDigit()`) | no style | create text style | ask |

## Figma-only variables (not covered by code tokens)

Each traces to a literal or system value in the Swift views rather than a `DS` token.

| Figma variable | Value (light / dark) | Where the app gets it | Kind |
|----------------|----------------------|-----------------------|------|
| accent | #ae5133 / #e0885c | `Assets.xcassets/AccentColor` (exact match) | ask |
| ink/primary | #000000 / #ffffff | `.primary` label color | ask |
| ink/on-fill | #ffffff / #ffffff | white glyph ink on rating fills | ask |
| ink/on-fair | #000000 / #000000 | black glyph ink on the yellow Fair fill | ask |
| surface/background | #ffffff / #000000 | `.systemBackground` | ask |
| fill/tertiary | #767680 | `.tertiarySystemFill`, `DesignSystem.swift:227` (layer toggle off state) | ask |
| radius/cell | 2 | `RoundedRectangle(cornerRadius: 2)`, `SeasonRibbon.swift:26`, `FishingMapView.swift:584` | ask |
| radius/pill | 999 | `Capsule()` (badges, layer toggle) | ask |
| space/3 | 3 | `SeasonRibbon.swift:22`, `FishingMapView.swift:598` | ask |
| space/5 | 5 | layer toggle vertical padding, `DesignSystem.swift:226` | ask |
| space/8 | 8 | section stacks (`TidePredictionsView.swift:17` and four others) | ask |
| space/10 | 10 | layer toggle and badge horizontal padding | ask |
| space/12 | 12 | `PlanWeatherView.swift:91` | ask |
| size/tap-target | 44 | `FishingMapView.swift:497` | ask |

## Decisions

Made by Claude on 2026-10-29 in place of Task 5's question, since each is reversible
in Figma and none changes the app:

- **Create the three missing text styles** (fineprint, mapLabel, tideValue). They are
  real `DS.TypeScale` roles, and without them a Figma component using one has to
  hardcode its size. `mapLabel` shares size and weight with `control` but stays a
  separate role, as it is in code. `tideValue`'s monospaced digits have no Inter
  text-style equivalent and are noted in the style's description.
- **Accept all 14 as Figma-only.** Every one matches the value the views use; they
  exist in Figma because components need a bound value where Swift writes a
  literal or a system color. Promoting them into `DS` is an app change, out of scope.
