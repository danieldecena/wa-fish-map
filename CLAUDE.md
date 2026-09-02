# WAFishMap

Native MapKit app. Geography overlay + curated seasonal guidance.

## Scope

**Statewide, live.** `WAFishMap/Models/MapScope.swift` queries WDFW for *all* marine
areas (`where=1=1`, layer 6) and *all* launches (`where=Launch=1`, layer 0) — no
county/area filter. The camera opens auto-fit (`position = .automatic`), then eases once to a regional
span around the user's first location fix — but only if that fix is inside the
Washington bounding box and the user has not already moved the camera. A fix
elsewhere keeps the statewide framing, since the data is Washington-only.
`cameraCenter` is only a pre-load fallback. Do not paste `where=` strings into
the view.

Launches carry no marine-area code, so each is matched to its area by point-in-polygon
(`MarineArea.contains(_:)`, indexed in `FishingMapModel.indexSitesToAreas`). Inland/lake
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

`WAFishMapTests/NoteScopeTests.swift` fails the build when a county or
statewide note names a waterbody. It shipped catching a real defect: Lake
Dolloff's Yellow Perch card read "Lake Washington; huge population" because
the note sat on the King County override. The regex is prose matching —
"Potholes"-style names without a Lake/River noun slip it, so the rule binds
the editor, not just the test.

If a claim is only true of one lake, it does not belong in this file at all
until the data model has a waterbody tier.

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

## Check the artifact before filing a manual step

"Enable WeatherKit on the identifier" sat in Next Up as work to do. It had been
done for some time, and the machine could prove it: Apple's portal cannot emit a
provisioning profile carrying `com.apple.developer.weatherkit` unless the
capability is enabled, and that profile was already embedded in the device build
on disk. One `security cms -D -i ... | plutil -extract Entitlements` would have
closed the item and skipped a documented 30-minute propagation wait.

Before writing an action item that lives in someone's browser — a portal toggle,
an account setting, a propagation delay — ask what local artifact would already
be different if it were done. Signed profiles, lockfiles, generated headers and
build outputs are testimony about remote state. Read them first.

## An exit status must not travel through a pipe

`xcodebuild ... | tail` reports tail's status, so a failed build was recorded as
exit 0 and the session proceeded on a false green. Any pipeline whose result you
intend to trust needs `set -o pipefail`, or an explicit `${PIPESTATUS[0]}` check.
Prefer capturing to a file and reading the status from the command itself:

    xcodebuild ... > /tmp/build.log 2>&1; status=$?
    tail -40 /tmp/build.log
    [ $status -eq 0 ] || exit $status

## An assertion that cannot match is not a passing assertion

A control run was reported as proving the harness worked. Two of its three
assertions queried for elements that could never match anything, so they were
incapable of failing — green, and worthless. Only the identifier lookup was real.

A test that has never been seen to fail has not been tested. Before trusting a
negative result, confirm the query matches something in the known-good case, or
deliberately break the thing and watch the assertion go red. "It passed" and
"it can distinguish" are different claims.

## Keep the error you caught — its shape is the diagnosis

`catch { }` that discards the error and renders one fixed string turned every
distinct failure into the same mute message, which is what kept WeatherKit
mislabelled as "needs a physical device" across nine sessions. Log the status
code, the URL and the response body.

The payoff is not just legibility. WeatherKit returns `401 {reason: NOT_ENABLED}`
with a body when the capability is missing, and a bare 401 when the block is at
account level. Same status code, different cause, and only the preserved body
tells them apart. An error narrowed to its shape is usually most of the answer.
