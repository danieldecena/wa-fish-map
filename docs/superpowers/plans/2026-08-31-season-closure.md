# Season/Closure Rating Cap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A species that is plausibly closed can never render as Prime, without the app ever asserting a season date.

**Architecture:** A central `seasonRisk` table in `fisheries.json` is matched to species by substring at load time, stamping `riskMonths`/`riskReason` onto each `SpeciesSeason`. `rating(inMonth:)` then clamps to `.fair` in a stamped month. The marker and heat overlay inherit the cap for free through `AreaFishery.rating(inMonth:)`.

**Tech Stack:** Swift 6, SwiftUI, swift-testing (`@Test` / `#expect`), Xcode 27 beta, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-08-31-season-closure-design.md`

## Global Constraints

- The app never states that a fishery is open or closed. Copy says "verify", never a date.
- `rating(inMonth:)` stays pure and clock-free: the view injects the month.
- No change to `FishingRating`, the legend, the marker colors, or the heat overlay.
- Tests use swift-testing (`import Testing`, `struct XTests`, `@Test func`), matching `WAFishMapTests/FisheryTests.swift`. Not XCTest.
- Existing tests must keep passing unchanged.
- Build/test destination: `platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8` (iPhone 17 Pro).

---

### Task 1: SeasonRisk type and match rule

**Files:**
- Create: `WAFishMap/Models/SeasonRisk.swift`
- Test: `WAFishMapTests/SeasonRiskTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct SeasonRisk: Decodable, Equatable, Sendable` with `let match: String`, `let months: [Int]`, `let reason: String`, and `func matches(_ speciesName: String) -> Bool`.

- [ ] **Step 1: Write the failing test**

Create `WAFishMapTests/SeasonRiskTests.swift`:

```swift
import Foundation
import Testing
@testable import WAFishMap

struct SeasonRiskTests {
    let chinook = SeasonRisk(
        match: "Chinook",
        months: [1, 2, 3],
        reason: "Selective-fishery and quota dates set annually"
    )

    @Test func matchesExactName() {
        #expect(chinook.matches("Chinook Salmon"))
    }

    @Test func matchesParentheticalVariants() {
        #expect(chinook.matches("Chinook Salmon (ocean)"))
        #expect(chinook.matches("Chinook Salmon (Tulalip)"))
        #expect(chinook.matches("Resident Chinook (Blackmouth)"))
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(chinook.matches("CHINOOK SALMON"))
        #expect(chinook.matches("chinook salmon"))
    }

    @Test func doesNotMatchUnrelatedSpecies() {
        #expect(!chinook.matches("Coho Salmon"))
        #expect(!chinook.matches("Rainbow Trout"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "error:|SeasonRisk"
```
Expected: FAIL — `cannot find 'SeasonRisk' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `WAFishMap/Models/SeasonRisk.swift`:

```swift
import Foundation

/// One curated "this fishery's season moves" flag, matched to species by name.
///
/// Deliberately coarse: it marks months in which a closure is *plausible* so the
/// rating can stop short of Prime. It is not a season date and must never be
/// presented as one.
struct SeasonRisk: Decodable, Equatable, Sendable {
    /// Case-insensitive substring tested against `SpeciesSeason.species`, so one
    /// row covers "Chinook Salmon", "(ocean)", "(Tulalip)" and "Resident Chinook".
    let match: String
    /// Months 1–12 in which a closure is plausible.
    let months: [Int]
    /// Short phrase shown to the user. Says why to verify, never a date.
    let reason: String

    func matches(_ speciesName: String) -> Bool {
        speciesName.range(of: match, options: .caseInsensitive) != nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "SeasonRiskTests|\*\* TEST"
```
Expected: `Suite SeasonRiskTests passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/Models/SeasonRisk.swift WAFishMapTests/SeasonRiskTests.swift
git commit -m "feat: SeasonRisk type with case-insensitive substring matching"
```

---

### Task 2: Cap the rating in a flagged month

**Files:**
- Modify: `WAFishMap/Models/Fishery.swift` (the `SpeciesSeason` struct)
- Test: `WAFishMapTests/FisheryTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1 — the fields are plain data.
- Produces: `SpeciesSeason.riskMonths: [Int]` (default `[]`), `SpeciesSeason.riskReason: String?` (default `nil`), and `func withRisk(months: [Int], reason: String?) -> SpeciesSeason`. `rating(inMonth:)` keeps its signature.

- [ ] **Step 1: Write the failing test**

Append to `WAFishMapTests/FisheryTests.swift` inside `struct FisheryTests`:

```swift
    @Test func flaggedMonthCapsPeakToFair() {
        let flagged = coho.withRisk(months: [9], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 9) == .fair)
    }

