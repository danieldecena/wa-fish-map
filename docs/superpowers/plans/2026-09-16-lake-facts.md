# Lake Facts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show WDFW's official facts for the lake a launch sits on (acres, elevation, ramp, access, management, species) on the launch detail sheet.

**Architecture:** A stdlib Python generator bundles WDFW's 2014 lowland-lakes points plus 15 species layers into `lakes.json`. A pure Swift `Lake.match` links a launch to at most one lake by acreage-scaled distance, refusing ambiguous and name-contradicted matches. `FishingMapModel` indexes launches to lakes next to its waterbody index, and `SiteDetailSheet` renders a `LakeFactsSection` when a lake matched.

**Tech Stack:** Python 3 stdlib, Swift 6 / SwiftUI, Swift Testing, Xcode file-system-synchronized groups (new files under `WAFishMap/` and `WAFishMapTests/` are picked up without editing `project.pbxproj`).

**Spec:** `docs/superpowers/specs/2026-09-16-lake-facts-design.md`

## Global Constraints

- Source service: `https://geodataservices.wdfw.wa.gov/arcgis/rest/services/ApplicationServices/FishWA_2014_AllLakes_PROD/MapServer`, layer 2 lakes, layers 4-18 species.
- Species join by exact point geometry rounded to 6 decimal places (verified 2026-09-16: 653 lakes, 653 unique coordinates; only 3 species rows unjoined, all with null `LakeName`, in layers 4, 8, 10).
- Match reach: `1.5 * r + 400 m`, `r = sqrt(acres * 4046.86 / pi)`. Null acres never match. More than one lake in reach -> nil.
- Name check words ignored: `lake lakes pond ponds reservoir the upper lower north south east west of`.
- Sheet footnote text, verbatim: `From WDFW's lowland lakes map (2014). Species listed are not a stocking or season guarantee.`
- Guidance, not regulation: no season, bag-limit or open/closed claims in the new section.
- Every `xcodebuild` run goes through the `ios-build` skill first. Destination `platform=iOS Simulator,name=iPhone`. Never pipe `xcodebuild`; write to a log and take `rc=$?`.
- Python: `/opt/homebrew/bin/python3` (no venv here); run `ruff check` and `ruff format --check` on the new script.
- `WAFishMap/FishingMapView.swift` may carry another session's uncommitted edits. Commit with an explicit pathspec only; never `git add -A`.
- Commits end with the session attribution lines from the system reminder.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/build_lakes.py` (create) | Fetch WDFW lakes + species, join, guard counts, write deterministic JSON |
| `WAFishMap/Resources/lakes.json` (generated) | Bundled lake facts |
| `WAFishMap/Models/Lake.swift` (create) | `Lake` value type, distance reach, name check, `match` |
| `WAFishMap/Services/LakeLoader.swift` (create) | Decode `lakes.json` |
| `WAFishMap/Services/FishingMapModel.swift` (modify) | Load lakes, index launch -> lake, `lake(for:)` |
| `WAFishMap/SiteDetailSheet.swift` (modify) | `LakeFactsSection`, new `lake` parameter |
| `WAFishMap/FishingMapView.swift:113-121` (modify) | Pass `model.lake(for: site)` |
| `WAFishMapTests/LakeTests.swift` (create) | Name check, matching, bundled-file gate |
| `WAFishMapTests/FishingMapModelTests.swift` (modify) | Model indexes a lake launch |

---

### Task 1: Generator and bundled `lakes.json`

**Files:**
- Create: `scripts/build_lakes.py`
- Generate: `WAFishMap/Resources/lakes.json`

**Interfaces:**
- Produces: `lakes.json` shaped `{"source": str, "snapshot": "WDFW FishWA lowland lakes (2014)", "lakes": [Lake]}` where each lake has keys `name, county, longitude, latitude, species` always, and `acres, elevationFeet, management, shorelineAccess, boatRamp, websiteURL` only when non-empty. `species` is in WDFW layer order (4 -> 18). Lakes sorted by `(name, longitude, latitude)`.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Generate WAFishMap/Resources/lakes.json from WDFW's lowland lakes map.

WDFW publishes lakes as *points* (one per lake), with a separate point layer per
species holding the lakes that species is listed for. Species rows are joined to
lakes by exact coordinate, not by name + county: four name + county pairs repeat
(two Trout Lakes in King County, for one), so a name join would hand one lake's
species to its namesake. On 2026-09-16 all 653 lake points had unique
coordinates and the only unjoined species rows were three with a null LakeName.

The service is named 2014 and is treated as a static snapshot, which is why this
is bundled rather than fetched: the sheet needs no network and tests are
repeatable.

Output is deterministic: lakes sorted by name then coordinate, species in layer
order, coordinates rounded to COORD_PLACES.

    ./scripts/build_lakes.py [--out PATH]
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

SERVICE = (
    "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/"
    "ApplicationServices/FishWA_2014_AllLakes_PROD/MapServer"
)
LAKES_LAYER = 2
SPECIES_LAYERS = {
    4: "Rainbow Trout",
    5: "Brown Trout",
    6: "Brook Trout",
    7: "Tiger Trout",
    8: "Coastal Cutthroat",
    9: "Kokanee",
    10: "Largemouth Bass",
    11: "Smallmouth Bass",
    12: "Walleye",
    13: "Tiger Muskie",
    14: "Brown Bullhead",
    15: "Yellow Perch",
    16: "Black Crappie",
    17: "Pumpkinseed",
    18: "Bluegill",
}
COORD_PLACES = 6
MIN_LAKES = 600
MUST_HAVE = ("Lake Dolloff", "Lake Washington", "Steele Lake")
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "WAFishMap/Resources/lakes.json"


def query(layer: int, fields: str) -> list[dict]:
    params = urllib.parse.urlencode(
        {"where": "1=1", "outFields": fields, "outSR": "4326", "f": "json"}
    )
    with urllib.request.urlopen(f"{SERVICE}/{layer}/query?{params}", timeout=60) as r:
        body = json.load(r)
    if "error" in body:
        sys.exit(f"layer {layer}: {body['error']}")
    if body.get("exceededTransferLimit"):
        sys.exit(f"layer {layer}: exceededTransferLimit, output would be truncated")
    return body["features"]


def point(feature: dict) -> tuple[float, float]:
    g = feature["geometry"]
    return (round(g["x"], COORD_PLACES), round(g["y"], COORD_PLACES))


def text(value: object) -> str | None:
    if value is None:
        return None
    s = str(value).strip()
    return s or None


def build() -> dict:
    lakes: dict[tuple[float, float], dict] = {}
    for f in query(
        LAKES_LAYER,
        "LakeName,CountyName,ELEV,SurfaceAcres,PublicManagementType,"
        "ShorelineAccess,BoatRampAvailable,WebsiteURL",
    ):
        a = f["attributes"]
        lon, lat = point(f)
        lake = {
            "name": text(a["LakeName"]),
            "county": text(a["CountyName"]),
            "longitude": lon,
            "latitude": lat,
            "acres": a["SurfaceAcres"],
            "elevationFeet": a["ELEV"],
            "management": text(a["PublicManagementType"]),
            "shorelineAccess": text(a["ShorelineAccess"]),
            "boatRamp": text(a["BoatRampAvailable"]),
            "websiteURL": text(a["WebsiteURL"]),
            "species": [],
        }
        if lake["name"] is None or lake["county"] is None:
            sys.exit(f"lake at {(lon, lat)} has no name or county: {a}")
        if (lon, lat) in lakes:
            sys.exit(f"two lakes share coordinate {(lon, lat)}; the species join needs them unique")
        lakes[(lon, lat)] = {k: v for k, v in lake.items() if v is not None}

    skipped_null = 0
    for layer, species in SPECIES_LAYERS.items():
        rows = query(layer, "LakeName")
        if not rows:
            sys.exit(f"species layer {layer} ({species}) returned no rows")
        for f in rows:
            if f["attributes"]["LakeName"] is None:
                skipped_null += 1
                continue
            lake = lakes.get(point(f))
            if lake is None:
                sys.exit(f"{species} row {f['attributes']['LakeName']!r} matches no lake point")
            lake["species"].append(species)

    if len(lakes) < MIN_LAKES:
        sys.exit(f"only {len(lakes)} lakes, expected at least {MIN_LAKES}")
    names = {lake["name"] for lake in lakes.values()}
    missing = [n for n in MUST_HAVE if n not in names]
    if missing:
        sys.exit(f"expected lakes missing: {missing}")

    print(f"{len(lakes)} lakes, {skipped_null} null-name species rows skipped", file=sys.stderr)
    ordered = sorted(lakes.values(), key=lambda x: (x["name"], x["longitude"], x["latitude"]))
    return {
        "source": SERVICE,
        "snapshot": "WDFW FishWA lowland lakes (2014)",
        "lakes": ordered,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    data = build()
    args.out.write_text(json.dumps(data, indent=1, ensure_ascii=False, sort_keys=False) + "\n")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Prove the guard fires before trusting it**

Temporarily set `MUST_HAVE = ("Lake Dolloff", "No Such Lake")`, run
`/opt/homebrew/bin/python3 scripts/build_lakes.py --out "$TMPDIR/lakes-bad.json"; echo rc=$?`.
Expected: `expected lakes missing: ['No Such Lake']`, `rc=1`, no file written. Assert the edit applied (`grep -n "No Such Lake" scripts/build_lakes.py`) before reading the result, then revert it.

- [ ] **Step 3: Generate for real, twice**

```bash
chmod +x scripts/build_lakes.py
/opt/homebrew/bin/python3 scripts/build_lakes.py; echo rc=$?
shasum WAFishMap/Resources/lakes.json
/opt/homebrew/bin/python3 scripts/build_lakes.py; echo rc=$?
shasum WAFishMap/Resources/lakes.json
```
Expected: `653 lakes, 3 null-name species rows skipped`, `rc=0` both times, identical hashes.

- [ ] **Step 4: Spot-check content**

```bash
/opt/homebrew/bin/python3 -c "import json;d=json.load(open('WAFishMap/Resources/lakes.json'));print(len(d['lakes']));print([l for l in d['lakes'] if l['name']=='Lake Dolloff'])"
```
Expected: `653` and one Lake Dolloff entry, county `King`, with a non-empty `species` list.

- [ ] **Step 5: Lint**

`ruff check scripts/build_lakes.py && ruff format --check scripts/build_lakes.py`. If format fails, run `ruff format scripts/build_lakes.py` and re-run Step 3 to confirm the output hash is unchanged.

- [ ] **Step 6: Commit**

```bash
git add scripts/build_lakes.py WAFishMap/Resources/lakes.json
git commit -m "Bundle WDFW lowland lakes with species lists" -- scripts/build_lakes.py WAFishMap/Resources/lakes.json
```
Body: why species join by coordinate (repeating name + county pairs).

---

### Task 2: `Lake` model, name check and matching

**Files:**
- Create: `WAFishMap/Models/Lake.swift`
- Create: `WAFishMapTests/LakeTests.swift`

**Interfaces:**
- Consumes: `LonLat` (`WAFishMap/Models/LonLat.swift`, `longitude`/`latitude` Doubles).
- Produces:
  - `struct Lake: Decodable, Identifiable, Equatable, Sendable` with `name: String`, `county: String`, `longitude: Double`, `latitude: Double`, `acres: Double?`, `elevationFeet: Int?`, `management: String?`, `shorelineAccess: String?`, `boatRamp: String?`, `websiteURL: String?`, `species: [String]`, computed `id: String`, `coordinate: LonLat`, `radiusMeters: Double?`.
  - `static func Lake.match(facilityName: String, at point: LonLat, in lakes: [Lake]) -> Lake?`
  - `static func Lake.namesAgree(facility: String, lake: String) -> Bool`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import WAFishMap

/// A wrong lake puts another lake's facts on a sheet, which breaks the scope
/// promise; a miss shows nothing. So most of these pin refusals. The real pairs
/// come from a 2026-09-16 probe of WDFW launches against WDFW lake points, where
/// distance alone matched Lyle Lake to Herman Lake.
struct LakeTests {
    static func lake(_ name: String, _ lon: Double, _ lat: Double, acres: Double?) -> Lake {
        Lake(name: name, county: "King", longitude: lon, latitude: lat, acres: acres,
             elevationFeet: nil, management: nil, shorelineAccess: nil, boatRamp: nil,
             websiteURL: nil, species: [])
    }

    // MARK: Name check

    @Test(arguments: [
        ("Steel Lake", "Steele Lake"),
        ("Tim Ponds", "Tims Ponds"),
        ("Lake Saint Clair", "St. Clair Lake"),
        ("Devils Lake", "Lost (Devil’s) Lake"),
        ("North Lake", "North Lake"),
        ("Pond 6-Buena", "I-82 Pond 6"),
    ])
    func namesThatAgree(facility: String, lake: String) {
        #expect(Lake.namesAgree(facility: facility, lake: lake))
    }

    @Test(arguments: [
        ("Lyle Lake", "Herman Lake"),
        ("Corral Lake", "Potholes Reservoir"),
        ("North Lake", "South Lake"),
    ])
    func namesThatDisagree(facility: String, lake: String) {
        #expect(!Lake.namesAgree(facility: facility, lake: lake))
    }

    /// A launch not named for a lake (Medicare Beach on Potholes) is not checked.
    @Test func aLaunchNotNamedForWaterIsNotNameChecked() {
        #expect(Lake.namesAgree(facility: "Medicare Beach", lake: "Potholes Reservoir"))
    }

    // MARK: Matching

    @Test func aLaunchInReachOfOneLakeMatchesIt() {
        let dolloff = Self.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)
        let launch = LonLat(longitude: -122.284561, latitude: 47.323529)
        #expect(Lake.match(facilityName: "Lake Dolloff", at: launch, in: [dolloff])?.name == "Lake Dolloff")
    }

    @Test func twoLakesInReachMatchNothing() {
        let a = Self.lake("A Lake", -122.000, 47.000, acres: 500)
        let b = Self.lake("B Lake", -122.004, 47.000, acres: 500)
        let between = LonLat(longitude: -122.002, latitude: 47.000)
        #expect(Lake.match(facilityName: "Access", at: between, in: [a, b]) == nil)
    }

    @Test func aLakeWithNoAcreageNeverMatches() {
        let unknown = Self.lake("Mystery Lake", -122.0, 47.0, acres: nil)
        #expect(Lake.match(facilityName: "Mystery Lake", at: LonLat(longitude: -122.0, latitude: 47.0), in: [unknown]) == nil)
    }

    @Test func aLaunchOutOfReachMatchesNothing() {
        // 21 acres -> r ~ 165 m, reach ~ 648 m. This launch is ~2.2 km away.
        let dolloff = Self.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)
        let far = LonLat(longitude: -122.2836, latitude: 47.3428)
        #expect(Lake.match(facilityName: "Lake Dolloff", at: far, in: [dolloff]) == nil)
    }

    @Test func aContradictingNameRefusesAnOtherwiseGoodMatch() {
        let herman = Self.lake("Herman Lake", -119.2030, 46.8900, acres: 60)
        let lyleLaunch = LonLat(longitude: -119.203165, latitude: 46.895406)
        #expect(Lake.match(facilityName: "Herman Lake", at: lyleLaunch, in: [herman]) != nil)
        #expect(Lake.match(facilityName: "Lyle Lake", at: lyleLaunch, in: [herman]) == nil)
    }
}
```

