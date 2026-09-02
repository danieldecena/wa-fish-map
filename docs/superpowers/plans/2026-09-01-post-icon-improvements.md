# WAFishMap Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the two Known-broken items that exist only because no UI claim in
this repo is machine-checkable, fix clustering at low zoom, add wind and precip
at plan time, and give notes a waterbody tier so lake-specific guidance can come
back.

**Architecture:** Four independent slices. Task 1 adds the missing verification
layer and unblocks every future "not seen on screen" claim, so it goes first.
Tasks 2-4 are unordered relative to each other. Every slice keeps the existing
shape: pure, testable logic in `Models/`, network behind an injectable protocol,
views thin.

**Tech Stack:** Swift 5, SwiftUI, MapKit, swift-testing (`@Test`/`#expect`),
XCTest for UI only, WeatherKit. Xcode 27, iOS 27 simulator, deployment target 18.0.

**Spec:** none — this plan is derived from `STATUS.md` (Known broken, Next Up),
`TASKS.md`, `CLAUDE.md` (the note-scope promise), and observations recorded in
the 2026-09-01 session.

## Global Constraints

- `IPHONEOS_DEPLOYMENT_TARGET = 18.0`. Anything iOS 26+ only (WeatherKit is fine;
  layered icons already are) must degrade, not crash, below that.
- Guidance stays editorial. Every screen showing it keeps the disclaimer and the
  `wdfwURL` deep link. No live bag limits, no season dates presented as
  authoritative. (`CLAUDE.md`, "Not this app".)
- `fisheries.json`: bump `updated` on any data change.
- Note-scope promise: a note is shown at every site in its tier, so a county or
  statewide note must not name a waterbody. `NoteScopeTests` enforces it.
- **An auto-commit hook is active on this repo.** It committed and pushed working
  tree changes mid-session on 2026-09-01 (`a5a6561`, `e99b97e`), discarding the
  intended commit message. Commit deliberately and early; do not leave a slice
  sitting dirty while you think.
- Signing is a paid Individual team, `877MLS29T9`, profile valid to 2027-09-01.
  No 7-day expiry, no trust prompt.

### Driving the simulator without gestures

Injected taps and `cliclick` drags are unreliable here and have twice opened
menus over the user's own windows. Use this instead — it moves the camera by
triggering the app's own ease-to-region behaviour:

```bash
SIM=2575FFC9-DAEA-407E-ADEF-810F39558E3C   # "iPhone", iOS 27.0
xcrun simctl privacy $SIM grant location com.danieldecena.WAFishMap
xcrun simctl location $SIM set 47.6062,-122.3321
xcrun simctl launch $SIM com.danieldecena.WAFishMap
xcrun simctl io $SIM screenshot /tmp/shot.png
```

---

### Task 1: XCUITest target — make UI claims checkable

Both `## Known broken` entries exist because the repo has one unit-test target
and no way to assert anything on screen. The verify badge is "proven by tests and
by reading the diff, not by observation". This task removes that category.

**Files:**
- Create: `WAFishMapUITests/WAFishMapUITests.swift`
- Create: `WAFishMapUITests/VerifyBadgeUITests.swift`
- Modify: `WAFishMap.xcodeproj/project.pbxproj` (new `com.apple.product-type.bundle.ui-testing` target; the project uses `PBXFileSystemSynchronizedRootGroup`, so a new root folder is picked up automatically once the target exists)
- Modify: `WAFishMap/SiteDetailSheet.swift` (accessibility identifiers only)

**Interfaces:**
- Consumes: nothing.
- Produces: a `WAFishMapUITests` scheme target runnable via
  `xcodebuild test -only-testing:WAFishMapUITests`.

- [ ] **Step 1: Add accessibility identifiers to the badge**

`SiteDetailSheet.swift:45-49` currently renders the badge with no identifier.
Add one so a UI test can find it without matching localised text:

```swift
if s.riskMonths.contains(month) {
    Label("Season varies — verify", systemImage: "exclamationmark.triangle")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("verifyBadge")
}
```

- [ ] **Step 2: Add the UI test target**

In Xcode: File > New > Target > UI Testing Bundle, name `WAFishMapUITests`,
target to test `WAFishMap`. This writes the `PBXNativeTarget` and the
`TEST_TARGET_NAME` build setting. Doing it by hand in `project.pbxproj` is
error-prone; use the GUI once, then commit the diff.

- [ ] **Step 3: Write the failing test**

```swift
import XCTest

final class VerifyBadgeUITests: XCTestCase {
    func testVerifyBadgeAppearsOnASeasonCappedSpecies() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-planMonth", "7"]
        app.launch()

        // Sites are annotations on the map; the launch argument below seeds a
        // deterministic selection so the test does not depend on network order.
        let badge = app.staticTexts["verifyBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 20))
    }
}
```

