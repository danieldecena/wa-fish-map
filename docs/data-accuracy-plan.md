# Making the map say something

Everything on screen reads the same colour. This is the measured account of why,
and the order to fix it in. Numbers come from `scripts/rating_spread.py`, which
reimplements `Fishery.swift`'s month logic against the shipped
`fisheries.json` — run it rather than trusting the figures written here.

    python3 scripts/rating_spread.py            # today
    python3 scripts/rating_spread.py --score    # proposed

## What the map actually shows (2026-09-19)

Over all 16 marine areas × 12 months — 192 cells:

| rating | cells | share |
|---|---|---|
| Slow | 45 | 23.4% |
| Fair | 105 | **54.7%** |
| Good | 40 | 20.8% |
| Prime | 2 | **1.0%** |

`Prime` occurs twice in the entire year: area 1 in August, area 12 in November.
That is the whole red budget for the state. Five months show only **two**
distinct colours statewide; September, the month this was raised in, is 8 Fair
and 8 Good with no Prime and no Slow — a four-stop thermal ramp rendering two
adjacent ambers.

## Four causes, and only one of them is the data

### 1. The aggregator erases curation that already exists

`AreaFishery.breadthRating` is `round(mean(top 3))`. Reaching `.excellent`
needs a top-3 mean ≥ 2.5 — roughly three species at peak simultaneously.
Reaching `.poor` needs all three at zero. Both tails are nearly unreachable, so
everything collapses into the middle two buckets. This was a deliberate fix (the
comment records that `max` "painted the whole map red in September"), but it
overcorrected: all-red became all-amber.

**The curation is not the problem — the rounding is.** Areas 3 and 5 produce the
identical 12-month string `001111111100`, and areas 10 and 11 produce
`111111111222`. Both pairs were assumed to be copy-paste. They are not:

- Area 3 lists ocean Chinook, ocean Coho and Black Rockfish; area 5 lists
  Chinook, Coho, Pink Salmon, Dungeness Crab and Blackmouth. Almost nothing is
  shared, and their Halibut and Lingcod months differ too.
- Areas 10 and 11 differ on three species' months — summer hatchery Chinook
  (11 adds good months 6 and 9), Dungeness Crab (10 adds good month 9), Market
  Squid (10 peaks in October, 11 only rates it good).

Real, sourced differences, flattened to the same pixel. **This is the cheapest
fix with the largest effect, and it recovers work already paid for.**

### 2. The rating's unit is the area, so 540 pins carry 16 values

477 launches and 63 piers all inherit one of 16 numbers. Two ramps 40 miles
apart in area 10 are identical *by construction*. No improvement to area data
can change that — it needs a site-level input.

The inputs already exist in the bundle and are unread:

- **`lakes.json`** — 653 lakes carrying `elevationFeet` (median 960 ft, **240
  above 1,500 ft, 68 above 3,000 ft**), `acres`, `management` (4 classes:
  299 trout-emphasis, 270 mixed-trout, 44 warmwater, 40 mixed-warmwater),
  `boatRamp`, `shorelineAccess`, and a species list 0–13 long. Used today
  **only** as a species filter. A 3,500 ft Cascade lake is currently handed the
  lowland trout calendar.
- **`kind` and `launch`** on every site — `pier` (63) vs `access` (477), and
  Concrete 199 / Gravel 78 / Hand launch 70 / Unimproved 50 / **none 80**.

And one outright false claim: **piers inherit boat fisheries.** A pier sheet
today can offer Halibut, Lingcod and **Albacore Tuna**. `Crab Snaring (shore)`
proves the concept of access-scoped species is already half-built.

### 3. Freshwater is one list for most of the state

Three statewide species (Rainbow Trout, Largemouth Bass, Cutthroat Trout), with
county overrides in **8 of 39 counties** while sites span 37. Every
un-overridden inland launch shows the same colour in a given month. `TASKS.md`
#38 fixed one face of this with the lake-species filter; the list underneath is
still three rows.

### 4. Shore and coastal access is missing, but not because the app drops it

WDFW's `MajorFishingArea` layers are queried with `where=1=1` and return
everything they have: **477 access sites and 63 piers, complete**. Their
alternative `ApplicationServices/Facilities` service is a *worse* source — 54
fishing piers, 340 boat ramps, 105 hand launches, mostly GUID and audit fields,
`FishingPierName` frequently null, and one record commented "Need to confirm
this is actually a fishing platform (pier)." Do not switch to it.

The gaps are real and are WDFW's, not ours:

- **The 63 piers sit in 12 of 37 counties**, all Puget Sound and the Strait.
  Zero on the coast (Grays Harbor, Pacific), zero east of the Cascades. The
  marquee Sound piers are present (Edmonds, Des Moines, Point Defiance, Les
  Davis, Redondo, Dash Point, Mukilteo, Seacrest), so this is a coverage
  boundary, not a sampling error.
- **80 of 477 access sites carry no launch type** — "Soos Creek Drift",
  "Beginners' Hole", "Wallace Bar", "Cottonwood". These are river bank-access
  spots already in the bundle, drawn as boat ramps and rated with boat
  fisheries.
- **Razor Clams is curated for areas 1, 2 and 2-2 and has no site to attach
  to.** Long Beach, Twin Harbors, Copalis, Mocrocks and Kalaloch are neither
  launches nor piers. A whole fishery with no map presence.
- Jetties and breakwaters (Westport, Ocean Shores, Ilwaco) are absent for the
  same reason.

## Plan

### Phase 1 — Rescale the aggregator