The first `#expect` in `aContradictingNameRefusesAnOtherwiseGoodMatch` is the control: it proves the launch is in reach, so the second expectation fails only on the name check.

- [ ] **Step 2: Run to verify failure**

Load the `ios-build` skill, then:
```bash
xcodebuild test -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone' -only-testing:WAFishMapTests/LakeTests > "$TMPDIR/lake-t2.log" 2>&1; rc=$?; echo rc=$rc; grep -E "error:|TEST (SUCCEEDED|FAILED)" "$TMPDIR/lake-t2.log" | head
```
Expected: non-zero rc, compile error `cannot find 'Lake' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// A WDFW lowland lake, bundled from `scripts/build_lakes.py`. WDFW publishes
/// lakes as points, not outlines, so a launch is linked to a lake by distance
/// scaled to the lake's acreage, never by containment.
struct Lake: Decodable, Identifiable, Equatable, Sendable {
    var id: String { "\(name)|\(longitude)|\(latitude)" }
    let name: String
    let county: String
    let longitude: Double
    let latitude: Double
    let acres: Double?
    let elevationFeet: Int?
    let management: String?
    let shorelineAccess: String?
    let boatRamp: String?
    let websiteURL: String?
    /// WDFW's per-species lake lists, in WDFW layer order.
    let species: [String]

    var coordinate: LonLat { LonLat(longitude: longitude, latitude: latitude) }

    /// Radius of a circle with this lake's area. A long lake is wider than this
    /// along its axis, so its far shore misses; a miss is the safe failure.
    var radiusMeters: Double? {
        guard let acres, acres > 0 else { return nil }
        return (acres * 4046.86 / .pi).squareRoot()
    }

    static let reachFactor = 1.5
    /// Ramps sit on the shore, and WDFW's point is not always the lake's centre.
    static let reachPaddingMeters = 400.0

    /// The one lake a launch sits on, or nil. Two lakes in reach is nil rather
    /// than the nearer one: showing the wrong lake's facts is worse than none.
    static func match(facilityName: String, at point: LonLat, in lakes: [Lake]) -> Lake? {
        let inReach = lakes.filter { lake in
            guard let radius = lake.radiusMeters else { return false }
            return distanceMeters(point, lake.coordinate) <= reachFactor * radius + reachPaddingMeters
        }
        guard inReach.count == 1, let lake = inReach.first,
              namesAgree(facility: facilityName, lake: lake.name) else { return nil }
        return lake
    }

    static let ignoredWords: Set<String> = [
        "lake", "lakes", "pond", "ponds", "reservoir", "the",
        "upper", "lower", "north", "south", "east", "west", "of",
    ]

    /// A launch named for a lake must name *this* lake. Distance alone matched
    /// Lyle Lake's launch to Herman Lake. Loose on purpose: Steel/Steele,
    /// Saint/St. and Tim/Tims are one lake each.
    static func namesAgree(facility: String, lake: String) -> Bool {
        guard facility.range(of: #"\b(lake|lakes|pond|ponds|reservoir)\b"#,
                             options: [.regularExpression, .caseInsensitive]) != nil else { return true }
        let facilityTokens = tokens(facility)
        let lakeTokens = tokens(lake)
        // "North Lake" is all ignored words; compare it whole instead.
        if facilityTokens.isEmpty || lakeTokens.isEmpty {
            return words(facility) == words(lake)
        }
        return facilityTokens.contains { a in
            lakeTokens.contains { b in a == b || (a.count >= 3 && b.count >= 3 && withinOneEdit(a, b)) }
        }
    }

    private static func words(_ name: String) -> [String] {
        name.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "saint", with: "st")
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }

    private static func tokens(_ name: String) -> Set<String> {
        Set(words(name)
            .filter { !ignoredWords.contains($0) }
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 })
    }

    private static func withinOneEdit(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        if x == y { return true }
        if abs(x.count - y.count) > 1 { return false }
        if x.count == y.count { return zip(x, y).filter { $0 != $1 }.count == 1 }
        let (short, long) = x.count < y.count ? (x, y) : (y, x)
        return long.indices.contains { Array(long[..<$0] + long[($0 + 1)...]) == short }
    }

    /// Great-circle metres. Launch-to-lake distances run to kilometres, where the
    /// equirectangular shortcut `River` uses would start to drift.
    static func distanceMeters(_ a: LonLat, _ b: LonLat) -> Double {
        let r = 6_371_000.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, h.squareRoot()))
    }
}
```

