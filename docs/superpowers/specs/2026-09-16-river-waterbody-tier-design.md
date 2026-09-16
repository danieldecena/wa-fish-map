# River waterbody tier — design

Plan item 3 of the App Store plan (STATUS decision log, 2026-09-16).

## Problem

`FreshwaterGuide.byWaterbody` already exists and overrides county and statewide rows
(`Fishery.swift`). River sheets already read it by river name
(`RiverDetailSheet.swift:26`). But a launch or pier only reaches a waterbody through
`waterbodySites`, a hand-curated facility-name list, so a ramp on a river never
picks up that river's rows unless someone types its facility name in. Only one
waterbody row exists (Baker Lake sockeye).

## Goal

A launch or pier sitting on a mapped river resolves to that river automatically,
and river rows exist only where their note is true along the whole river.

## Design

### Matching

- New pure function on `River`:
  `static func nearest(to point: LonLat, within meters: Double, in rivers: [River]) -> River?`
  Built on the existing `River.distanceMeters(to:)`. Returns the closest river whose
  distance is `<= meters`, or nil. The nearer river wins at a confluence.
- New resolver on `FreshwaterGuide`:
  `func waterbody(forFacility facility: String, at point: LonLat, rivers: [River]) -> String?`
  Order: `waterbody(forFacility:)` (curated list) first, then
  `River.nearest(to: point, within: 150, in: rivers)?.name`.
  The curated list wins so a lake launch near an inlet river keeps the lake.
- `FishingMapModel.swift:85` (launches) and `:108` (piers) call the new resolver with
  the site's coordinate and the already-loaded rivers. Nothing else changes; the
  existing `fishery(county:waterbody:)` precedence is reused as is.
- The 150 m threshold is a named constant beside `nearest`, so it has one home.

### Data rule: whole-river truth

Each river in `rivers.json` is one feature end to end (the Columbia is asserted
whole by `theColumbiaIsTheWholeRiverNotAFragment`). A row keyed to a river renders at
every matched site along it. Therefore **a river row is admitted only if its note is
true along the entire mapped river in Washington.** Reach-specific claims (upper
Yakima wild rainbows, lower Yakima smallmouth, Upper Columbia summer Chinook) stay in
their county notes, which already word them county-wide.

Seed candidate: Spokane River redband trout, admitted only after a WDFW check confirms
the note holds for the whole Washington reach. If it does not, this slice ships the
matching with Baker Lake as the only row. No reach tier in this slice.

### Tests (Swift Testing)

1. `River.nearest`: a known Skagit River ramp coordinate matches `Skagit River`
   (positive control), and a point about 1 km off every river returns nil (negative
   control). Both are required; one alone can't separate working from always-matching.
2. Resolver precedence: a facility on the curated list resolves to its lake even when
   a river lies within 150 m.
3. `everyWaterbodyRowHasAtLeastOneSiteThatCanReachIt` widens: a row key resolves if it
   is a curated `waterbodySites` key **or** a river name in the bundled `rivers.json`.
   Observe it failing on a deliberately misspelled key before trusting the pass.
4. If a river row ships, `waterbodyRowsAreStampedWithSeasonRisk` covers it too.
5. Full suite via `xcodebuild test` on `platform=iOS Simulator,name=iPhone`, exit code
   captured without a pipe; new tests confirmed by name in the log.

### Docs

- `CLAUDE.md` "Notes are scoped" section: add the river tier and the whole-river rule
  in one short paragraph.
- Bump `fisheries.json` `updated` only if a data row changes.

## Out of scope

- Reach or lake-polygon tiers.
- Changing the river sheet, ratings, or flow logic.