    @Test func unflaggedMonthKeepsFullRating() {
        let flagged = coho.withRisk(months: [9], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 10) == .excellent)
    }

    @Test func capNeverRaisesAWeakRating() {
        let flagged = coho.withRisk(months: [3], reason: "Quota-driven")
        #expect(flagged.rating(inMonth: 3) == .poor)
    }

    @Test func unstampedSpeciesIsUnaffected() {
        #expect(coho.riskMonths.isEmpty)
        #expect(coho.rating(inMonth: 9) == .excellent)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "error:"
```
Expected: FAIL — `value of type 'SpeciesSeason' has no member 'withRisk'`.

- [ ] **Step 3: Write minimal implementation**

In `WAFishMap/Models/Fishery.swift`, add two stored properties to `SpeciesSeason` after `note`:

```swift
    /// Months where a closure is plausible. Stamped at load from the `seasonRisk`
    /// table, never decoded from a species row.
    var riskMonths: [Int] = []
    /// Why verification is needed, shown beside the capped rating.
    var riskReason: String?
```

Add the copy helper below the initializers:

```swift
    /// A copy carrying the resolved season-risk flag.
    func withRisk(months: [Int], reason: String?) -> SpeciesSeason {
        var copy = self
        copy.riskMonths = months
        copy.riskReason = reason
        return copy
    }
```

Replace the body of `rating(inMonth:)` with:

```swift
    /// This species' rating in a given month: peak → good → shoulder → off, then
    /// clamped to `.fair` in a month where a closure is plausible.
    func rating(inMonth month: Int) -> FishingRating {
        let base: FishingRating
        if bestMonths.contains(month) {
            base = .excellent
        } else if goodMonths.contains(month) {
            base = .good
        } else {
            let onShoulder = (bestMonths + goodMonths)
                .contains { Self.circularMonthDistance($0, month) == 1 }
            base = onShoulder ? .fair : .poor
        }
        return riskMonths.contains(month) ? min(base, .fair) : base
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "FisheryTests|\*\* TEST"
```
Expected: `Suite FisheryTests passed`, `** TEST SUCCEEDED **`. Every pre-existing FisheryTests case must still pass — the cap is inert with an empty `riskMonths`.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/Models/Fishery.swift WAFishMapTests/FisheryTests.swift
git commit -m "feat: clamp a species rating to Fair in a closure-prone month"
```

---

### Task 3: Resolve the table onto the guide at load

**Files:**
- Modify: `WAFishMap/Models/Fishery.swift` (`FisheryGuide`, `AreaFishery`, `FreshwaterGuide`)
- Modify: `WAFishMap/Services/FisheryLoader.swift`
- Test: `WAFishMapTests/SeasonRiskTests.swift`

**Interfaces:**
- Consumes: `SeasonRisk.matches(_:)` from Task 1; `SpeciesSeason.withRisk(months:reason:)` from Task 2.
- Produces: `FisheryGuide.seasonRisk: [SeasonRisk]` (defaults to `[]` when the key is absent), `SpeciesSeason.seasonRiskOverride: String?` (decoded from a species row's `seasonRisk` key), and `func resolvingSeasonRisk() -> FisheryGuide`. `FisheryLoader.guide(from:)` keeps its signature and returns a resolved guide.

- [ ] **Step 1: Write the failing test**

Append to `WAFishMapTests/SeasonRiskTests.swift`:

```swift
struct SeasonRiskResolutionTests {
    /// Minimal guide JSON: one area, two species, one risk row.
    let json = """
    {
      "updated": "2026-08-31",
      "disclaimer": "d",
      "wdfwURL": "https://wdfw.wa.gov",
      "seasonRisk": [
        { "match": "Chinook", "months": [1, 2], "reason": "Quota-driven" }
      ],
      "areas": [
        {
          "areaName": "13",
          "species": [
            { "species": "Chinook Salmon", "bestMonths": [1] },
            { "species": "Rainbow Trout", "bestMonths": [1] }
          ]
        }
      ]
    }
    """.data(using: .utf8)!

    @Test func stampsMatchingSpeciesOnly() throws {
        let guide = try FisheryLoader.guide(from: json)
        let species = try #require(guide.area(named: "13")?.species)
        let chinook = try #require(species.first { $0.species == "Chinook Salmon" })
        let trout = try #require(species.first { $0.species == "Rainbow Trout" })
        #expect(chinook.riskMonths == [1, 2])
        #expect(chinook.riskReason == "Quota-driven")
        #expect(trout.riskMonths.isEmpty)
        #expect(trout.riskReason == nil)
    }

    @Test func cappedSpeciesDragsTheAreaRatingDown() throws {
        let guide = try FisheryLoader.guide(from: json)
        let area = try #require(guide.area(named: "13"))
        // Trout is unflagged and peaks in January, so the area stays Prime.
        #expect(area.rating(inMonth: 1) == .excellent)
    }

    @Test func areaOfOnlyFlaggedSpeciesCapsToFair() throws {
        let onlyChinook = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [{ "match": "Chinook", "months": [1], "reason": "r" }],
          "areas": [{ "areaName": "13",
            "species": [{ "species": "Chinook Salmon", "bestMonths": [1] }] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: onlyChinook)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .fair)
    }

    @Test func rowCanOptOutOfTheTable() throws {
        let optOut = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "seasonRisk": [{ "match": "Chinook", "months": [1], "reason": "r" }],
          "areas": [{ "areaName": "13", "species": [
            { "species": "Chinook Salmon", "bestMonths": [1], "seasonRisk": "none" }
          ] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: optOut)
        let species = try #require(guide.area(named: "13")?.species.first)
        #expect(species.riskMonths.isEmpty)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .excellent)
    }

    @Test func guideWithoutTableIsUnchanged() throws {
        let noTable = """
        {
          "updated": "2026-08-31", "disclaimer": "d", "wdfwURL": "u",
          "areas": [{ "areaName": "13",
            "species": [{ "species": "Chinook Salmon", "bestMonths": [1] }] }]
        }
        """.data(using: .utf8)!
        let guide = try FisheryLoader.guide(from: noTable)
        #expect(guide.area(named: "13")?.rating(inMonth: 1) == .excellent)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "error:"
```
Expected: FAIL — `value of type 'SpeciesSeason' has no member 'riskMonths'` is already resolved by Task 2, so the real failure is `stampsMatchingSpeciesOnly` returning empty `riskMonths` because nothing resolves yet.

- [ ] **Step 3: Write minimal implementation**

In `WAFishMap/Models/Fishery.swift`, add to `AreaFishery`:

```swift
    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> AreaFishery {
        AreaFishery(areaName: areaName, species: species.map { $0.resolvingSeasonRisk(table) })
    }
```

Add to `SpeciesSeason` a decoded opt-out, alongside the existing fields. Add
`seasonRisk` to its `CodingKeys` and decode it in `init(from:)`:

```swift
    /// A row sets `"seasonRisk": "none"` where this area is open while its
    /// neighbours are not. The central table cannot express that; this is the
    /// escape hatch, applied case by case as it is discovered.
    let seasonRiskOverride: String?
```

```swift
    // in CodingKeys
    case species, bestMonths, goodMonths, bait, bestTime, note
    case seasonRisk

    // in init(from:)
    seasonRiskOverride = try c.decodeIfPresent(String.self, forKey: .seasonRisk)
```

The memberwise `init` gains `seasonRiskOverride: String? = nil` so existing
call sites and tests keep compiling unchanged.

Then add the resolver:

```swift
    /// Union the months of every matching row; join distinct reasons with "; ".
    /// An explicit "none" on the row beats any table match.
    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> SpeciesSeason {
        guard seasonRiskOverride?.lowercased() != "none" else { return self }
        let hits = table.filter { $0.matches(species) }
        guard !hits.isEmpty else { return self }
        let months = Array(Set(hits.flatMap(\.months))).sorted()
        var reasons: [String] = []
        for hit in hits where !reasons.contains(hit.reason) { reasons.append(hit.reason) }
        return withRisk(months: months, reason: reasons.joined(separator: "; "))
    }
```

Add to `FreshwaterGuide`:

```swift
    func resolvingSeasonRisk(_ table: [SeasonRisk]) -> FreshwaterGuide {
        FreshwaterGuide(
            species: species.map { $0.resolvingSeasonRisk(table) },
            byCounty: byCounty?.mapValues { $0.map { $0.resolvingSeasonRisk(table) } }
        )
    }
```

`FreshwaterGuide` has no memberwise initializer today because it only decodes; add one:

```swift
    init(species: [SpeciesSeason], byCounty: [String: [SpeciesSeason]]?) {
        self.species = species
        self.byCounty = byCounty
    }
```

Add to `FisheryGuide` — the property, a defaulting decoder, an initializer, and the resolver:

```swift
    let seasonRisk: [SeasonRisk]

    private enum CodingKeys: String, CodingKey {
        case updated, disclaimer, wdfwURL, areas, freshwater, seasonRisk
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updated = try c.decode(String.self, forKey: .updated)
        disclaimer = try c.decode(String.self, forKey: .disclaimer)
        wdfwURL = try c.decode(String.self, forKey: .wdfwURL)
        areas = try c.decodeIfPresent([AreaFishery].self, forKey: .areas) ?? []
        freshwater = try c.decodeIfPresent(FreshwaterGuide.self, forKey: .freshwater)
        seasonRisk = try c.decodeIfPresent([SeasonRisk].self, forKey: .seasonRisk) ?? []
    }

    init(updated: String, disclaimer: String, wdfwURL: String,
         areas: [AreaFishery], freshwater: FreshwaterGuide?, seasonRisk: [SeasonRisk]) {
        self.updated = updated
        self.disclaimer = disclaimer
        self.wdfwURL = wdfwURL
        self.areas = areas
        self.freshwater = freshwater
        self.seasonRisk = seasonRisk
    }

    /// Stamp every species with its resolved risk months. Done once at load so
    /// matching costs nothing per render.
    func resolvingSeasonRisk() -> FisheryGuide {
        guard !seasonRisk.isEmpty else { return self }
        return FisheryGuide(
            updated: updated,
            disclaimer: disclaimer,
            wdfwURL: wdfwURL,
            areas: areas.map { $0.resolvingSeasonRisk(seasonRisk) },
            freshwater: freshwater?.resolvingSeasonRisk(seasonRisk),
            seasonRisk: seasonRisk
        )
    }
```

`AreaFishery` also needs a memberwise initializer if the compiler no longer synthesizes one; add it beside the struct's properties:

```swift
    init(areaName: String, species: [SpeciesSeason]) {
        self.areaName = areaName
        self.species = species
    }
```

In `WAFishMap/Services/FisheryLoader.swift`, resolve after decoding:

```swift
    static func guide(from data: Data) throws -> FisheryGuide {
        try JSONDecoder().decode(FisheryGuide.self, from: data).resolvingSeasonRisk()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "SeasonRiskResolutionTests|\*\* TEST"
```
Expected: `Suite SeasonRiskResolutionTests passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/Models/Fishery.swift WAFishMap/Services/FisheryLoader.swift WAFishMapTests/SeasonRiskTests.swift
git commit -m "feat: resolve the seasonRisk table onto every species at load"
```

---

### Task 4: Curate the seasonRisk table

**Files:**
- Modify: `WAFishMap/Resources/fisheries.json`
- Test: `WAFishMapTests/SeasonRiskTests.swift`

**Interfaces:**
- Consumes: the schema from Tasks 1 and 3.
- Produces: no new API. The shipped guide now carries a populated `seasonRisk`.

**Source material:** the 42 species entries whose `note` already describes a
closure. Find them with:

```bash
grep -n '"note"' WAFishMap/Resources/fisheries.json | grep -iE 'clos|quota|selective|release-only|announced|season'
```

Derive months from that prose only. Where the prose gives no months, flag the
whole season the species is otherwise rated for — never invent a date.

- [ ] **Step 1: Write the failing test**

Append to `WAFishMapTests/SeasonRiskTests.swift`:

```swift
struct ShippedSeasonRiskTests {
    func loadShipped() throws -> FisheryGuide {
        let url = try #require(Bundle.main.url(forResource: "fisheries", withExtension: "json"))
        return try FisheryLoader.guide(from: Data(contentsOf: url))
    }

    @Test func shippedGuideCarriesATable() throws {
        #expect(try !loadShipped().seasonRisk.isEmpty)
    }

    @Test func everyRowHasMonthsAndAReason() throws {
        for row in try loadShipped().seasonRisk {
            #expect(!row.months.isEmpty, "\(row.match) has no months")
            #expect(!row.reason.isEmpty, "\(row.match) has no reason")
            #expect(row.months.allSatisfy { (1...12).contains($0) }, "\(row.match) month out of range")
        }
    }

    @Test func noReasonStatesADate() throws {
        // The reason explains why to verify; it must not read as a season date.
        for row in try loadShipped().seasonRisk {
            #expect(!row.reason.contains("–"), "\(row.match) reason looks like a date range")
            #expect(row.reason.range(of: #"\b\d{1,2}/\d{1,2}\b"#, options: .regularExpression) == nil,
                    "\(row.match) reason contains a date")
        }
    }

    @Test func freshwaterStaplesAreNotFlagged() throws {
        let guide = try loadShipped()
        for name in ["Rainbow Trout", "Smallmouth Bass", "Walleye", "Channel Catfish"] {
            #expect(!guide.seasonRisk.contains { $0.matches(name) }, "\(name) should stay unflagged")
        }
    }

    @Test func salmonAndShellfishAreFlagged() throws {
        let guide = try loadShipped()
        for name in ["Chinook Salmon", "Coho Salmon (ocean)", "Dungeness Crab", "Lingcod"] {
            #expect(guide.seasonRisk.contains { $0.matches(name) }, "\(name) should be flagged")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "ShippedSeasonRiskTests|\*\* TEST"
```
Expected: FAIL — `shippedGuideCarriesATable` fails, the table is absent.

- [ ] **Step 3: Add the table**

Insert `seasonRisk` into `WAFishMap/Resources/fisheries.json` immediately after
the `wdfwURL` line, and bump `updated` to the day you do the work. Start from
this set and extend it only where the `note` prose in the file supports it:

```json
  "seasonRisk": [
    { "match": "Chinook", "months": [1,2,3,4,5,6,7,8,9,10,11,12],
      "reason": "Selective-fishery rules and season dates set annually" },
    { "match": "Coho", "months": [7,8,9,10,11],
      "reason": "Quota-driven; dates set annually" },
    { "match": "Sockeye", "months": [6,7,8],
      "reason": "Opens only when the return supports it" },
    { "match": "Pink Salmon", "months": [7,8,9],
      "reason": "Odd-year fishery; rules set annually" },
    { "match": "Chum", "months": [10,11,12],
      "reason": "Terminal-area rules vary; confirm before you go" },
    { "match": "Halibut", "months": [5,6,7,8],
      "reason": "A few announced days, quota-driven" },
    { "match": "Lingcod", "months": [3,4,5,6,7],
      "reason": "Bottomfish opener with area and depth limits" },
    { "match": "Rockfish", "months": [5,6,7],
      "reason": "Some species closed; yelloweye is release-only" },
    { "match": "Crab", "months": [6,7,8,9,10],
      "reason": "Season and areas set annually by WDFW" },
    { "match": "Shrimp", "months": [5,6],
      "reason": "A few announced days, quota-driven" },
    { "match": "Razor Clam", "months": [10,11,12,1,2,3,4,5],
      "reason": "Digs announced only after marine-toxin testing" },
    { "match": "Albacore", "months": [7,8,9,10],
      "reason": "Offshore and weather-dependent" }
  ],
```

Verify the JSON still parses before running the suite:

```bash
python3 -c "import json;json.load(open('WAFishMap/Resources/fisheries.json'));print('json valid')"
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "ShippedSeasonRiskTests|\*\* TEST"
```
Expected: `Suite ShippedSeasonRiskTests passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/Resources/fisheries.json WAFishMapTests/SeasonRiskTests.swift
git commit -m "data: flag closure-prone species with seasonRisk months"
```

---

### Task 5: Show the verify badge on a capped species

**Files:**
- Modify: `WAFishMap/SiteDetailSheet.swift`
- Test: manual, on the simulator — this is view code with no logic left to unit-test.

**Interfaces:**
- Consumes: `SpeciesSeason.riskMonths` and `.riskReason` from Task 2.
- Produces: no new API.

- [ ] **Step 1: Add the badge**

In `WAFishMap/SiteDetailSheet.swift`, inside the species card where
`RatingBadge(rating: s.rating(inMonth: month))` is rendered (around line 53),
add immediately after the `RatingBadge`:

```swift
                            if s.riskMonths.contains(month) {
                                Label("Season varies — verify", systemImage: "exclamationmark.triangle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
```

And under the existing `bestTime` label, add the reason:

```swift
                        if s.riskMonths.contains(month), let why = s.riskReason {
                            Text(why)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
```

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' build 2>&1 | grep -E "error:|\*\* BUILD"
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify on the simulator**

```bash
xcrun simctl launch 4B294677-5DB5-402C-9B02-3B85BACB8EA8 com.danieldecena.WAFishMap
```

Tap a saltwater launch in Puget Sound. Expected: a salmon or crab entry shows
the "Season varies — verify" badge with its reason underneath, and its rating
badge reads Fair rather than Prime. A freshwater bass or trout entry shows no
badge. Screenshot with:

```bash
xcrun simctl io 4B294677-5DB5-402C-9B02-3B85BACB8EA8 screenshot verify.png
```

Note: the simulator's renderer has failed mid-session before, producing a blank
screen with the app still running. If that happens, `xcrun simctl shutdown` then
`boot` the device and relaunch — it is not a code fault.

- [ ] **Step 4: Run the full suite**

Run:
```bash
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,id=4B294677-5DB5-402C-9B02-3B85BACB8EA8' test 2>&1 | grep -E "\*\* TEST|failed"
```
Expected: `** TEST SUCCEEDED **`, with every pre-existing suite still passing.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/SiteDetailSheet.swift
git commit -m "feat: badge a capped species with its verify reason"
```

---

## Verification

End to end, after all five tasks:

1. `xcodebuild ... test` passes, including the four pre-existing suites untouched by this work.
2. Launch the app in August and tap a Puget Sound launch: salmon entries read Fair with a verify badge, not Prime.
3. Toggle the plan date to a month outside a species' flagged range and confirm it recovers its full rating.
4. Confirm a freshwater lake launch is unchanged — no badges, ratings identical to before this feature.
5. Confirm the marker colour for a marine area whose only peak species is flagged has dropped from red (Prime) to purple (Fair).