- [ ] **Step 4: Run to verify pass**

Same command as Step 2 (`$TMPDIR/lake-t2.log`). Expected: `rc=0`, `** TEST SUCCEEDED **`, and the log lists every `LakeTests` test name (grep for `namesThatDisagree` and `twoLakesInReachMatchNothing` to confirm they ran, not skipped).

- [ ] **Step 5: Watch a refusal go red**

Temporarily change `guard inReach.count == 1` to `guard inReach.count >= 1`. Confirm the edit applied with `grep -n "inReach.count >= 1" WAFishMap/Models/Lake.swift`, re-run, expect `twoLakesInReachMatchNothing` to FAIL. Then temporarily make `namesAgree` return `true` on its first line, confirm with grep, re-run, expect `namesThatDisagree` and `aContradictingNameRefusesAnOtherwiseGoodMatch` to FAIL. Revert both and re-run to green.

- [ ] **Step 6: Commit**

```bash
git add WAFishMap/Models/Lake.swift WAFishMapTests/LakeTests.swift
git commit -m "Match launches to WDFW lakes by reach and name" -- WAFishMap/Models/Lake.swift WAFishMapTests/LakeTests.swift
```

---

### Task 3: Loader and the shipped-file gate

**Files:**
- Create: `WAFishMap/Services/LakeLoader.swift`
- Modify: `WAFishMapTests/LakeTests.swift` (append)