Pure, testable, no new data. Replace `round(mean(top 3))` with a depth-led score
and absolute thresholds:

    score = best + 0.5 × second + 0.25 × third        (range 0 – 5.25)

Thresholds stated as **meaning**, then checked against the histogram — never
fitted to it:

| rating | cut | what it means |
|---|---|---|
| Prime | ≥ 3.75 | a species at peak **with support** (peak + one good, or peak + two shoulders) |
| Good | ≥ 2.75 | a species at peak alone, or two species solidly in season |
| Fair | ≥ 1.5 | one species in a good month, or two on the shoulder |
| Slow | < 1.5 | nothing better than a lone shoulder month |

Measured result: Prime 1.0% → **19.8%**, Fair 54.7% → 40.1%, Slow unchanged at
23.4%, and **no two areas read identically across the year**.

Keep the scale **absolute**. Red means peak season, in February as in September.
A relative rank-within-month scale would guarantee four colours every month but
would make red in February mean "least bad in February" — which collides with
the scope promise in `CLAUDE.md`. If a comparative view is wanted later it ships
as a separately labelled lens ("Best this month"), never as the unlabelled
default.

Watch two seams:

- `seasonRisk` caps a species' rating to `.fair` **before** scoring, so a capped
  species contributes at most 1.0 / 0.5 / 0.25. That composes correctly, but
  `closurePlausible(inMonth:species:)` reads the max-based `rating(inMonth:)`
  and must be kept consistent with whatever the colour now reflects.
- `rating(inMonth:species:)` with a **named** species is untouched. Only the
  All-species aggregate changes.

Tests: assert the distribution — all four ratings occur, and Prime is neither
absent nor a majority — plus fixed expectations on named area/months. Per the
runbook rule, watch each new assertion fail before trusting it green;
`scripts/rating_spread.py` is the harness that makes the failure visible.

### Phase 2 — Per-site signal from data already in the bundle

**2a. Access-scoped species.** Add `access` to species rows: `boat`, `shore`,
`any` (default `any`, so the field is additive and every existing row keeps
behaving). Drop boat-only species at piers, and at lakes whose `boatRamp` is
`"No"`. Piers stop claiming albacore; 63 piers differentiate from 477 ramps.
This removes false claims, so it is accuracy work, not decoration.

**2b. Label the 80 bank-access sites.** A site with no launch type and no pier
flag is shore access. Give it its own `kind` so it reads as bank fishing and
takes shore-scoped species. Cheap, and it makes river access legible for the
first time.

**2c. Lake attributes.** `management` and species richness are safe to use now.
**Elevation is not** — shifting a high lake's trout months later is exactly the
invented precision `CLAUDE.md` warns against. Find a WDFW source for the shift
first. Absent one, use elevation as a **confidence downgrade** (a 3,500 ft lake
being handed the lowland calendar is low-confidence, not differently-rated) and
let Phase 4 render it honestly.

### Phase 3 — Split the encoding

Colour answers *how good*; a second channel answers *how many species are
working*. Today one colour fuses both, which is part of why everything reads
mid-scale.

**Do not make colour a bare `max`.** Measured: max-only puts 9 of 16 areas at
Prime in September and 8 of 16 in October — the original all-red bug, restored.
The Phase 1 score is already depth-led (the best species carries weight 1.0,
breadth only 0.5 and 0.25), so colour reads as "how good" while breadth becomes
a tiebreak. Surface breadth as its own mark — a count badge on the pin or in
the sheet — so two ambers can be told apart on screen.

### Phase 4 — Provenance on every row

Add `source` (and optionally `confidence`) per species row: WDFW-checked with a
date, versus seeded-unverified. Then:

- Render unverified rows differently instead of asserting them.
- A test asserts every row carries a source, the way `NoteScopeTests` binds the
  editor.
- Generate a coverage report — which areas and counties are unverified. **That
  report is the Phase 5 backlog.**

This makes "these two areas look the same" a question the data can answer,
instead of a silence. `CLAUDE.md` already flags the v1 seed as unverified; this
is where that warning becomes machine-readable.

### Phase 5 — Curate, driven by Phase 4's report

Priority order from the measurements:

1. Freshwater statewide (3 species) and the 31 counties with no override — the
   largest number of identically-coloured pins in the app.
2. The species whose months were genuinely copied across areas: ocean Chinook,
   ocean Coho, Black Rockfish, Crab Snaring and Razor Clams each have **one**
   month signature across 3–5 areas; Lingcod has two across thirteen.
3. Marine areas the coverage report marks unverified.

### Phase 6 — Shore and coastal sites (needs a decision)

WDFW has no more to give. Adding coast and shore access means a second,
non-WDFW source and the scope question that comes with it: the app currently
promises WDFW-derived geography. Candidates, cheapest first:

- **Razor clam beaches** — five named beaches, hand-curated, a closed set that
  rarely changes, and it gives an already-curated fishery somewhere to live.
- **Jetties** — Westport, Ocean Shores, Ilwaco. Also a short closed set.
- **State Parks and municipal piers** — a long tail, an ongoing maintenance
  burden, and a different data licence. Do not start here.

Decide the source question before building any of it.

## Open questions

- Is there a WDFW source for a high-lake seasonal shift? Without one, 2c stays a
  confidence signal rather than a rating change.
- Does adding hand-curated coastal sites break the "WDFW geography" promise, or
  extend it? That is a scope call, not an engineering one.
- Is ~20% Prime the right density, or still too generous? The threshold is the
  knob; the meanings in the Phase 1 table are what must survive the argument.
