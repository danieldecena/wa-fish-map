# River Waterbody Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Context:** App Store plan item 3. A launch or pier reaches `freshwater.byWaterbody`
only through the hand-typed `waterbodySites` list, so ramps on rivers never get river
rows. This makes a launch within 150 m of a mapped river resolve to it, and admits river
rows only when the note is true along the whole river.

**Goal:** Launches and piers on a mapped river pick up that river's waterbody rows automatically.

**Architecture:** A pure `River.nearest` finds the closest river within 150 m. A pure
resolver on `FreshwaterGuide` tries the curated list first, then the river. `FishingMapModel`
precomputes the result per site into an index (like `siteAreaName`), so pins don't re-scan
river geometry on every render.

**Tech Stack:** Swift 6, SwiftUI/MapKit, Swift Testing (`@Test`/`#expect`), `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-09-16-river-waterbody-tier-design.md`

## Global Constraints

- Swift Testing only in unit tests. Fixtures load through `FixtureBundle.loader`, never `Bundle.main`.
- Any `xcodebuild` goes through the `ios-build` skill first. Destination: `-destination 'platform=iOS Simulator,name=iPhone'`.
- The exit status never travels through a pipe: `xcodebuild ... > "$log" 2>&1; rc=$?`. Do not use `status` (read-only in zsh).
- A new test counts as run only when its name appears in the log as passed.
- `fisheries.json` is guidance, not regulation. Never invent months, bait, or species; bump `updated` when data changes.
- A river row is admitted only if its note is true along the whole mapped river in Washington.
- Commits: scoped pathspec, new commit, trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

Test command used below (call it TEST):
```bash
log=$(mktemp); xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone' test \
  -only-testing:WAFishMapTests/<Suite> > "$log" 2>&1; rc=$?; echo "rc=$rc"; grep -E "Test .*(passed|failed)|error:" "$log" | tail -20
```

---

### Task 1: `River.nearest`

**Files:** Modify `WAFishMap/Models/River.swift` (add below `distanceMeters`). Test in `WAFishMapTests/RiverTests.swift` (MARK: Tap distance section, reuse `Self.reach`).

**Interfaces:** Produces `static let waterbodyMatchMeters: Double = 150` and
`static func nearest(to point: LonLat, within meters: Double, in rivers: [River]) -> River?`.

- [ ] **Step 1: Write failing tests** in `RiverTests`:
```swift
    // MARK: Nearest river

    private static let other = River(
        name: "Other River", streamOrder: 3, lengthKm: 1,
        lines: [[LonLat(longitude: -122.000, latitude: 47.5020),
                 LonLat(longitude: -121.990, latitude: 47.5020)]]
    )

    @Test func aPointBesideARiverMatchesIt() {
        // ~55m north of Test River.
        let ramp = LonLat(longitude: -121.995, latitude: 47.5005)
        #expect(River.nearest(to: ramp, within: 150, in: [Self.reach])?.name == "Test River")
    }

    /// The control: without a point that must NOT match, "matches" is
    /// indistinguishable from "always returns the first river".
    @Test func aPointAKilometreOffMatchesNothing() {
        let far = LonLat(longitude: -121.995, latitude: 47.509)
        #expect(River.nearest(to: far, within: 150, in: [Self.reach]) == nil)
    }

    /// Two rivers in range: the nearer one wins, whatever the array order.
    @Test func theNearerRiverWinsAtAConfluence() {
        // ~167m from Test River, ~56m from Other River (0.002 deg lat apart).
        let point = LonLat(longitude: -121.995, latitude: 47.5015)
        #expect(River.nearest(to: point, within: 300, in: [Self.reach, Self.other])?.name == "Other River")
    }
```
- [ ] **Step 2:** Run TEST with `<Suite>` = `RiverTests`. Expect a build error: `nearest` isn't defined.
- [ ] **Step 3: Implement** in `River`:
```swift
    /// How close a launch must sit to a river's line to count as on it. Ramps sit
    /// back from NHD's centreline; much wider and a lakeside launch catches the
    /// neighbouring river.
    static let waterbodyMatchMeters: Double = 150

    /// The closest river within `meters` of `point`, or nil. The nearer river wins
    /// at a confluence.
    static func nearest(to point: LonLat, within meters: Double, in rivers: [River]) -> River? {
        var best: (river: River, distance: Double)?
        for river in rivers {
            guard let d = river.distanceMeters(to: point), d <= meters else { continue }
            if best == nil || d < best!.distance { best = (river, d) }
        }
        return best?.river
    }
```
- [ ] **Step 4:** Run TEST. Expect `rc=0`, with all three new test names passed.
- [ ] **Step 5:** Commit `River.swift RiverTests.swift`: "Find the nearest river within a distance".