**Interfaces:**
- Consumes: `Lake` (Task 2), `lakes.json` shape (Task 1), `FixtureBundle.loader` (`WAFishMapTests/FishingMapModelTests.swift:146`).
- Produces: `enum LakeLoader { static func lakes(from data: Data) throws -> [Lake] }`

- [ ] **Step 1: Append failing tests to `LakeTests`**

```swift
    // MARK: The shipped resource

    private static func bundled() throws -> [Lake] {
        let bundle = try #require(FixtureBundle.loader)
        let url = try #require(bundle.url(forResource: "lakes", withExtension: "json"))
        return try LakeLoader.lakes(from: Data(contentsOf: url))
    }

    @Test func theBundleHoldsTheStatewideLakeList() throws {
        let lakes = try Self.bundled()
        #expect(lakes.count >= 600)
        let dolloff = try #require(lakes.first { $0.name == "Lake Dolloff" })
        #expect(dolloff.county == "King")
        #expect(!dolloff.species.isEmpty)
    }

    /// Real WDFW launch coordinates (layer 0, 2026-09-16) against the shipped
    /// lakes. Three launches within 2 km of each other in Federal Way, and the
    /// two probe mismatches from eastern Washington.
    @Test(arguments: [
        ("Lake Dolloff", -122.284561, 47.323529, "Lake Dolloff" as String?),
        ("Steel Lake", -122.300005, 47.325877, "Steele Lake"),
        ("North Lake", -122.289173, 47.308077, "North Lake"),
        ("Lyle Lake", -119.203165, 46.895406, nil),
        ("Corral Lake", -119.311142, 46.969255, nil),
    ])
    func realLaunchesMatchTheirOwnLake(facility: String, lon: Double, lat: Double, expected: String?) throws {
        let lakes = try Self.bundled()
        let matched = Lake.match(facilityName: facility, at: LonLat(longitude: lon, latitude: lat), in: lakes)
        #expect(matched?.name == expected)
    }
```

