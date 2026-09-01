# Waterbody-Scoped Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop county-scoped species notes from making claims that are only true of one waterbody, and add a gate so the defect cannot return.

**Architecture:** The bug is data, not logic. `FreshwaterGuide.byCounty["King"]` carries a Yellow Perch note reading "Lake Washington; huge population, schools deep in fall/winter." A county is not a waterbody — King County holds Lake Washington, Lake Sammamish, Lake Dolloff and the Green River — so that sentence renders at every freshwater site in the county. Fix is two halves: reword the county notes so they are true county-wide, then add a test that fails when any non-area note names a specific waterbody. The area tier keeps its waterbody names, because a WDFW marine area genuinely is a place.

**Tech Stack:** Swift 6, Swift Testing (`@Test` / `#expect`), Xcode project, `xcodebuild test`.

**Spec:** No separate spec. The defect is recorded in `/Users/home/Developer/TASKS-apple-services.md` section 1, and reproduced by the Lake Dolloff screenshot from 2026-09-01.

## Global Constraints

- Swift Testing only — `import Testing`, `@Test func`, `#expect`. No XCTest.
- Test data files are loaded through `FixtureBundle.loader`, never `Bundle.main` in new tests.
- `WAFishMap/Resources/fisheries.json` is curated editorial data. Change wording, never invent months, bait, or species.
- Notes are guidance, never a statement of open seasons. Do not add anything that reads as a regulation.
- Run the suite with:
  `xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

---

### Task 1: A gate that fails on the shipped data

Write the check first and watch it catch the real defect. If it passes before the data is fixed, the check is wrong.

**Files:**
- Create: `WAFishMapTests/NoteScopeTests.swift`
- Test: `WAFishMapTests/NoteScopeTests.swift`

**Interfaces:**
- Consumes: `FisheryLoader.guide(from:) throws -> FisheryGuide`, `FisheryGuide.freshwater: FreshwaterGuide?`, `FreshwaterGuide.species: [SpeciesSeason]`, `FreshwaterGuide.byCounty: [String: [SpeciesSeason]]?`, `SpeciesSeason.note: String?`, `FixtureBundle.loader`
- Produces: `NoteScopeTests.waterbodyPattern` — a `Regex` other tests may reuse. Nothing else depends on this task.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import WAFishMap

/// A note attached to the statewide or county tier is shown at every site in
/// that scope. Naming one waterbody there is a claim about a place the reader
/// is not standing in: the King County Yellow Perch note read "Lake Washington;
/// huge population" and rendered at Lake Dolloff in Federal Way, twenty miles
/// away, on 2026-09-01.
///
/// The area tier is deliberately exempt. A WDFW marine area IS a place, so
/// "Elliott Bay / Central Sound spring selective fishery" on area 10 is correct.
struct NoteScopeTests {

    /// A proper noun immediately followed by a waterbody word. Matches
    /// "Lake Washington" and "Green River"; does not match the generic
    /// "Lowland lakes" or "warm-water bite", which are true anywhere.
    static let waterbodyPattern = /\b([A-Z][a-z]+)\s+(Lake|River|Bay|Sound|Creek|Reservoir)\b|\b(Lake|Mount)\s+[A-Z][a-z]+/

    private func offenders(in species: [SpeciesSeason], scope: String) -> [String] {
        species.compactMap { s in
            guard let note = s.note,
                  note.firstMatch(of: Self.waterbodyPattern) != nil else { return nil }
            return "\(scope) / \(s.species): \(note)"
        }
    }

    @Test func statewideNotesNameNoWaterbody() throws {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "fisheries", withExtension: "json"))
        let guide = try FisheryLoader.guide(from: Data(contentsOf: url))
        let freshwater = try #require(guide.freshwater)
        let bad = offenders(in: freshwater.species, scope: "statewide")
        #expect(bad.isEmpty, "statewide notes must hold anywhere in WA:\n\(bad.joined(separator: "\n"))")
    }

    @Test func countyNotesNameNoWaterbody() throws {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "fisheries", withExtension: "json"))
        let guide = try FisheryLoader.guide(from: Data(contentsOf: url))
        let freshwater = try #require(guide.freshwater)
        var bad: [String] = []
        for (county, species) in (freshwater.byCounty ?? [:]).sorted(by: { $0.key < $1.key }) {
            bad += offenders(in: species, scope: county)
        }
        #expect(bad.isEmpty, "county notes must hold anywhere in the county:\n\(bad.joined(separator: "\n"))")
    }

    /// Proves the pattern fires, so a passing suite means the data is clean
    /// rather than the regex being broken.
    @Test func patternCatchesAWaterbodyAndSparesGenericProse() {
        #expect("Lake Washington; huge population".firstMatch(of: Self.waterbodyPattern) != nil)
        #expect("Green River hatchery run".firstMatch(of: Self.waterbodyPattern) != nil)
        #expect("Lowland lakes; many open year-round.".firstMatch(of: Self.waterbodyPattern) == nil)
        #expect("Warm-water bite late spring through summer.".firstMatch(of: Self.waterbodyPattern) == nil)
    }
}
```

- [ ] **Step 2: Run the tests and verify two fail**

Run: `xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:WAFishMapTests/NoteScopeTests`

Expected: `patternCatchesAWaterbodyAndSparesGenericProse` PASSES.
`countyNotesNameNoWaterbody` FAILS, listing:
```
King / Yellow Perch: Lake Washington; huge population, schools deep in fall/winter.
King / Coho Salmon: Lake Washington fall coho only in years with a healthy run; sockeye has been closed for years.
```
`statewideNotesNameNoWaterbody` PASSES — the statewide rows are already clean, which is worth confirming rather than assuming.