### Task 2: Resolver with curated-first precedence

**Files:** Modify `WAFishMap/Models/Fishery.swift` (`FreshwaterGuide`, next to `waterbody(forFacility:)`). Create `WAFishMapTests/WaterbodyResolverTests.swift` (the project uses synchronized folder groups, so no pbxproj edit).

**Interfaces:** Consumes `River.nearest`, `River.waterbodyMatchMeters`. Produces
`func waterbody(forFacility facility: String, at point: LonLat, rivers: [River]) -> String?`.

- [ ] **Step 1: Write failing tests:**
```swift
import Testing
@testable import WAFishMap

struct WaterbodyResolverTests {
    private static let river = River(
        name: "Test River", streamOrder: 4, lengthKm: 1,
        lines: [[LonLat(longitude: -122.000, latitude: 47.500),
                 LonLat(longitude: -121.990, latitude: 47.500)]]
    )
    private static let guide = FreshwaterGuide(
        species: [], waterbodySites: ["Test Lake": ["Lakeside Ramp"]]
    )
    private static let nearRiver = LonLat(longitude: -121.995, latitude: 47.5005)

    @Test func anUncuratedRampBesideARiverResolvesToTheRiver() {
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: Self.nearRiver, rivers: [Self.river]) == "Test River")
    }

    /// A lake launch near an inlet river must keep the lake.
    @Test func theCuratedListBeatsANearbyRiver() {
        #expect(Self.guide.waterbody(forFacility: "Lakeside Ramp", at: Self.nearRiver, rivers: [Self.river]) == "Test Lake")
    }

    @Test func anUncuratedRampFarFromEveryRiverResolvesToNothing() {
        let far = LonLat(longitude: -121.995, latitude: 47.509)
        #expect(Self.guide.waterbody(forFacility: "Unknown Ramp", at: far, rivers: [Self.river]) == nil)
    }
}
```
- [ ] **Step 2:** Run TEST (`WaterbodyResolverTests`). Expect a build error.
- [ ] **Step 3: Implement** in `FreshwaterGuide`:
```swift
    /// Curated list first, so a lake ramp near an inlet river keeps the lake;
    /// otherwise the river the site sits on.
    func waterbody(forFacility facility: String, at point: LonLat, rivers: [River]) -> String? {
        waterbody(forFacility: facility)
            ?? River.nearest(to: point, within: River.waterbodyMatchMeters, in: rivers)?.name
    }
```
- [ ] **Step 4:** Run TEST. Expect `rc=0`, with 3 names passed.
- [ ] **Step 5:** Commit: "Resolve a site's waterbody from the curated list, then rivers".

### Task 3: Precomputed index in `FishingMapModel`

**Files:** Modify `WAFishMap/Services/FishingMapModel.swift`: properties near `siteAreaName` (:26), `fishery(for site:)` (:80-87), `fishery(for pier:)` (:103-110), and the call sites of `indexSitesToAreas()` (:133, :159) and `indexPiersToAreas()` (:188). Test in `WAFishMapTests/FishingMapModelTests.swift`.

**Interfaces:** Consumes the Task 2 resolver. Produces `private(set) var siteWaterbody: [AccessSite.ID: String]`, `private(set) var pierWaterbody: [FishingPier.ID: String]`, and `func indexWaterbodies()` (internal, so tests can call it).

- [ ] **Step 1: Write the failing test** in `FishingMapModelTests`:
```swift
    @Test @MainActor func anInlandLaunchBesideARiverGetsTheRiversRows() throws {
        let model = FishingMapModel()
        let river = River(name: "Test River", streamOrder: 4, lengthKm: 1,
                          lines: [[LonLat(longitude: -117.40, latitude: 47.66),
                                   LonLat(longitude: -117.39, latitude: 47.66)]])
        let row = SpeciesSeason(species: "Redband Trout", bestMonths: [8], note: "river row")
        model.guide = FisheryGuide(updated: "t", disclaimer: "d", wdfwURL: "https://wdfw.wa.gov",
                                   areas: [], freshwater: FreshwaterGuide(species: [], byWaterbody: ["Test River": [row]]))
        model.rivers = [river]
        let onRiver = AccessSite(facilityName: "River Ramp", countyName: "Spokane", hasLaunch: true,
                                 launchSurface: .gravel, hasRestrooms: false, directions: "",
                                 coordinate: LonLat(longitude: -117.395, latitude: 47.6605))
        let offRiver = AccessSite(facilityName: "Dry Ramp", countyName: "Spokane", hasLaunch: true,
                                  launchSurface: .gravel, hasRestrooms: false, directions: "",
                                  coordinate: LonLat(longitude: -117.395, latitude: 47.67))
        model.accessSites = [onRiver, offRiver]
        model.indexWaterbodies()
        #expect(model.siteWaterbody[onRiver.id] == "Test River")
        #expect(model.siteWaterbody[offRiver.id] == nil)
        #expect(model.fishery(for: onRiver)?.species.first?.note == "river row")
    }
```
  First check `FisheryGuide`'s memberwise init at `Fishery.swift:258` and match its labels exactly. If `seasonRisk` or other parameters have no defaults, pass `[]`.