- [ ] **Step 2: Run to verify failure**

`-only-testing:WAFishMapTests/LakeTests`, log `$TMPDIR/lake-t3.log`. Expected: compile error `cannot find 'LakeLoader' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Decodes the bundled WDFW lake list. Static, offline data, like `RiverLoader`.
enum LakeLoader {
    private struct File: Decodable {
        let lakes: [Lake]
    }

    static func lakes(from data: Data) throws -> [Lake] {
        try JSONDecoder().decode(File.self, from: data).lakes
    }
}
```

- [ ] **Step 4: Run to verify pass**

Expected: `rc=0`, `** TEST SUCCEEDED **`, and grep the log for `realLaunchesMatchTheirOwnLake` showing 5 argument runs. If a real pair fails, do **not** loosen the test: report which pair and what matched, because that is the scope-promise defect the test exists to catch.

- [ ] **Step 5: Commit**

```bash
git add WAFishMap/Services/LakeLoader.swift
git commit -m "Load bundled lakes and gate real launch matches" -- WAFishMap/Services/LakeLoader.swift WAFishMapTests/LakeTests.swift
```

---

### Task 4: Model wiring

**Files:**
- Modify: `WAFishMap/Services/FishingMapModel.swift` (properties near line 25-40, `loadFromBundle` ~145, `load` ~166, `indexWaterbodies` ~269, loaders ~287)
- Modify: `WAFishMapTests/FishingMapModelTests.swift` (append a test)

