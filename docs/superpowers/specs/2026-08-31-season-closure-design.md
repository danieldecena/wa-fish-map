# Season/closure (open-window) modeling — design

**Date:** 2026-08-31
**Status:** approved, not implemented
**Feature:** a rating never shows Prime for a species that is plausibly closed.

## Problem

`SpeciesSeason.rating(inMonth:)` in `WAFishMap/Models/Fishery.swift` computes a
`FishingRating` from `bestMonths` and `goodMonths` alone. It has no notion of a
closed season, so a species at its seasonal peak renders `.excellent` ("Prime",
green) in a month it may not be legal to fish.

The data already knows better and is ignored: **42 of 134 species entries** in
`WAFishMap/Resources/fisheries.json` carry closure language in their free-text
`note` field — "Some rockfish closed May-Jul", "Season opens ~mid-June by quota;
Chinook often closes mid-Aug", "Selective-fishery rules and season dates set
annually". None of it reaches the rating, the marker color, or the heat overlay.

## Constraint

`CLAUDE.md` draws a hard product boundary: the app is editorial seasonal
*timing*, not a rulebook. No scraped regulations, no live bag limits, and no
season or closure dates presented as authoritative. Every screen defers to WDFW.

The design must therefore change what the app *shows* without the app *claiming*
a season date. It suppresses an over-confident rating; it never states that a
fishery is open or closed.

## Decisions

1. **Cap, do not hide.** A closure-prone species keeps its card and its place in
   "Biting now" but cannot reach Prime. Hiding it would cost the user the very
   information that sends them to WDFW.
2. **Cap only in flagged months.** A species reliably open at its peak still
   rates Prime there. A blanket per-species cap would permanently dim fisheries
   like peak-August Chinook.
3. **Cap at `.fair`.** Reuses the existing four-step ramp, so the legend, the
   marker colors, the heat overlay, and any future recolor path are untouched. A
   badge carries the meaning that the color cannot.
4. **Curate centrally by species.** One `seasonRisk` table, not a `verifyMonths`
   array repeated across 134 rows. A correction lands in one place.

## Architecture

### Data

A `seasonRisk` array at the top level of `fisheries.json`, beside `updated`,
`disclaimer`, and `wdfwURL`:

```json
"seasonRisk": [
  {
    "match": "Chinook",
    "months": [1, 2, 3, 4, 5, 6, 11, 12],
    "reason": "Selective-fishery and quota dates set annually"
  }
]
```

- `match` — case-insensitive substring tested against `SpeciesSeason.species`.
  One row covers `Chinook Salmon`, `Chinook Salmon (ocean)`,
  `Chinook Salmon (Tulalip)`, and `Resident Chinook (Blackmouth)`.
- `months` — 1-12, the months in which a closure is plausible.
- `reason` — short phrase shown to the user. Describes *why verification is
  needed*, never a date claim.

A single species row opts out with `"seasonRisk": "none"`, for the real case
where one marine area is open while its neighbours are not.

### Model

`SpeciesSeason` gains two fields that are **not decoded from JSON** and are
stamped during load:

- `riskMonths: [Int]` — defaults to `[]`
- `riskReason: String?` — defaults to `nil`

`rating(inMonth:)` keeps its current peak/good/shoulder/off computation, then
applies one final clamp:

```swift
let base = /* existing computation */
return riskMonths.contains(month) ? min(base, .fair) : base
```

The function stays pure and clock-free. The view continues to inject the
`Calendar` month, per the existing rule in `CLAUDE.md`.

### Resolution

A new `SeasonRisk` type owns the match rule. A pure
`FisheryGuide.resolvingSeasonRisk()` returns a guide whose every
`SpeciesSeason` carries its resolved `riskMonths`/`riskReason`.
`FisheryLoader.guide(from:)` calls it once after decode, so matching costs
nothing per render.

Resolution order for one species row:
1. If the row sets `"seasonRisk": "none"`, it gets `riskMonths: []`. Stop.
2. Otherwise collect every `seasonRisk` entry whose `match` is a
   case-insensitive substring of the species name.
3. Union their `months`. Join distinct `reason` values with "; ".

### UI

`SiteDetailSheet` shows a "Season varies — verify" badge beside the rating badge
on any species card whose `riskMonths` contains the displayed month, with
`riskReason` as secondary text under it.

No new disclaimer surface: the existing "Before you go" block and its WDFW deep
link already carry the legal framing on the same screen.

The map marker and the heat overlay need no change. They read
`AreaFishery.rating(inMonth:)`, which is the max over species ratings and so
inherits the cap for free.

## Curation scope

Roughly 15-20 `seasonRisk` rows cover all 42 flagged entries. Expected families:
salmon (Chinook, Coho, Sockeye, Pink, Chum), halibut, Dungeness and red rock
crab, spot shrimp, lingcod, rockfish, and razor clams.

Freshwater species — trout, bass, walleye, kokanee, catfish — stay unflagged.
Most are open year-round or nearly so, and flagging them would dim the map for
no gain.

## Honest limits

The risk months are derived from the same `note` prose that `CLAUDE.md` records
as an unverified first pass. The cap is therefore an honest signal of
*uncertainty* and is not itself verified against WDFW. That is acceptable for a
"verify this" prompt. It would not be acceptable for anything asserting a date,
which is why no date is shown.

A species may be genuinely open in one marine area and closed in the next. The
central table cannot express that; the per-row `"seasonRisk": "none"` opt-out is
the escape hatch, applied case by case as it is discovered.

The table matches by substring against the species name, not by area, so a
single row's months apply everywhere that species appears. The Lingcod row
derived from a "mid-Mar to mid-Oct" note also clamps Lingcod in areas whose own
note describes a much narrower "~May 1-Jun 15" window, and the same is true for
Crab, Coho, Sockeye, and Chinook: one row's months are wider than what some
individual areas actually experience. Over-flagging is the safe direction for a
"verify this" signal, but a future data editor curating a new area's `note`
should know the central table can silently clamp it to a window that does not
match what they just wrote.

## Testing

Pure logic, so all of it is unit-testable without a simulator.

- `SpeciesSeasonTests` — a flagged month caps a `.excellent` species to `.fair`;
  an unflagged month leaves it `.excellent`; a species already `.poor` is
  unchanged by the cap.
- `SeasonRiskTests` — substring matching catches the four Chinook variants;
  matching is case-insensitive; a non-matching species gets empty `riskMonths`;
  `"seasonRisk": "none"` wins over a matching table row; two matching rows union
  their months and join their reasons.
- `AreaFisheryTests` — an area whose only Prime species is capped drops from
  `.excellent` to `.fair`, proving the marker inherits the cap.
- Existing `FisheryTests` must still pass unchanged, proving the cap is inert
  when no `seasonRisk` table is present.

## Out of scope

- Real open/closed dates from any WDFW feed.
- Any UI that states a fishery is open or closed.
- Changes to `FishingRating` itself, the legend, or the heat overlay.
