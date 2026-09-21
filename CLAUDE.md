# WAFishMap

Native MapKit app. Geography overlay + curated seasonal guidance.

## Scope

**Statewide, live.** `WAFishMap/Models/MapScope.swift` queries WDFW for *all* marine
areas (`where=1=1`, layer 6; the "Oregon" North of Falcon area is dropped in
`MapScope.filter` because Oregon regulates it, so the app is Washington only) and *all* launches (`where=1=1`, layer 0) — no
county/area filter. The camera opens auto-fit (`position = .automatic`), then eases once to a regional
span around the user's first location fix — but only if that fix is inside the
Washington bounding box and the user has not already moved the camera. A fix
elsewhere keeps the statewide framing, since the data is Washington-only.
`cameraCenter` is only a pre-load fallback. Do not paste `where=` strings into
the view.

Launches and piers carry no marine-area code, so each is matched to its area by
`MarineArea.matching(_:in:)`: point-in-polygon first, else the nearest area within
150 m (`shoreSnapMeters`). WDFW draws areas to the shoreline and records a pier or
ramp at its landward end, so containment alone read 29 of 63 piers as freshwater.
Indexed in `FishingMapModel.indexSitesToAreas`/`indexPiersToAreas`. Inland/lake
launches match no area → **neutral (gray) rating**, by design.

## Seasonal guidance

`WAFishMap/Resources/fisheries.json` holds hand-curated, per-area species and
their best/good months. It drives:

- the blue→amber→orange→red marker/rating (`FishingRating`, computed by month in
  `Fishery.swift` — pure and unit-tested; the *view* injects `Calendar` month, the
  logic never reads the clock)
- the tap-a-launch detail sheet (`SiteDetailSheet.swift`): NOAA high/low tides
  for the nearest station, what's biting now, best months, and the "Before you go"
  alerts block.
- the sheet's "Lake facts (WDFW)" section, from bundled `lakes.json`
  (`scripts/build_lakes.py`), matched by `Lake.match`. It refuses ambiguous and
  name-contradicted matches, because showing the wrong lake breaks the scope
  promise below.

Editing rules:

- It is **guidance, not regulation.** Every screen that shows it carries the
  disclaimer and a WDFW deep link (`wdfwURL`). Keep both.
- Bump `updated` when you change the data.
- v1 seed is a first pass from general South-Sound knowledge — **treat species/month
  facts as unverified until checked against WDFW.**

## Not this app

Fish Washington is still the rulebook; this app defers to it. No scrape, no
**live** bag limits, no season/closure dates presented as authoritative, no public
catch heatmap. The rating is editorial seasonal *timing*, not a claim that a
fishery is open — always route the user to WDFW to confirm.

## Notes are scoped, and the scope is a promise

`fisheries.json` carries notes at three tiers, and a note is shown at every
site in its tier:

- `areas[]` — one WDFW marine area. Naming a place here is correct; area 10's
  "Elliott Bay / Central Sound spring selective fishery" is true of area 10.
- `freshwater.byCounty` — a whole county. King County holds Lake Washington,
  Lake Sammamish, Lake Dolloff and the Green River, so a note naming one of
  them is wrong at the other three.
- `freshwater.species` — the entire state.
- `freshwater.byWaterbody` — one lake or river. Lakes resolve through the
  curated `waterbodySites` list; rivers resolve by name to any site within 150 m
  of the river line. A river is one feature end to end, so a river row must be
  true along the whole river — the Spokane River was refused on 2026-09-16
  because its rule changes reach by reach (see the STATUS decision log).

`WAFishMapTests/NoteScopeTests.swift` fails the build when a county or
statewide note names a waterbody. It shipped catching a real defect: Lake
Dolloff's Yellow Perch card read "Lake Washington; huge population" because
the note sat on the King County override. The regex is prose matching —
"Potholes"-style names without a Lake/River noun slip it, so the rule binds
the editor, not just the test.

A claim only true of one lake or river belongs in `freshwater.byWaterbody`,
keyed by an exact lake facility (via `waterbodySites`) or an exact river name
from `rivers.json` — never prose-matched. It must still be true everywhere that
key resolves: a whole lake, or a whole river end to end.

## Apple's docs are a tool call, not a memory

An `apple-docs` MCP server is registered globally (`~/.claude/mcp/apple-docs/`).
Check API facts against it rather than recalling them — signatures, deprecations
and availability move every release, and this project targets iOS 18.0, which is
newer than most training data.