**Interfaces:**
- Consumes: `Lake.match`, `LakeLoader.lakes(from:)`.
- Produces: `var lakes: [Lake]`, `private(set) var siteLake: [AccessSite.ID: Lake]`, `func lake(for site: AccessSite) -> Lake?`.

- [ ] **Step 1: Write the failing test**

Append inside the existing test struct, matching its `AccessSite` initializer style (`FishingMapModelTests.swift:59`):

```swift
    @Test @MainActor func aLakeLaunchIsIndexedToItsLake() {
        let model = FishingMapModel()
        model.lakes = [LakeTests.lake("Lake Dolloff", -122.2836, 47.3228, acres: 21.0)]
        let site = AccessSite(facilityName: "Lake Dolloff", countyName: "King", hasLaunch: true,
                              launchSurface: .concrete, hasRestrooms: false, directions: "",
                              coordinate: LonLat(longitude: -122.284561, latitude: 47.323529))
        model.accessSites = [site]
        model.indexWaterbodies()
        #expect(model.lake(for: site)?.name == "Lake Dolloff")
    }
```

If the surrounding tests are not `@MainActor` per test, follow whatever isolation they use.

- [ ] **Step 2: Run to verify failure**

`-only-testing:WAFishMapTests/FishingMapModelTests`, log `$TMPDIR/lake-t4.log`. Expected: compile error on `lakes` / `lake(for:)`.