- [ ] **Step 2:** Run TEST (`FishingMapModelTests`). Expect a build error: `indexWaterbodies` isn't defined.
- [ ] **Step 3: Implement.** Add the properties beside `siteAreaName`:
```swift
    /// Inland launch → the waterbody it sits on (curated list, else nearest river).
    /// Precomputed: resolving scans river geometry, too slow for every pin render.
    private(set) var siteWaterbody: [AccessSite.ID: String] = [:]
    private(set) var pierWaterbody: [FishingPier.ID: String] = [:]
```
  Add the builder beside `indexPiersToAreas()`. It skips marine sites, since those never read freshwater rows:
```swift
    /// Must run after the guide, rivers and marine-area indexes are in place.
    func indexWaterbodies() {
        let freshwater = guide?.freshwater
        var sites: [AccessSite.ID: String] = [:]
        for site in accessSites where siteAreaName[site.id] == nil {
            sites[site.id] = freshwater?.waterbody(forFacility: site.facilityName, at: site.coordinate, rivers: rivers)
        }
        siteWaterbody = sites
        var piersMap: [FishingPier.ID: String] = [:]
        for pier in piers where pierAreaName[pier.id] == nil {
            piersMap[pier.id] = freshwater?.waterbody(forFacility: pier.name, at: pier.coordinate, rivers: rivers)
        }
        pierWaterbody = piersMap
    }
```
  Call `indexWaterbodies()` right after `indexSitesToAreas()` at both call sites (:133, :159) and after `indexPiersToAreas()` (:188). In the two `fishery(for:)` functions, replace `waterbody: guide?.freshwater?.waterbody(forFacility: …)` with `waterbody: siteWaterbody[site.id]` and `waterbody: pierWaterbody[pier.id]`.
- [ ] **Step 4:** Run TEST. Expect `rc=0` and the new test passed. Then run the full suite (drop `-only-testing`): `rc=0`, with no previously passing test now failing.
- [ ] **Step 5: Measure the index cost** on the real bundle. Temporarily wrap `indexWaterbodies()` in `ContinuousClock().measure` and print; run the app on the simulator; read the log. Revert the timing code, and **check the revert applied** (`git diff` shows none). If it takes over 200 ms, add a per-river bounding-box prefilter as its own commit with a test. Otherwise record the number in the commit body.
- [ ] **Step 6:** Commit `FishingMapModel.swift FishingMapModelTests.swift`: "Index each inland site's waterbody once, including rivers".

### Task 4: The reachability gate knows about rivers

**Files:** Modify `WAFishMapTests/NoteScopeTests.swift:59-65`.

**Interfaces:** Consumes `RiverLoader.rivers(from:)` and the bundled `rivers.json` via `FixtureBundle.loader`. Produces `static func unreachableWaterbodyKeys(in freshwater: FreshwaterGuide, riverNames: Set<String>) -> [String]` (test-local).