- [ ] **Step 4: Add the launch-argument seam**

The test must not depend on live WDFW data or on tapping a specific pin. In
`FishingMapModel`, honour `-uiTesting` by loading the bundled
`access-sites.sample.geojson` fixture instead of the network, and `-planMonth`
by forcing the month. Keep the seam to those two arguments; do not build a
general test-harness.

- [ ] **Step 5: Run it and watch it fail**

```bash
xcodebuild test -project WAFishMap.xcodeproj -scheme WAFishMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .ios-build -only-testing:WAFishMapUITests
```
Expected: fails on `waitForExistence`, because nothing selects a site yet.

- [ ] **Step 6: Drive the selection, make it pass**

Under `-uiTesting`, preselect the first fixture site so the sheet is up on
launch. Re-run; expected PASS.

- [ ] **Step 7: Commit and clear the Known-broken entry**

```bash
git add WAFishMapUITests WAFishMap/SiteDetailSheet.swift WAFishMap.xcodeproj/project.pbxproj
git commit -m "test: UI test target, and observe the verify badge on screen"
```
Then delete the verify-badge bullet from `STATUS.md`'s `## Known broken` and
record in the decision log that it is now observed, not inferred.

---

### Task 2: Clamp clustering at low zoom

`e99b97e` moved cluster badges from the grid-cell centre to the members' centroid,
which killed the lattice. It exposed that the grid was also doing anti-overlap
work: at continental zoom the badges pile into an unreadable mass, and
`bestRating` (a `max()`) paints nearly every cell Prime. Both have one cause —
`heatCellDegrees` returns `0.20` for everything past 400km, so a single cell
swallows a huge area.

**Files:**
- Modify: `WAFishMap/FishingMapView.swift:28-34` (`heatCellDegrees`)
- Modify: `WAFishMap/FishingMapView.swift:223-234` (`pinClusters`)
- Test: `WAFishMapTests/MapClusterTests.swift`

**Interfaces:**
- Consumes: `HeatMap.clusters(points:cellDegrees:) -> [MapCluster]` (unchanged).
- Produces: no new API. `pinClusters` gains a zoom floor.

- [ ] **Step 1: Write the failing test**

```swift
@Test func clustersStayApartWhenZoomedOut() {
    // Two sites 0.3 degrees apart must not merge into one badge at any cell
    // size the view actually uses, or the badge lies about where they are.
    let west = LonLat(longitude: -123.00, latitude: 47.00)
    let east = LonLat(longitude: -122.70, latitude: 47.00)
    let clusters = HeatMap.clusters(
        points: [(id: "w", coord: west, rating: .fair),
                 (id: "e", coord: east, rating: .excellent)],
        cellDegrees: 0.20
    )
    #expect(clusters.count == 2)
}
```

- [ ] **Step 2: Run it**

Run: `xcodebuild test ... -only-testing:WAFishMapTests/MapClusterTests`
Expected: this one may already pass — 0.3 degrees exceeds a 0.20 cell. If it
passes, the grid is not the whole story and the real fix is the badge *count* on
screen, not the cell size. Record which it is before changing code; do not skip
this step, it decides Step 3.

- [ ] **Step 3: Add the zoom floor**

Above a camera distance where badges cannot be read, stop drawing per-cluster
badges at all and let the heat overlay carry the state-wide picture. Concretely,
in `pinClusters` return `[]` past the same threshold `heatCellDegrees` uses for
its coarsest bucket, and make sure the Heat toggle is on-by-default there so the
map is not empty.

- [ ] **Step 4: Observe it**

Use the gesture-free recipe in Global Constraints, take screenshots at the
continental and regional zooms, and compare against
`/private/tmp/.../centroid-after-small.png` from 2026-09-01. The pile-up must be
gone and the regional view unchanged.

- [ ] **Step 5: Commit**

```bash
git commit -m "fix: stop drawing cluster badges below a readable zoom"
```

---

### Task 3: WeatherKit wind and precipitation at plan time

`STATUS.md` says this is "likely blocked on a paid-account entitlement". That
premise is false: the team is a paid Individual program membership. The only
real blocker is that the App ID has no WeatherKit capability yet — the current
provisioning profile carries only `com.apple.developer.team-identifier`.

Wind is the single most decision-relevant variable for small-boat fishing, so
this is the highest user value in the plan.

**Files:**
- Create: `WAFishMap/WAFishMap.entitlements`
- Create: `WAFishMap/Models/Conditions.swift`
- Create: `WAFishMap/ConditionsView.swift`
- Create: `WAFishMapTests/ConditionsTests.swift`
- Modify: `WAFishMap/SiteDetailSheet.swift` (add the section next to tides)
- Modify: `WAFishMap.xcodeproj/project.pbxproj` (`CODE_SIGN_ENTITLEMENTS`)