- `get_apple_doc(page)` — full page with declaration and per-platform availability.
  Takes a bare symbol (`MKMapView`), a `Framework/Symbol` path, or a docs URL.
  Works for every framework, indexed or not.
- `search_apple_docs(query, framework?)` — when you don't know the symbol's name.
  Search covers Swift, SwiftUI, MapKit, Foundation, UIKit, XCTest, XCUIAutomation
  and CoreLocation; `index_apple_framework` adds others.

Two things that will otherwise cost a build cycle:

**Fetching `developer.apple.com` directly returns an empty shell.** The site renders
client-side, so a plain fetch gets the title and nothing else. Appending `.md` to a
documentation URL returns real markdown — that is what the server does, and why it
succeeds where a raw fetch quietly returns a stub you might mistake for the page.

**UI automation is no longer in XCTest.** `XCUIElement`, `XCUIElementQuery` and
their kin live in `XCUIAutomation`; every `XCTest/XCUI*` path 404s. The server
retries across frameworks and will find it, but write the right one. For the
record, since it was checked against Apple and belongs here:
`XCUIElementQuery.containing(_:)` matches elements *containing a descendant* that
satisfies the predicate — it filters by descendant, not by the element's own
attributes. That is the whole reason it composes differently from `matching(_:)`.

Quote declarations from the docs. Do not reconstruct them from memory.

## Building this app: the runbook owns the how

Any `xcodebuild`, `simctl` or `devicectl` run here goes through the **`ios-build`
skill** first, routine ones included — its destination and exit-status rules
prevent failures rather than only explaining them afterwards. Source lives in
`~/.claude/skills/ios-build/`, and the same content is a maintained page at
<https://claude.ai/artifact/L1ruhjyy8eZpN5zZ4phPWT>. Most of
what is in it was paid for on this project. Do not re-derive it.

Four are restated here in one line each, because a skill that has not loaded
cannot warn you off the thing you are about to do:

- **An exit status must not travel through a pipe.** `xcodebuild ... | tail`
  reports tail's status, and a failed build once read as exit 0 here. Capture to
  a file and take `rc=$?` from the command itself — `status` is read-only in zsh.
  A wrapper's or a harness's exit code is not the build's either: one reported
  `completed (exit code 0)` for a run whose log said `exit=65 ** TEST FAILED **`.
- **An assertion that cannot match is not a passing assertion.** Two of three
  assertions in a run reported as a control queried elements that could never
  match anything, so they were incapable of failing. Green, and worthless. Watch
  a check go red before you trust its green.
- **Keep the error you caught.** `catch { }` rendering one fixed string kept
  WeatherKit mislabelled as "needs a physical device" across nine sessions.
  `401 {reason: NOT_ENABLED}` and a bare 401 are different causes wearing the
  same status code, and only the preserved body separates them.
- **Check the artifact before filing a manual step.** "Enable WeatherKit on the
  identifier" sat in Next Up while a signed profile already on disk proved it was
  done. Signed profiles, lockfiles and build outputs are testimony about remote
  state — read them before writing an action item that lives in a browser.

The simulator destination should be dynamically resolved. Use `scripts/run_sim.sh` instead of hardcoding `name=iPhone 17` or `name=iPhone`, as those device models may not exist on the current runtime.

## Toolchain Requirement

Although the deployment target is iOS 18.0, the build host MUST use **Xcode 26 or newer** (iOS 26 SDK). The `GlassCard` component references `glassEffect(_:in:)`, which will fail to compile on older Xcode versions even behind `#available` checks.

## Subsystem Architecture

- **USGS Streamflow**: Driven by `RiverLoader` and `USGSFlowLoader`. Computes percentiles via `RiverFlowStats` (p10/p25/p75/p90) and intentionally caps flow rating below `Prime`. Features use a 22pt fingertip hit-test tolerance for selection.
- **NDBC Buoys & NOAA Tides**: Buoy observation polling is handled by `NDBCLoader` (wave height, water temperature). Tides use a 170-station model.
- **WeatherKit**: PlanWeather implements a 1-hour cache expiry. Note that WeatherKit simulator provisioning is unsupported; testing requires physical device verification via `scripts/verify_weatherkit_device.sh`.
- **Marine Protected Areas (MPAs)**: Polygon logic punches holes in marine areas and resolves status via a 3-tier system (`inside / clear / unavailable`).
- **Season Risk**: The `seasonRisk` table in `fisheries.json` intentionally caps annual rule-variable species to `.fair`.