- [ ] **Step 3: Implement**

After the `riverFlows` property:
```swift
    /// Bundled WDFW lake facts. Not a live layer — see `Lake`.
    var lakes: [Lake] = []
    /// Inland launch → the one WDFW lake it sits on. Precomputed like
    /// `siteWaterbody`: matching scans every lake.
    private(set) var siteLake: [AccessSite.ID: Lake] = [:]

    func lake(for site: AccessSite) -> Lake? {
        siteLake[site.id]
    }
```

In both `loadFromBundle(bundle:)` and `load(client:bundle:)`, add `loadLakes(bundle: bundle)` directly after each `loadRiverStats(bundle: bundle)`.

At the end of `indexWaterbodies()`:
```swift
        var lakeMap: [AccessSite.ID: Lake] = [:]
        for site in accessSites where siteAreaName[site.id] == nil {
            lakeMap[site.id] = Lake.match(facilityName: site.facilityName, at: site.coordinate, in: lakes)
        }
        siteLake = lakeMap
```

After `loadRiverStats(bundle:)`:
```swift
    private func loadLakes(bundle: Bundle) {
        guard lakes.isEmpty,
              let url = bundle.url(forResource: "lakes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? LakeLoader.lakes(from: data) else { return }
        lakes = loaded
    }
```

- [ ] **Step 4: Run to verify pass**

Full unit suite this time: `-only-testing:WAFishMapTests`, log `$TMPDIR/lake-t4.log`. Expected: `rc=0`, `** TEST SUCCEEDED **`, `aLakeLaunchIsIndexedToItsLake` present in the log.

- [ ] **Step 5: Commit**

```bash
git commit -m "Index inland launches to WDFW lakes" -- WAFishMap/Services/FishingMapModel.swift WAFishMapTests/FishingMapModelTests.swift
```

---

### Task 5: Sheet section

**Files:**
- Modify: `WAFishMap/SiteDetailSheet.swift` (new view before `struct SiteDetailSheet`, new parameter, body line after `amenitiesSection`)
- Modify: `WAFishMap/FishingMapView.swift:113-121`

**Interfaces:**
- Consumes: `Lake`, `FishingMapModel.lake(for:)`.
- Produces: `struct LakeFactsSection: View { let lake: Lake }`; `SiteDetailSheet.lake: Lake?` (default `nil`).

- [ ] **Step 1: Add the view** (above `/// Detail shown when a launch/shore marker is tapped.`)