- [ ] **Step 1: Write a known-bad test first:**
```swift
    static func unreachableWaterbodyKeys(in freshwater: FreshwaterGuide, riverNames: Set<String>) -> [String] {
        let keyed = Set(freshwater.waterbodySites?.keys ?? [:].keys).union(riverNames)
        return (freshwater.byWaterbody ?? [:]).keys.filter { !keyed.contains($0) }.sorted()
    }

    /// Proves the gate fires: a misspelled river is unreachable, a real one is not.
    @Test func theReachabilityGateCatchesAMisspelledRiver() {
        let row = SpeciesSeason(species: "Redband Trout", bestMonths: [8])
        let guide = FreshwaterGuide(species: [], byWaterbody: ["Spokane River": [row], "Spokan River": [row]])
        #expect(Self.unreachableWaterbodyKeys(in: guide, riverNames: ["Spokane River"]) == ["Spokan River"])
    }
```
- [ ] **Step 2:** Run TEST (`NoteScopeTests`). Expect it to pass: it is the detector's bad/good input pair, and it shows the gate fires on bad input and stays quiet on good. If it passes trivially because `guide` fails to build, fix that first.
- [ ] **Step 3:** Rewrite `everyWaterbodyRowHasAtLeastOneSiteThatCanReachIt` (rename it `everyWaterbodyRowIsReachable`) to use the helper, with river names from the bundle:
```swift
    @Test func everyWaterbodyRowIsReachable() throws {
        let freshwater = try #require(bundledGuide().freshwater)
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "rivers", withExtension: "json"))
        let names = Set(try RiverLoader.rivers(from: Data(contentsOf: url)).map(\.name))
        #expect(names.count > 200, "rivers.json did not load; the gate would pass vacuously")
        let orphans = Self.unreachableWaterbodyKeys(in: freshwater, riverNames: names)
        #expect(orphans.isEmpty, "waterbody notes no site can reach: \(orphans.joined(separator: ", "))")
    }
```
  Update that test's doc comment: the exemption holds because a key is either curated or an exact river name, never prose-matched. If `rivers.json` isn't in the test fixture bundle, `#require` fails loudly. Then add it to the test target's resources the same way `fisheries.json` is.
- [ ] **Step 4:** Run TEST. Expect `rc=0`, with both names passed.
- [ ] **Step 5:** Commit: "Let river names satisfy the waterbody reachability gate".

### Task 5: Spokane River row (WDFW-gated), docs, full verification

**Files:** Possibly `WAFishMap/Resources/fisheries.json` (`freshwater.byWaterbody`, `updated`), `WAFishMapTests/NoteScopeTests.swift` (the season-risk test), `CLAUDE.md` ("Notes are scoped"), `STATUS.md`.

- [ ] **Step 1: Check against WDFW.** Dispatch `research-analyst`: "Per current WDFW regulations and pages (cite URLs), is the Spokane River in Washington (Idaho line to the Columbia) catch-and-release for wild redband/rainbow trout along its whole length, and what months are open/best? Flag any reach where it differs." **Admit the row only if every reach agrees.**
- [ ] **Step 2a (admitted):** Add `"Spokane River": [ { species "Redband Trout", bestMonths/goodMonths from the source, note true river-wide } ]` to `byWaterbody`, and bump `updated` to `2026-09-16`. Extend `waterbodyRowsAreStampedWithSeasonRisk` to assert the Spokane row's `riskMonths` equals the matching `seasonRisk` entry, or is empty if none matches. Record the WDFW URLs in the STATUS decision log.
- [ ] **Step 2b (not admitted):** No data change. Record in the STATUS decision log why the row was refused, with URLs.
- [ ] **Step 3:** In `CLAUDE.md` "Notes are scoped", add after the tier list:
  `- freshwater.byWaterbody — one lake or river. Lakes resolve through the curated waterbodySites list; rivers resolve by name to any site within 150 m of the river line. A river is one feature end to end, so a river row must be true along the whole river.`
- [ ] **Step 4:** Run the full suite (TEST without `-only-testing`). Expect `rc=0`; confirm every test name from Tasks 1-4 passed in the log.
- [ ] **Step 5:** Run the `verifier` agent on the branch diff against the spec. Also run the app in the simulator (per `ios-build`), tap a launch on a river that has rows (or Baker Lake), and screenshot the sheet showing the river's row.
- [ ] **Step 6:** Commit the touched files. Flip `Waterbody tier keyed off river polylines` to `- [x] … — <sha>` in `TASKS.md` and point STATUS Next Up at the flow-stat gates.

## Slicing (TASKS.md)

After approval: save this plan to `docs/superpowers/plans/2026-09-16-river-waterbody-tier.md`, and replace the single TASKS.md line `Waterbody tier keyed off river polylines` with five sub-items:
- `River nearest-match within 150 m`
- `Waterbody resolver: curated list then river`
- `Model index for site and pier waterbodies`
- `Reachability gate accepts river names`
- `Spokane River row gated on WDFW, docs, verify`

Each slice ends in one commit, in order 1 through 5. Slices 1 and 2 are pure logic and safe for subagents; slice 5 needs the WDFW lookup and a simulator run.

## Verification

- Every slice runs its tests with `rc` captured, and new test names are confirmed passed.
- End-to-end: the full suite passes, the verifier agent checks against the spec, and a simulator screenshot shows a river row on a launch sheet.