**Interfaces:**
- Consumes: `LonLat`, `planDate: Date` — both already threaded into
  `TidePredictionsView`.
- Produces:
  ```swift
  struct Conditions: Equatable, Sendable {
      let windSpeedMPH: Double
      let windDirection: String     // "NW"
      let precipitationChance: Double  // 0...1
      var isSmallCraftUnfriendly: Bool { windSpeedMPH >= 15 }
  }
  protocol ForecastProviding: Sendable {
      func conditions(at: LonLat, on: Date) async throws -> Conditions
  }
  ```

- [ ] **Step 1: Enable the capability (one GUI action, yours)**

Xcode > target WAFishMap > Signing & Capabilities > + Capability > WeatherKit.
This enables it on the App ID and writes `WAFishMap.entitlements` containing
`com.apple.developer.weatherkit`. Not scriptable; `-allowProvisioningUpdates`
mints profiles but does not add capabilities.

- [ ] **Step 2: Prove the entitlement actually landed**

```bash
security cms -D -i ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision \
  | plutil -p - | grep -i weatherkit
```
Empty output means it did not take, whatever Xcode showed. Do not proceed on the
GUI's say-so.

- [ ] **Step 3: Write the failing test against a stub provider**

```swift
struct StubForecast: ForecastProviding {
    let value: Conditions
    func conditions(at: LonLat, on: Date) async throws -> Conditions { value }
}

@Test func fifteenKnotsReadsAsUnfriendlyToSmallCraft() {
    let c = Conditions(windSpeedMPH: 16, windDirection: "SW", precipitationChance: 0.2)
    #expect(c.isSmallCraftUnfriendly)
}

@Test func aCalmMorningIsNotFlagged() {
    let c = Conditions(windSpeedMPH: 6, windDirection: "N", precipitationChance: 0.1)
    #expect(!c.isSmallCraftUnfriendly)
}
```

- [ ] **Step 4: Run, expect failure**

Expected: compile failure, `Conditions` undefined.

- [ ] **Step 5: Implement `Conditions` and the WeatherKit provider**

Keep `Conditions` pure and `Sendable`. The WeatherKit call lives in a separate
`WeatherKitForecast: ForecastProviding` that reads `HourWeather` nearest
`planDate`. Tests never touch WeatherKit.

- [ ] **Step 6: Add the view, modelled on `TidePredictionsView`**

Same shape: `.task(id:)` keyed on day + coordinate, an injectable provider
defaulted to the real one, a headline, and a failure branch that renders a
caption rather than nothing. Unlike tides, show it for inland sites too — wind
matters on lakes.

- [ ] **Step 7: Run the full suite, then observe on the simulator**