```swift
/// WDFW's own facts for the lake a launch sits on. Everything here is WDFW's
/// per-lake data, so it is true of the whole lake and bypasses the scoped notes
/// in `fisheries.json`.
struct LakeFactsSection: View {
    let lake: Lake

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lake facts (WDFW)").font(.headline)
            Text(lake.name).font(.subheadline.weight(.semibold))
            if let acres = lake.acres {
                Label("\(acres.formatted(.number.precision(.fractionLength(0...1)))) acres", systemImage: "ruler")
            }
            if let elevation = lake.elevationFeet {
                Label("\(elevation.formatted()) ft elevation", systemImage: "mountain.2")
            }
            if let ramp = lake.boatRamp {
                Label("Boat ramp: \(ramp)", systemImage: "ferry")
            }
            if let access = lake.shorelineAccess {
                Label("Shoreline access: \(access)", systemImage: "figure.fishing")
            }
            if let management = lake.management {
                Label(management, systemImage: "building.columns")
            }
            if !lake.species.isEmpty {
                Label("WDFW lists: \(lake.species.joined(separator: ", "))", systemImage: "fish")
            }
            if let urlString = lake.websiteURL, let url = URL(string: urlString) {
                Link("WDFW lake page", destination: url)
            }
            Text("From WDFW's lowland lakes map (2014). Species listed are not a stocking or season guarantee.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityIdentifier("lakeFactsSection")
    }
}
```

Before relying on `systemImage` names, confirm `mountain.2`, `ruler`, `building.columns` and `fish` exist in SF Symbols for iOS 18 (the `apple-docs` MCP does not index symbols; if unsure, check a symbol already used in the repo with `grep -rn 'systemImage: "' WAFishMap | grep -o '"[a-z0-9.]*"' | sort -u` and prefer those).

- [ ] **Step 2: Wire it in**

In `SiteDetailSheet`, after `var species: String? = nil`:
```swift
    /// The WDFW lake this launch sits on, when `Lake.match` found exactly one.
    var lake: Lake? = nil
```
In `body`, after `amenitiesSection`:
```swift
                    if let lake { LakeFactsSection(lake: lake) }
```
In `FishingMapView.swift`, add `lake: model.lake(for: site)` as the last argument of `SiteDetailSheet(` (after `species: selectedSpecies`, adding the comma). Run `git diff WAFishMap/FishingMapView.swift` first: if there are edits you did not make, leave them unstaged and commit only your hunk (`git add -p` is interactive and unavailable, so commit the file only if the diff is yours alone; otherwise stop and report).

- [ ] **Step 3: Build and full unit suite**

`-only-testing:WAFishMapTests`, log `$TMPDIR/lake-t5.log`. Expected: `rc=0`, `** TEST SUCCEEDED **`.

- [ ] **Step 4: See it on screen**

Per the `ios-build` skill, install and launch on the `iPhone` simulator with live data, tap the Lake Dolloff launch (Federal Way), and take a screenshot. Observation required: the "Lake facts (WDFW)" section with Lake Dolloff's species. Then tap a saltwater launch and confirm the section is absent. An exit-0 build is not this observation.

- [ ] **Step 5: Commit**

```bash
git commit -m "Show WDFW lake facts on the launch sheet" -- WAFishMap/SiteDetailSheet.swift WAFishMap/FishingMapView.swift
```

---

### Task 6: Docs and tracking

**Files:**
- Modify: `CLAUDE.md` (Seasonal guidance section)
- Modify: `STATUS.md`, `TASKS.md`

- [ ] **Step 1:** In `CLAUDE.md`, under "Seasonal guidance", add one bullet: the sheet also shows WDFW lake facts from bundled `lakes.json` (`scripts/build_lakes.py`), matched by `Lake.match`, which refuses ambiguous and name-contradicted matches because a wrong lake breaks the scope promise.
- [ ] **Step 2:** `STATUS.md` decision log, `### 2026-09-16`: `- Decided: lake facts from WDFW's 2014 lakes points, matched by acreage reach + name check; distance alone matched Lyle Lake to Herman Lake.` Add to Known broken or Next Up: `Silver Lake -> North Silver Lake match unverified against WDFW.`
- [ ] **Step 3:** `TASKS.md`: mark `- [x] Add WDFW lowland lakes layer (AllLakes MapServer/2)`.
- [ ] **Step 4:** `graphify update .`
- [ ] **Step 5: Commit** `git commit -m "Document lake facts" -- CLAUDE.md STATUS.md TASKS.md`