If `countyNotesNameNoWaterbody` passes here, stop: the regex is not matching and the rest of this plan would ship a gate that guards nothing.

- [ ] **Step 3: Commit the failing gate**

```bash
git add WAFishMapTests/NoteScopeTests.swift
git commit -m "test: gate county and statewide notes against waterbody-specific claims

Fails on the shipped data, which is the point. King County's Yellow Perch
note reads 'Lake Washington; huge population' and renders at Lake Dolloff."
```

---

### Task 2: Reword the King County notes

**Files:**
- Modify: `WAFishMap/Resources/fisheries.json` — `freshwater.byCounty.King`, the `note` field on the `Yellow Perch` and `Coho Salmon` rows only

**Interfaces:**
- Consumes: nothing. Pure data edit.
- Produces: nothing. Task 1's tests are the only consumer.

- [ ] **Step 1: Confirm exactly what is there now**

Run:
```bash
cd /Users/home/Developer/wa-fish-map
python3 -c "
import json
d = json.load(open('WAFishMap/Resources/fisheries.json'))
for s in d['freshwater']['byCounty']['King']:
    print(repr(s['species']), '->', repr(s.get('note')))
"
```

Expected:
```
'Yellow Perch' -> 'Lake Washington; huge population, schools deep in fall/winter.'
'Coho Salmon' -> 'Lake Washington fall coho only in years with a healthy run; sockeye has been closed for years.'
```

- [ ] **Step 2: Rewrite both notes so they are true county-wide**

Edit `WAFishMap/Resources/fisheries.json`. In `freshwater.byCounty.King`, replace the two `note` values:

Yellow Perch — from:
```json
"note": "Lake Washington; huge population, schools deep in fall/winter."
```
to:
```json
"note": "Common in the county's lowland lakes; schools move deep in fall and winter."
```

Coho Salmon — from:
```json
"note": "Lake Washington fall coho only in years with a healthy run; sockeye has been closed for years."
```
to:
```json
"note": "Fall run only in years the return supports it; confirm the waterbody before you go."
```

Both keep the substance — perch school deep late in the year, coho is run-dependent — and drop the claim about which lake. Change nothing else on these rows: `bestMonths`, `bestTime`, `bait` and `seasonRisk` stay exactly as they are.

- [ ] **Step 3: Verify the JSON still parses and the values landed**

Run:
```bash
cd /Users/home/Developer/wa-fish-map
python3 -c "
import json
d = json.load(open('WAFishMap/Resources/fisheries.json'))
k = d['freshwater']['byCounty']['King']
assert len(k) == 2, f'expected 2 King rows, got {len(k)}'
for s in k:
    assert 'Lake Washington' not in (s.get('note') or ''), s
    assert s['bestMonths'], f'{s[\"species\"]} lost its months'
print('ok:', [s['species'] for s in k])
"
```

Expected: `ok: ['Yellow Perch', 'Coho Salmon']`

- [ ] **Step 4: Run the gate and verify it now passes**

Run: `xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:WAFishMapTests/NoteScopeTests`

Expected: all three tests PASS.

- [ ] **Step 5: Run the whole suite for regressions**

Run: `xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: every test passes. `FisheryTests.bundledGuideDecodesAndHasArea13` and the `SeasonRiskTests` case that reads `fisheries.json` both touch this file, so they are the ones to watch.

- [ ] **Step 6: Commit**

```bash
git add WAFishMap/Resources/fisheries.json
git commit -m "fix: King County notes no longer claim Lake Washington

A county note renders at every freshwater site in the county. Lake Dolloff
in Federal Way was showing 'Lake Washington; huge population' on its Yellow
Perch card. Both notes now say what is true across King County."
```

---

### Task 3: Record the rule where the data is edited

The gate catches the defect at test time. This makes the rule visible to whoever next writes a note, which is cheaper than a failing build.

**Files:**
- Modify: `/Users/home/Developer/wa-fish-map/CLAUDE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Append the rule**

Add to `CLAUDE.md`:

```markdown
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
the note sat on the King County override.

If a claim is only true of one lake, it does not belong in this file at all
until the data model has a waterbody tier.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record the note-scoping rule that NoteScopeTests enforces"
```

---

## Out of scope, deliberately

**The 477-site water-type audit.** The Dash Point Park Pier mis-classification is a different defect — a site tagged freshwater when it is saltwater — and it needs marine-area geometry to validate against, not a regex over prose. It deserves its own plan and should not ride along here.

**A waterbody tier in the data model.** Adding one would let the Lake Washington note come back correctly scoped. It is the right long-term shape and the wrong thing to build now: there is no per-waterbody data to fill it, so it would ship an empty dimension. Revisit when a second note needs it.

## Self-review

- **Coverage:** the defect is the King County note; Task 1 gates it, Task 2 fixes it, Task 3 documents it. The statewide tier is checked too, and confirmed already clean.
- **Placeholders:** none. Every note string, assertion and command is literal.
- **Type consistency:** `waterbodyPattern` is declared `static` in Task 1 and referenced as `Self.waterbodyPattern` throughout that same file. `offenders(in:scope:)` takes `[SpeciesSeason]` and returns `[String]` at both call sites. `FixtureBundle.loader` matches the existing usage in `FisheryTests.swift:82`.
- **Known risk:** the regex is prose matching and will not catch a waterbody named without its noun, such as "Sammamish" alone. Task 1's third test proves the pattern fires on the forms that actually appear; a name that slips past is a gap to widen the pattern for, not a reason to skip the gate.