```bash
xcodebuild test -project WAFishMap.xcodeproj -scheme WAFishMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .ios-build
```
Then launch and screenshot a site sheet. WeatherKit needs network and a real
entitlement, so a simulator run is the first honest check that the whole path
works end to end.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat: wind and precipitation at plan time via WeatherKit"
```

---

### Task 4: Waterbody note tier

`CLAUDE.md` states the rule and its consequence outright: "If a claim is only
true of one lake, it does not belong in this file at all until the data model has
a waterbody tier." That is currently deleting real content — the Whatcom Sockeye
entry was removed on 2026-09-01 because it is only true of Baker Lake.

**The hard part is the key, not the tier.** WDFW's access-site layer carries no
waterbody column. Its properties are `FacilityName`, `CountyName`, `Launch`,
`LaunchType`, `Restrooms`, `Camping`, `ADA*`, `OpenDates`, `PublicNotes`,
`Directions`. So the tier needs a key that does not exist in the source.

**Recommended approach: a curated `facilityName -> waterbody` map in
`fisheries.json`.** The guidance is hand-curated already, so curating which ramps
sit on Lake Washington is the same kind of work and the same kind of liability.
Rejected alternatives: substring-matching facility names against waterbody names
reproduces exactly the prose-matching failure `NoteScopeTests` already documents
for "Potholes"; a waterbody polygon layer plus point-in-polygon would match
`MarineArea.contains` architecturally but needs a data source the project does
not have.

**Files:**
- Modify: `WAFishMap/Resources/fisheries.json` (add `freshwater.byWaterbody` and `freshwater.waterbodySites`)
- Modify: `WAFishMap/Models/Fishery.swift:162-184` (`FreshwaterGuide`)
- Modify: `WAFishMap/Services/FishingMapModel.swift:40-44` and `:60-65`
- Modify: `WAFishMapTests/NoteScopeTests.swift`
- Test: `WAFishMapTests/FisheryTests.swift`

**Interfaces:**
- Consumes: `AccessSite.facilityName`, `AccessSite.countyName`.
- Produces:
  ```swift
  // FreshwaterGuide
  let byWaterbody: [String: [SpeciesSeason]]?
  let waterbodySites: [String: [String]]?          // waterbody -> facilityName list
  func waterbody(forFacility: String) -> String?
  func fishery(county: String, waterbody: String?) -> AreaFishery
  ```

- [ ] **Step 1: Write the failing precedence test**

```swift
@Test func aWaterbodyRowBeatsItsCountyAndTheStatewideDefault() {
    let guide = bundledGuide().freshwater!
    let onLakeWashington = guide.fishery(county: "King", waterbody: "Lake Washington")
    let elsewhereInKing = guide.fishery(county: "King", waterbody: nil)
    let perch = onLakeWashington.species.first { $0.species == "Yellow Perch" }
    let countyPerch = elsewhereInKing.species.first { $0.species == "Yellow Perch" }
    #expect(perch?.note != countyPerch?.note)
}
```

- [ ] **Step 2: Run it, expect a compile failure**

`fishery(county:waterbody:)` does not exist yet.

- [ ] **Step 3: Extend `FreshwaterGuide`**

Mirror the existing `fishery(county:)` merge exactly, one tier deeper.
Precedence waterbody > county > statewide, overriding per species name:

```swift
func fishery(county: String, waterbody: String?) -> AreaFishery {
    let base = fishery(county: county).species
    guard let waterbody, let rows = byWaterbody?[waterbody], !rows.isEmpty else {
        return AreaFishery(areaName: "freshwater", species: base)
    }
    let overridden = Set(rows.map(\.species))
    return AreaFishery(areaName: "freshwater",
                       species: rows + base.filter { !overridden.contains($0.species) })
}
```

**Order is load-bearing.** `AreaFishery.inSeason(month:)` breaks rating ties on
declaration index, so overrides must come first. Keep the existing
`fishery(county:)` as-is so the marine path and the tests around it do not move.

- [ ] **Step 4: Thread the key through the model**

`FishingMapModel.fishery(for:)` currently falls straight to
`guide?.freshwater?.fishery(county: site.countyName)`. It becomes:

```swift
return guide?.freshwater?.fishery(
    county: site.countyName,
    waterbody: guide?.freshwater?.waterbody(forFacility: site.facilityName)
)
```
Marine still wins outright before this line — do not blend marine and freshwater.

- [ ] **Step 5: Stamp season risk on the new tier**

`FisheryGuide.resolvingSeasonRisk()` walks `areas`, `freshwater.species` and every
`byCounty` list. Add `byWaterbody` or the new rows silently skip the season cap,
which would let a closed fishery render as Prime. Add an assertion for this
specifically — it is the failure mode that matters.

- [ ] **Step 6: Exempt the new tier in `NoteScopeTests`**

A waterbody note naming its own waterbody is correct, exactly as an area note
naming its area is. Leave the statewide and county tests untouched, and add a
comment saying why the exemption is sound. Then restore the Whatcom Sockeye /
Baker Lake entry under `byWaterbody` as the first real user of the tier.

- [ ] **Step 7: Bump `updated`, run the suite, commit**

```bash
git commit -m "feat: waterbody note tier, and restore the Baker Lake sockeye entry"
```

---

### Task 5 (optional): Camera guard residual

`FishingMapView.swift:38-56` documents the residual honestly: a genuine user
gesture during `.beforeLoad` or `.awaitingPostLoadRefit` is swallowed, because
`MapCameraUpdateContext` exposes no gesture-vs-programmatic reason.

There is a real fix. Attach a `DragGesture(minimumDistance: 1)` and a
`MagnifyGesture` with `.simultaneousGesture` to the `Map`; both fire only for
actual touches. Set `userMovedCamera = true` from those instead of inferring
provenance from the load phase, and the state machine can go.

Do this only if the residual is ever observed to bite. It is narrow, documented,
and the phase machine works; replacing working code carries its own risk.

## Verification

Per task above. Across the whole plan:

1. `xcodebuild test -project WAFishMap.xcodeproj -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .ios-build` — currently 85 tests in 14 suites; must stay green and grow.
2. `python3 scripts/verify_wdfw_live.py` after any `fisheries.json` change, since it checks every `areaName` against the live layer.
3. `swift scripts/make_icon.swift` still passes its own checks if the icon is touched.
4. Screenshot the simulator with the gesture-free recipe for anything visual. A
   green build is not evidence about appearance.
