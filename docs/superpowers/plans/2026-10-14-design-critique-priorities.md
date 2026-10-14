# Design Critique Priorities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the three priority fixes from the 2026-10-14 design critique: lead the detail sheets with "What's biting", fix the contrast and touch-target failures, and make the map chrome consistent (pill controls, toggles that report their state, named type roles).

**Architecture:** All changes are SwiftUI view edits plus a few new design tokens in `DesignSystem.swift`. Each fix gets a test that is watched failing for the right reason before the fix lands: Swift Testing unit tests for colour contrast (same construction as `RatingBadgeContrastTests`) and XCUITest UI tests for layout facts only a real screen can show (section order, frame size, toggle state).

**Tech Stack:** Swift, SwiftUI, MapKit (UIKit annotation views), Swift Testing (`WAFishMapTests`), XCTest/XCUIAutomation (`WAFishMapUITests`), `~/bin/apple-build.sh`.

**Spec:** the "Design critique" section directly below. It is the source for every task. Findings it lists that no task covers are in "Deferred" at the end, on purpose.

---

## Design critique (the spec, 2026-10-14)

Reviewed from the six App Store screenshots in `docs/app-store/screenshots/` (light and dark), the app icon `icon/icon_1024.png`, and the source of every view, marker and token. Not run live: the heat and river overlays, species cards, weather, buoys, iPad and large Dynamic Type sizes were not seen.

### Overall impression

A disciplined, well-reasoned interface. The colour ramp, marker contrast and closure badge all show careful work. The biggest problem is order: the app's reason to exist ("What's biting") sits about ninth on the detail sheet, below facts available anywhere else.

### Usability

| Finding | Severity | Recommendation |
|---|---|---|
| On a launch or pier sheet, "What's biting" comes after facility rows, directions, daylight, tides, buoy, weather and protected areas. At the medium detent most people see, it is off screen. | High | Move it directly under the header (after the protected-area qualifier, which must stay above it), with "Before you go" right after it because it qualifies the guidance. |
| The map legend explains colours only. The "!" badge (season may be closed), the faded pin (closed) and the three pin glyphs (boat, angler, fish) are explained only to VoiceOver. | Medium | One line in the info popover covering badge, faded pin and glyphs. |
| Rivers and Heat look nearly identical on and off (tint only; Rivers' icon does not change). VoiceOver hears "Rivers, button" in both states. | Medium | A filled on-state and a state assistive tech can read. |
| Top bar: the date and "Now" are pills, the species menu is bare blue text, "Night" is a non-interactive label between buttons that reads as one. | Medium | Give the species menu the same pill. With every control a pill, the plain "Night" reads as status. |
| A closed pier says closed three times: WDFW's "(CLOSED)" in the name, the gray chip, and a sentence. | Low | Strip the suffix from the sheet title only; keep it on map labels, where the faded pin is a weak cue. |
| The river sheet showed a reading stamped Aug 6 against a Sep 20 plan date with no warning (possibly fixture data; nothing in code flags an old reading). | Low | Mark readings older than about a day as stale. |

### Visual hierarchy

- **What draws the eye first:** the orange and red cluster badges. Correct; they are the rating signal.
- **Reading flow on a sheet:** title, an unexplained gap of about 80pt, rating chip, facility rows, then a full-width blue Directions button that outweighs the rating.
- **Emphasis:** the map chrome is all 11pt (`caption2`). `DesignSystem.swift` itself records that 31 of 48 type calls sit on the two smallest steps. Small for a phone read outdoors.

### Consistency

| Element | Issue | Recommendation |
|---|---|---|
| Type scale | `DS.TypeScale` defines roles; 0 of 108 text-style calls use them. | Adopt the roles, so enlarging chrome text is one edit. |
| Boat launch icon | `sailboat.fill` on the map, `ferry` in the sheet and lake facts. A ferry reads as a ferry terminal in Puget Sound. | One glyph in both places. |
| Fish icon | One glyph means pier pin, species filter, bait row and lake species. | Keep the fish for species; distinct glyphs for bait and pier. |
| Row icons | Label icons differ in width, so row text starts at different x. | Fixed-width icon column. |
| Units | River length in km; everything else imperial. | Miles. |
| Fixed font sizes | "MA n" labels (11pt), recentre icon (15pt), season-ribbon "?" (7pt) ignore Dynamic Type. | Scaled sizes; 7pt is unreadable at any setting. |

### Accessibility

- **Colour contrast:** the gray "Closed" chip (white on system gray) is about 3.3:1 by calculation, under 4.5:1 for text that size. The faintest gray (`.tertiary`) is about 1.7:1 on white by calculation, lower on the sheet's gray. It carries the season-risk reason, river gauge notes, flow-strip labels and "Guidance updated". In dark mode, "All species" in blue on the teal glass bar is the weakest text in the screenshots.
- **Touch targets:** the recentre button is 36x36pt, under 44pt. Pins, clusters and the info button already meet 44pt.
- **Text readability:** sheet body text is fine; map chrome is 11pt secondary over glass whose legibility depends on the map beneath.
- **Note found while planning:** `secondaryLabel` itself is about 3.5:1 on white by calculation, so "promote to secondary" fixes the 1.7:1 text but does not reach 4.5:1. App-wide secondary text is a separate decision (Deferred).

### What works well

- The rating ramp: anchored to system colours, lightness steps gated by `RampLightnessTests`, colour-blind simulations in `docs/design/ramp-check`.
- Marker glyph ink picks black or white per stop, white by default.
- Closure is a badge shape, so colour does one job.
- The season ribbon starts at the current month, so winter runs do not split.
- Honest empty states: no gauge, gauge not reporting, and USGS unreachable are three messages; a failed protected-area check never looks clear.
- iPad uses an inspector, not a stretched phone sheet.
- The app icon is clean and legible small, though generic (white fish on teal, nothing that says map or Washington).

### Priority recommendations

1. **Lead the detail sheet with "What's biting".**
2. **Fix the faint text, the Closed chip and the 36pt recentre button.**
3. **Unify the top bar and the toggles, and adopt the type roles in the map chrome.**

---

## Global Constraints

- Deployment target iOS 18.0; build host Xcode 26 or newer (`GlassCard` needs the iOS 26 SDK).
- Every screen showing guidance keeps the disclaimer and WDFW link. `GuidanceOnEverySheetUITests` must stay green.
- `ProtectedAreaSection` stays immediately above `BitingNowView`: it qualifies the guidance and must be read first.
- Design tokens: a view names a role (`DS.*`), never a raw value. Prefer system colours; a literal colour needs a comment saying why the system one fails.
- Contrast floor for text is 4.5:1 (WCAG AA), except where a task states otherwise and says why.
- Run every `xcodebuild` through `~/bin/apple-build.sh` from the repo root. Never pipe xcodebuild into `tail`; never hardcode a simulator name. Exactly one iPhone simulator must be booted (`scripts/run_sim.sh --no-location` boots, builds and installs one if none is).
- `WAFishMapUITests/PinVoiceOverProbe` fails on every run (known, STATUS "Known broken"). Never run the whole UI target without `-skip-testing:WAFishMapUITests/PinVoiceOverProbe`.
- A cold UI-test launch has taken 193s; tests wait up to 120s for the first sheet. After a simulator erase, re-run once before believing a first red.
- No emoji anywhere. Comments explain why, never restate the code.
- Work on branch `design/critique-priorities`. Commit with an explicit pathspec covering only files you touched; new files need `git add` first. Never `--no-verify`. Every commit message ends with:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU
  ```
- New Swift files join their targets automatically (the project uses synchronized folders); do not edit `project.pbxproj`.

## File structure

| File | Change | Responsibility |
|---|---|---|
| `WAFishMap/SiteDetailSheet.swift` | Modify | Section order (site, pier); `whatsBitingHeading` id; `ClosedBadge`; fine-print ink |
| `WAFishMap/DaylightView.swift` | Modify | `daylightHeading` id |
| `WAFishMap/DesignSystem.swift` | Modify | New `DS.Ink.fineprint`, `DS.Chrome.riversOn`, `DS.Chrome.heatOn` |
| `WAFishMap/FishingMapView.swift` | Modify | Recentre hit target; layer toggles; species pill; type roles; fine-print ink |
| `WAFishMap/BuoyConditionsView.swift`, `PlanWeatherView.swift`, `TidePredictionsView.swift`, `FlowRangeStrip.swift`, `RiverDetailSheet.swift` | Modify | Fine-print ink only |
| `WAFishMapUITests/SheetOrderUITests.swift` | Create | "What's biting" leads both sheets |
| `WAFishMapUITests/MapChromeUITests.swift` | Create (Task 4), extend (Task 5) | Recentre size; toggle state |
| `WAFishMapTests/FineprintContrastTests.swift` | Create | Fine-print ink floor plus its control |
| `WAFishMapTests/RatingBadgeContrastTests.swift` | Modify | Closed chip contrast |
| `WAFishMapTests/ToggleTintContrastTests.swift` | Create | White label on toggle on-state fills |
| `STATUS.md` | Modify (Task 7) | Decision log |

---

### Task 0: Branch

- [ ] **Step 1: Switch to the branch (it was created with this plan's commit)**

```bash
cd ~/developer/wa-fish-map
git status --untracked-files=no
git switch design/critique-priorities
```

Expected: clean tracked tree, now on `design/critique-priorities`, whose latest commit adds this plan. If the tree is not clean, stop and report what is modified rather than carrying it onto the branch.

---

### Task 1: Lead the detail sheets with "What's biting"

**Files:**
- Create: `WAFishMapUITests/SheetOrderUITests.swift`
- Modify: `WAFishMap/SiteDetailSheet.swift` (`BitingNowView.body`, `SiteDetailSheet.body`, `PierDetailSheet.body`)
- Modify: `WAFishMap/DaylightView.swift` (`body`)

**Interfaces:**
- Consumes: `-uiTesting` and `-uiTestingDetail site|pier` launch flags (`UITestSeam`); sheet ids `siteDetailSheet`, `pierDetailSheet`.
- Produces: accessibility identifiers `whatsBitingHeading` and `daylightHeading`.

- [ ] **Step 1: Add the two identifiers (no reorder yet)**

In `BitingNowView.body` (`SiteDetailSheet.swift`), change:

```swift
            Text("What's biting").font(.headline)
```

to:

```swift
            Text("What's biting").font(.headline)
                .accessibilityIdentifier("whatsBitingHeading")
```

In `DaylightView.body`, change:

```swift
                Text("Daylight").font(.headline)
```

to:

```swift
                Text("Daylight").font(.headline)
                    .accessibilityIdentifier("daylightHeading")
```

- [ ] **Step 2: Write the failing UI test**

Create `WAFishMapUITests/SheetOrderUITests.swift`:

```swift
import XCTest

/// The detail sheets open at the medium detent, and what fits there is what
/// most people read. "What's biting" is the one section no other app has, so
/// it has to be on that first screen rather than ninth in a scroll (design
/// critique, 2026-10-14).
///
/// Asserted two ways because each alone can pass wrongly: an order check
/// passes on a sheet short enough to need no scrolling, and a hittable check
/// passes on a tall enough screen whatever the order.
@MainActor
final class SheetOrderUITests: XCTestCase {
    private func launch(detail: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingDetail", detail]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private static func labels(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    private func assertBitingLeads(sheetID: String, detail: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let app = launch(detail: detail)
        let sheet = element(app, sheetID)
        guard sheet.waitForExistence(timeout: 120) else {
            XCTFail("\(sheetID) never came up, so nothing below proves anything. On screen: \(Self.labels(app))",
                    file: file, line: line)
            return
        }
        let biting = element(app, "whatsBitingHeading")
        let daylight = element(app, "daylightHeading")
        // Both must exist before their positions mean anything: a missing
        // element's frame is .zero, and zero sits above everything.
        guard biting.waitForExistence(timeout: 10), daylight.exists else {
            XCTFail("Missing heading (biting: \(biting.exists), daylight: \(daylight.exists)). On screen: \(Self.labels(app))",
                    file: file, line: line)
            return
        }
        XCTAssertLessThan(biting.frame.minY, daylight.frame.minY,
                          "What's biting sits below Daylight on \(sheetID).", file: file, line: line)
        XCTAssertTrue(biting.isHittable,
                      "What's biting is off screen at the sheet's opening height on \(sheetID).",
                      file: file, line: line)
    }

    func testSiteSheetLeadsWithWhatsBiting() {
        assertBitingLeads(sheetID: "siteDetailSheet", detail: "site")
    }

    func testPierSheetLeadsWithWhatsBiting() {
        assertBitingLeads(sheetID: "pierDetailSheet", detail: "pier")
    }
}
```

- [ ] **Step 3: Run it and watch it fail for the right reason**

Run:

```bash
cd ~/developer/wa-fish-map
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/SheetOrderUITests
```

Expected: the script reports failure, and both tests fail on "What's biting sits below Daylight". If either fails on "never came up" or "Missing heading" instead, the test is not yet measuring the order: fix that before going on.

- [ ] **Step 4: Reorder the site sheet**

In `SiteDetailSheet.body`, replace the `VStack` contents:

```swift
                VStack(alignment: .leading, spacing: 18) {
                    header
                    facilitySection
                    DirectionsButton(name: site.facilityName, coordinate: site.coordinate)
                    amenitiesSection
                    if let lake { LakeFactsSection(lake: lake) }
                    DaylightView(coordinate: site.coordinate, planDate: planDate)
                    TidePredictionsView(
                        coordinate: site.coordinate,
                        planDate: planDate,
                        isMarine: isMarine
                    )
                    BuoyConditionsView(coordinate: site.coordinate, isMarine: isMarine)
                    PlanWeatherView(coordinate: site.coordinate, planDate: planDate)
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    if !site.directions.isEmpty { directionsSection }
                }
```

with:

```swift
                VStack(alignment: .leading, spacing: 18) {
                    header
                    // The guidance leads: it is what the medium detent shows
                    // and the one thing this app knows that Maps does not.
                    // The protected-area qualifier stays above it and the
                    // footer right after it, since both qualify it.
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
                    facilitySection
                    DirectionsButton(name: site.facilityName, coordinate: site.coordinate)
                    amenitiesSection
                    if let lake { LakeFactsSection(lake: lake) }
                    DaylightView(coordinate: site.coordinate, planDate: planDate)
                    TidePredictionsView(
                        coordinate: site.coordinate,
                        planDate: planDate,
                        isMarine: isMarine
                    )
                    BuoyConditionsView(coordinate: site.coordinate, isMarine: isMarine)
                    PlanWeatherView(coordinate: site.coordinate, planDate: planDate)
                    if !site.directions.isEmpty { directionsSection }
                }
```

- [ ] **Step 5: Reorder the pier sheet**

In `PierDetailSheet.body`, move the three lines

```swift
                    ProtectedAreaSection(check: protectedAreaCheck)
                    BitingNowView(fishery: fishery, month: month)
                    GuidanceFooter(guide: guide)
```

from the end of the `VStack` to directly after the `if pier.isClosed { Text("WDFW lists this pier as closed. ...") }` block, so the `VStack` reads in this order: header `HStack`, closed sentence, `ProtectedAreaSection`, `BitingNowView`, `GuidanceFooter`, the county/water/link `VStack`, `DirectionsButton`, `DaylightView`, `TidePredictionsView`, `BuoyConditionsView`, `PlanWeatherView`. Add no comment here; the site sheet's comment covers the rule.

- [ ] **Step 6: Run the new test and the guidance test**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/SheetOrderUITests -only-testing:WAFishMapUITests/GuidanceOnEverySheetUITests -only-testing:WAFishMapUITests/VerifyBadgeUITests
```

Expected: the script reports success; all tests in the three classes pass.

- [ ] **Step 7: Commit**

```bash
git add WAFishMapUITests/SheetOrderUITests.swift
git commit -m "Lead the launch and pier sheets with what's biting

The guidance sat ninth on the sheet, below daylight, tides, buoy and
weather, so at the medium detent most people never reached it. It now
follows the header, with the protected-area qualifier still above it and
the WDFW footer right after it. SheetOrderUITests asserts both the order
and that the heading is on screen at the opening height.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/SiteDetailSheet.swift WAFishMap/DaylightView.swift WAFishMapUITests/SheetOrderUITests.swift
```

---

### Task 2: Raise the faint fine print to a readable ink

The fine print uses `.tertiary` (about 1.7:1 on white by calculation). It moves to `secondaryLabel` through a named token. The floor here is 3.0:1, not 4.5:1, and the reason is stated in the test: `secondaryLabel` itself sits near 3.5:1 in light mode, so 4.5:1 for fine print would make fine print darker than the secondary text above it and invert the hierarchy. Raising all secondary text is a separate, deferred decision.

**Files:**
- Modify: `WAFishMap/DesignSystem.swift` (new `DS.Ink`)
- Create: `WAFishMapTests/FineprintContrastTests.swift`
- Modify (call sites): `SiteDetailSheet.swift` (risk reason in `BitingNowView`, "Guidance updated" in `GuidanceFooter`), `BuoyConditionsView.swift` (2), `PlanWeatherView.swift` (1), `TidePredictionsView.swift` (1), `FlowRangeStrip.swift` (3 texts), `RiverDetailSheet.swift` (4), `FishingMapView.swift` (`HeatLegend`, 1)

**Interfaces:**
- Consumes: `RatingBadgeContrastTests.components(_:_:)`, `.composite(_:alpha:over:)`, `.ratio(_:_:)` (existing static helpers).
- Produces: `DS.Ink.fineprint: Color`.

- [ ] **Step 1: Add the token at today's value**

In `DesignSystem.swift`, after the `Surface` enum and before `// MARK: - Type`, add:

```swift
    // MARK: - Ink

    enum Ink {
        /// Disclaimers, attributions, "updated" stamps, axis words.
        ///
        /// Was `.tertiary`, about 1.7:1 on white: below any floor, and it
        /// carried a season-risk reason, which is safety-relevant. It is the
        /// secondary label colour so that size, not lightness, separates fine
        /// print from the supporting text above it.
        static let fineprint = Color(uiColor: .tertiaryLabel)
    }
```

(The value is deliberately still tertiary so the test below can be seen failing. Step 4 changes it.)

- [ ] **Step 2: Write the test and its control**

Create `WAFishMapTests/FineprintContrastTests.swift`:

```swift
import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// Fine print must be readable on the sheet's surfaces.
///
/// The label colours are translucent greys, so the alpha matters: reading only
/// RGB measures a colour that is never drawn. Each ink is composited over the
/// surface before the ratio is taken.
///
/// The floor is 3.0:1, not 4.5:1, on purpose. `secondaryLabel` itself sits
/// near 3.5:1 in light appearance, and fine print darker than the secondary
/// text above it would invert the hierarchy. Raising all secondary text is a
/// separate decision (design critique, 2026-10-14, Deferred).
struct FineprintContrastTests {
    typealias Contrast = RatingBadgeContrastTests

    static let floor = 3.0

    /// The sheet is a material over the map, which no test can resolve. Both
    /// system backgrounds bracket it.
    static let surfaces: [(name: String, color: UIColor)] = [
        ("systemBackground", .systemBackground),
        ("secondarySystemBackground", .secondarySystemBackground),
    ]

    static func ratio(_ ink: UIColor, on surface: UIColor, _ style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ink.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ground = Contrast.components(Color(uiColor: surface), style)
        let drawn = Contrast.composite((Double(r), Double(g), Double(b)), alpha: Double(a), over: ground)
        return Contrast.ratio(drawn, ground)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func fineprintClearsTheFloor(style: UIUserInterfaceStyle) {
        for surface in Self.surfaces {
            let measured = Self.ratio(UIColor(DS.Ink.fineprint), on: surface.color, style)
            #expect(measured >= Self.floor,
                    "Fine print is \(String(format: "%.2f", measured)):1 on \(surface.name) in \(style == .light ? "light" : "dark"); needs \(Self.floor):1.")
        }
    }

    /// The control. Tertiary is what the fine print used to be; if this
    /// passes the floor, the check above cannot tell old from new.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func tertiaryFallsBelowTheFloor(style: UIUserInterfaceStyle) {
        let measured = Self.ratio(.tertiaryLabel, on: .systemBackground, style)
        #expect(measured < Self.floor,
                "Tertiary measured \(String(format: "%.2f", measured)):1, so the floor no longer separates it.")
    }
}
```

- [ ] **Step 3: Run it and watch the first test fail**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/FineprintContrastTests
```

Expected: script reports failure. `fineprintClearsTheFloor` fails in both appearances with a ratio under 3.0; `tertiaryFallsBelowTheFloor` passes in both. If the control fails, stop: the floor does not separate tertiary from secondary on this OS and the task's premise needs re-checking.

- [ ] **Step 4: Point the token at secondary**

In `DS.Ink`, change:

```swift
        static let fineprint = Color(uiColor: .tertiaryLabel)
```

to:

```swift
        static let fineprint = Color(uiColor: .secondaryLabel)
```

- [ ] **Step 5: Run it and see both pass; record the numbers**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/FineprintContrastTests
```

Expected: success. Temporarily add `print(measured)` in the first test if the log does not show values, note the four light/dark x surface ratios for the STATUS entry in Task 7, then remove the print.

- [ ] **Step 6: Replace every `.tertiary` text ink with the token**

Change `.foregroundStyle(.tertiary)` to `.foregroundStyle(DS.Ink.fineprint)` at each of these, and nowhere else:

- `SiteDetailSheet.swift`: the `Text(why)` risk reason in `BitingNowView`, and `Text("Guidance updated \(updated)")` in `GuidanceFooter`.
- `BuoyConditionsView.swift`: `Text("Latest NDBC buoy observation, not a forecast.")` and the relative-age `Text(Self.age.localizedString(...))`.
- `PlanWeatherView.swift`: `Text("Forecast for \(...), not an observation.")`.
- `TidePredictionsView.swift`: `Text("NOAA predictions at the nearest station. Not a tide book.")`.
- `FlowRangeStrip.swift`: `Text("Lower")`, `Text("Typical for the date")`, `Text("Higher")`. Leave `Capsule().fill(.tertiary)` alone; it is a track fill, not text.
- `RiverDetailSheet.swift`: the two `Text("USGS gauge ...")` lines, `Text("Compared against this river's own flow ...")`, and the gauge-name lines in the `!flowsLoaded` and not-reporting branches (four `.tertiary` text sites in all).
- `FishingMapView.swift`: `Text("· density of well-rated spots")` in `HeatLegend`.

Verify nothing was missed:

```bash
grep -rn "foregroundStyle(.tertiary)" WAFishMap
```

Expected: no output.

- [ ] **Step 7: Build and run the unit target**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests
```

Expected: success.

- [ ] **Step 8: Commit**

```bash
git add WAFishMapTests/FineprintContrastTests.swift
git commit -m "Raise the sheet fine print from tertiary to secondary ink

Tertiary measured about 1.7:1 on white and carried the season-risk reason,
gauge notes and flow-strip labels. A DS.Ink.fineprint token now names the
role. Its floor is 3.0:1, not 4.5:1, because secondaryLabel itself sits
near 3.5:1 and fine print must not out-weigh the text above it; the test
carries tertiary as its control so the floor is shown to separate them.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/DesignSystem.swift WAFishMapTests/FineprintContrastTests.swift WAFishMap/SiteDetailSheet.swift WAFishMap/BuoyConditionsView.swift WAFishMap/PlanWeatherView.swift WAFishMap/TidePredictionsView.swift WAFishMap/FlowRangeStrip.swift WAFishMap/RiverDetailSheet.swift WAFishMap/FishingMapView.swift
```

---

### Task 3: Make the Closed chip readable

**Files:**
- Modify: `WAFishMap/SiteDetailSheet.swift` (new `ClosedBadge`; use it in `PierDetailSheet`)
- Modify: `WAFishMapTests/RatingBadgeContrastTests.swift`

**Interfaces:**
- Consumes: `RatingBadgeContrastTests` static helpers.
- Produces: `struct ClosedBadge: View` with `static let labelColor: Color`, `static let fill: Color`, `static let washOpacity: Double`.

- [ ] **Step 1: Extract the chip unchanged**

In `SiteDetailSheet.swift`, directly after `RatingBadge`, add:

```swift
/// The "Closed" capsule on a pier sheet.
struct ClosedBadge: View {
    static let labelColor: Color = .white
    static let fill: Color = .gray
    static let washOpacity = 1.0

    var body: some View {
        Label("Closed", systemImage: "xmark.octagon.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Self.labelColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Self.fill.opacity(Self.washOpacity), in: Capsule())
            .accessibilityIdentifier("closedBadge")
    }
}
```

In `PierDetailSheet.body`, replace:

```swift
                            Label("Closed", systemImage: "xmark.octagon.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.gray, in: Capsule())
                                .accessibilityIdentifier("closedBadge")
```

with:

```swift
                            ClosedBadge()
```

- [ ] **Step 2: Write the failing test**

Append inside `struct RatingBadgeContrastTests` in `RatingBadgeContrastTests.swift`:

```swift
    /// The pier sheet's Closed chip, measured the same way as the rating
    /// badges: the label against the fill as composited over the sheet.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func closedBadgeLabelIsReadable(style: UIUserInterfaceStyle) {
        let surface = Self.components(Color(uiColor: .systemBackground), style)
        let fill = Self.components(ClosedBadge.fill, style)
        let label = Self.components(ClosedBadge.labelColor, style)
        let drawn = Self.composite(fill, alpha: ClosedBadge.washOpacity, over: surface)
        let contrast = Self.ratio(label, drawn)
        #expect(contrast >= 4.5,
                "Closed label is \(String(format: "%.2f", contrast)):1 in \(style == .light ? "light" : "dark"); needs 4.5:1.")
    }
```

- [ ] **Step 3: Run it and watch it fail**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/RatingBadgeContrastTests
```

Expected: failure. `closedBadgeLabelIsReadable` fails in both appearances at roughly 3.3:1; the existing badge test still passes.

- [ ] **Step 4: Give the chip the rating badge's construction**

Replace the whole `ClosedBadge` with:

```swift
/// The "Closed" capsule on a pier sheet.
///
/// Built like `RatingBadge`, for the same reason: white on opaque system gray
/// measured about 3.3:1. Primary ink on a light wash, with the stroke carrying
/// the shape.
struct ClosedBadge: View {
    static let labelColor: Color = .primary
    static let fill: Color = .gray
    static let washOpacity = 0.2

    var body: some View {
        Label("Closed", systemImage: "xmark.octagon.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Self.labelColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Self.fill.opacity(Self.washOpacity), in: Capsule())
            .overlay(Capsule().stroke(Self.fill, lineWidth: 1))
            .accessibilityIdentifier("closedBadge")
    }
}
```

- [ ] **Step 5: Run it and see it pass**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/RatingBadgeContrastTests
```

Expected: success, all cases.

- [ ] **Step 6: Commit**

```bash
git commit -m "Make the pier Closed chip readable

White on opaque system gray measured about 3.3:1. The chip is now a
ClosedBadge built like RatingBadge (primary ink on a 20% wash with a
stroke), and RatingBadgeContrastTests measures it in both appearances.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/SiteDetailSheet.swift WAFishMapTests/RatingBadgeContrastTests.swift
```

---

### Task 4: Give the recentre button a 44pt touch target

The button keeps its 36pt drawing so it stays small chrome over the map; only the touch area grows, the same split `MarkerMetrics` makes for pins.

**Files:**
- Create: `WAFishMapUITests/MapChromeUITests.swift`
- Modify: `WAFishMap/FishingMapView.swift` (`recenterButton`)

**Interfaces:**
- Consumes: `MarkerMetrics.minimumTapTarget` (44, in `Map/AnnotationViews.swift`).
- Produces: accessibility identifier `recenterButton`; `MapChromeUITests` with helpers `launch()`, `element(_:_:)`, `labels(_:)`, `dismissSheet(_:)` that Task 5 extends.

- [ ] **Step 1: Add the identifier only**

In `recenterButton`, after `.accessibilityLabel("Center on my location")`, add:

```swift
        .accessibilityIdentifier("recenterButton")
```

- [ ] **Step 2: Write the failing UI test**

Create `WAFishMapUITests/MapChromeUITests.swift`:

```swift
import XCTest

/// Map chrome facts only a real screen can show: the recentre button's touch
/// area, and whether the layer toggles tell assistive tech their state
/// (design critique, 2026-10-14).
@MainActor
final class MapChromeUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private static func labels(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    /// `-uiTesting` opens the site sheet on launch, and on a phone it covers
    /// the bottom chrome. Same dismissal as `GuidanceOnEverySheetUITests`.
    private func dismissSheet(_ app: XCUIApplication) {
        let sheet = element(app, "siteDetailSheet")
        if sheet.waitForExistence(timeout: 120) {
            sheet.swipeDown(velocity: .fast)
            _ = sheet.waitForNonExistence(timeout: 10)
        }
    }

    func testRecenterButtonIsAtLeastFortyFourPoints() {
        let app = launch()
        let button = element(app, "recenterButton")
        guard button.waitForExistence(timeout: 120) else {
            XCTFail("recenterButton never appeared. On screen: \(Self.labels(app))")
            return
        }
        XCTAssertGreaterThanOrEqual(button.frame.width, 44, "Recentre target is \(button.frame.width)pt wide.")
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Recentre target is \(button.frame.height)pt tall.")
    }
}
```

- [ ] **Step 3: Run it and watch it fail on size**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests
```

Expected: failure reading "Recentre target is 36.0pt wide" (and tall). A "never appeared" failure means Step 1 did not land.

- [ ] **Step 4: Grow the touch area, keep the drawing**

Replace `recenterButton` with:

```swift
    /// Drawn at 36pt so it stays small chrome over the map; touched at 44pt,
    /// the same split `MarkerMetrics` makes for pins. The padding shrinks by
    /// the 4pt the target grows on each side, so the drawing does not move.
    private var recenterButton: some View {
        Button {
            recenterRequested = true
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(width: MarkerMetrics.minimumTapTarget, height: MarkerMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Center on my location")
        .accessibilityIdentifier("recenterButton")
        .padding(.trailing, 6)
        .padding(.top, 2)
    }
```

- [ ] **Step 5: Run it and see it pass**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests
```

Expected: success.

- [ ] **Step 6: Commit**

```bash
git add WAFishMapUITests/MapChromeUITests.swift
git commit -m "Give the recentre button a 44pt touch target

It was 36x36, under Apple's minimum. The drawing stays 36pt; the touch
area grows to MarkerMetrics.minimumTapTarget and the padding shrinks to
match, so nothing moves on screen. MapChromeUITests reads the frame.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/FishingMapView.swift WAFishMapUITests/MapChromeUITests.swift
```

---

### Task 5: Make Rivers and Heat real toggles

`Toggle` with `.toggleStyle(.button)` fills its background with the tint when on (Apple docs, `ToggleStyle.button`, checked 2026-10-14), so the on-state needs a fill white text can sit on. System teal and the overlay's dark violet are both too light for that by calculation, hence two fixed chrome tokens.

**Files:**
- Modify: `WAFishMap/DesignSystem.swift` (new `DS.Chrome`)
- Create: `WAFishMapTests/ToggleTintContrastTests.swift`
- Modify: `WAFishMapUITests/MapChromeUITests.swift`
- Modify: `WAFishMap/FishingMapView.swift` (`statusBar`)

**Interfaces:**
- Consumes: `MapChromeUITests` helpers from Task 4; `RatingBadgeContrastTests` helpers; `DS.Overlay.density`; `DS.TypeScale.control`.
- Produces: `DS.Chrome.riversOn: Color`, `DS.Chrome.heatOn: Color`; identifiers `riversToggle`, `heatToggle`.

- [ ] **Step 1: Add identifiers to the existing buttons**

In `statusBar`, after the Rivers button's `.tint(showRivers ? .teal : .secondary)` add `.accessibilityIdentifier("riversToggle")`, and after the Heat button's `.tint(showHeat ? DS.Overlay.density : .secondary)` add `.accessibilityIdentifier("heatToggle")`.

- [ ] **Step 2: Write the failing UI tests**

Add inside `MapChromeUITests`:

```swift
    /// On is either the selected trait or a switch-style value of "1",
    /// depending on how SwiftUI exposes a button-style toggle. Accepting both
    /// is not loose: a plain `Button` reports neither, before or after a tap,
    /// which is the defect.
    private static func isOn(_ e: XCUIElement) -> Bool {
        e.isSelected || (e.value as? String) == "1"
    }

    private func assertReportsState(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let app = launch()
        dismissSheet(app)
        let toggle = element(app, id)
        guard toggle.waitForExistence(timeout: 30) else {
            XCTFail("\(id) never appeared. On screen: \(Self.labels(app))", file: file, line: line)
            return
        }
        XCTAssertFalse(Self.isOn(toggle), "\(id) reads on before any tap.", file: file, line: line)
        for _ in 0..<20 where !toggle.isHittable {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        toggle.tap()
        for _ in 0..<20 where !Self.isOn(toggle) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(Self.isOn(toggle),
                      "\(id) still reads off after a tap (selected: \(toggle.isSelected), value: \(String(describing: toggle.value))).",
                      file: file, line: line)
        // Kept so the on-state can be looked at, not just asserted: the
        // contrast test assumes a white label on a filled capsule.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(id)-on"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testRiversToggleReportsItsState() {
        assertReportsState("riversToggle")
    }

    func testHeatToggleReportsItsState() {
        assertReportsState("heatToggle")
    }
```

- [ ] **Step 3: Run and watch them fail on state**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests
```

Expected: both toggle tests fail on "still reads off after a tap"; the recentre test passes. A "never appeared" failure means the sheet did not dismiss: fix that first.

- [ ] **Step 4: Add the chrome tokens at a deliberately failing value**

In `DesignSystem.swift`, after the `Overlay` enum, add:

```swift
    // MARK: - Chrome

    enum Chrome {
        /// Fill behind the Rivers toggle when on. The button toggle style
        /// fills with its tint and puts the label over it, so this has to
        /// carry white text; `ToggleTintContrastTests` holds the floor.
        static let riversOn = Color.teal
        /// Fill behind the Heat toggle when on.
        static let heatOn = DS.Overlay.density
    }
```

- [ ] **Step 5: Write the contrast test and its control**

Create `WAFishMapTests/ToggleTintContrastTests.swift`:

```swift
import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// A layer toggle that is on is a filled capsule with its label over it, so
/// the fill must carry white text at 4.5:1 in both appearances.
struct ToggleTintContrastTests {
    typealias Contrast = RatingBadgeContrastTests

    static let fills: [(name: String, color: Color)] = [
        ("Rivers", DS.Chrome.riversOn), ("Heat", DS.Chrome.heatOn),
    ]

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func whiteLabelReadsOnEveryOnStateFill(style: UIUserInterfaceStyle) {
        let white = Contrast.components(.white, style)
        for fill in Self.fills {
            let measured = Contrast.ratio(white, Contrast.components(fill.color, style))
            #expect(measured >= 4.5,
                    "\(fill.name) on-state is \(String(format: "%.2f", measured)):1 in \(style == .light ? "light" : "dark"); needs 4.5:1.")
        }
    }

    /// The control, and the reason Heat does not reuse the overlay token:
    /// the overlay's dark value is lightened to read on a dark map, which
    /// leaves it too light to carry white text.
    @Test func whiteOnTheDarkOverlayVioletFails() {
        let white = Contrast.components(.white, .dark)
        let violet = Contrast.components(DS.Overlay.density, .dark)
        #expect(Contrast.ratio(white, violet) < 4.5)
    }
}
```

- [ ] **Step 6: Run and watch it fail**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/ToggleTintContrastTests
```

Expected: failure. `whiteLabelReadsOnEveryOnStateFill` fails for Rivers (system teal, both appearances) and for Heat in dark; the control passes. If the control fails, stop and report: the premise for a separate Heat token is wrong.

- [ ] **Step 7: Set the real values**

Replace the `Chrome` enum with:

```swift
    // MARK: - Chrome

    enum Chrome {
        /// Fill behind the Rivers toggle when on.
        ///
        /// The button toggle style fills with its tint and puts the label
        /// over it, so this has to carry white text. System teal does not
        /// (about 2.6:1 by calculation), so this is a literal: a deep teal
        /// between the app icon's two gradient stops. One value for both
        /// appearances because the label on it is white in both.
        static let riversOn = Color(red: 0x00 / 255, green: 0x7C / 255, blue: 0x9E / 255)

        /// Fill behind the Heat toggle when on: the overlay violet's light
        /// value, in both appearances. The overlay's own dark value is
        /// lightened for a dark map and cannot carry white text.
        static let heatOn = Color(red: 0x7A / 255, green: 0x29 / 255, blue: 0xB8 / 255)
    }
```

- [ ] **Step 8: Run and see it pass**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapTests/ToggleTintContrastTests
```

Expected: success.

- [ ] **Step 9: Convert the two buttons to toggles**

In `statusBar`, replace the Rivers `Button { showRivers.toggle() } ...` block (through its `.accessibilityIdentifier("riversToggle")`) and the Heat `Button { showHeat.toggle() } ...` block (through `.accessibilityIdentifier("heatToggle")`) with:

```swift
                // Toggles, not buttons: the on-state is a fill, and assistive
                // tech can read whether the layer is showing.
                Toggle(isOn: $showRivers) {
                    Label("Rivers", systemImage: "water.waves")
                        .font(DS.TypeScale.control)
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .tint(showRivers ? DS.Chrome.riversOn : .secondary)
                .accessibilityIdentifier("riversToggle")
                Toggle(isOn: $showHeat) {
                    Label("Heat", systemImage: showHeat ? "flame.fill" : "flame")
                        .font(DS.TypeScale.control)
                }
                .toggleStyle(.button)
                .controlSize(.small)
                // The overlay's violet family: orange is the Good rating.
                .tint(showHeat ? DS.Chrome.heatOn : .secondary)
                .accessibilityIdentifier("heatToggle")
```

- [ ] **Step 10: Run the UI tests and see them pass**

```bash
rm -rf /tmp/wafishmap-chrome-light.xcresult
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests -resultBundlePath /tmp/wafishmap-chrome-light.xcresult
```

Expected: success, all three tests. If `apple-build.sh` refuses `-resultBundlePath`, drop it and use the result bundle path the script prints instead.

- [ ] **Step 11: Look at the on-state in light and dark**

The contrast test assumes the on-state draws a white label on a tint fill. Confirm it by looking. Run the toggle tests again in dark:

```bash
xcrun simctl ui booted appearance dark
rm -rf /tmp/wafishmap-chrome-dark.xcresult
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests -resultBundlePath /tmp/wafishmap-chrome-dark.xcresult
xcrun simctl ui booted appearance light
```

Export the `riversToggle-on` and `heatToggle-on` attachments from both bundles. I believe the command is `xcrun xcresulttool export attachments --path <bundle> --output-path <dir>`; confirm with `xcrun xcresulttool export --help` before relying on it. Read the four images.

Pass when: each on-state is a filled capsule with a white label, in both appearances. The off-state is visible in Task 6's screenshots. If the on-state label is not white (for example tinted text on a pale wash), stop and report what you saw with the images; do not adjust tokens to fit, because the test's premise changed.

- [ ] **Step 12: Commit**

```bash
git add WAFishMapTests/ToggleTintContrastTests.swift
git commit -m "Make Rivers and Heat toggles that show and report their state

They were buttons whose only on/off difference was tint, and VoiceOver
heard the same thing in both states. They are now button-style Toggles:
filled when on, and readable as on or off. The fills are two DS.Chrome
literals because system teal and the overlay's dark violet are too light
to carry the white label; ToggleTintContrastTests holds the floor and
keeps the dark violet as its control.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/DesignSystem.swift WAFishMap/FishingMapView.swift WAFishMapTests/ToggleTintContrastTests.swift WAFishMapUITests/MapChromeUITests.swift
```

---

### Task 6: Species pill and named type roles in the map chrome

No test can see a font role or a pill, so this task is verified by a no-raw-font grep and a before/after screenshot. Type roles are bound to today's sizes, so apart from the species pill nothing should change on screen. Promoting the roles to a larger size is deliberately not in this task (Deferred).

**Files:**
- Modify: `WAFishMap/FishingMapView.swift` (`dateControl`, `planPicker`, `timeOfDayHint`, `nowButton`, `speciesMenu`, `statusBar`, `HeatLegend`, `RatingLegend`)

**Interfaces:**
- Consumes: `DS.TypeScale.control` (`caption2` semibold), `DS.TypeScale.legend` (`caption2`).

- [ ] **Step 1: Capture the before screenshots**

```bash
cd ~/developer/wa-fish-map
scripts/run_sim.sh --no-location
mkdir -p /tmp/wafishmap-before && scripts/app_store_screenshots.sh -o /tmp/wafishmap-before
```

Expected: PNGs in `/tmp/wafishmap-before`, including a light and a dark map frame. Read them; check the file times are from now.

- [ ] **Step 2: Give the species menu the date pill's style**

In `speciesMenu`, after `.fixedSize()`, add:

```swift
        // Same pill as the date and Now: a bare-text menu between two pills
        // read as a different kind of thing, and in dark it was the faintest
        // text on the bar.
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
```

- [ ] **Step 3: Name the roles**

In `FishingMapView.swift`, replace each font below. Each pair is identical in size and weight, so this is a rename:

| Where | From | To |
|---|---|---|
| `dateControl` container | `.font(.caption2)` | `.font(DS.TypeScale.legend)` |
| `planPicker` label | `.font(.caption2.weight(.semibold))` | `.font(DS.TypeScale.control)` |
| `timeOfDayHint` | `.font(.caption2.weight(.semibold))` | `.font(DS.TypeScale.control)` |
| `nowButton` | `.font(.caption2.weight(.semibold))` | `.font(DS.TypeScale.control)` |
| `speciesMenu` label | `.font(.caption2.weight(.semibold))` | `.font(DS.TypeScale.control)` |
| `statusBar` status message | `.font(.caption2)` | `.font(DS.TypeScale.legend)` |
| `statusBar` location-off label | `.font(.caption2)` | `.font(DS.TypeScale.legend)` |
| `HeatLegend` (three texts) | `.font(.caption2)` | `.font(DS.TypeScale.legend)` |
| `RatingLegend` (two texts) | `.font(.caption2)` | `.font(DS.TypeScale.legend)` |

Leave the info popover's `.caption` texts alone; it is not map chrome. Leave the recentre icon's fixed size alone (Deferred).

Verify:

```bash
grep -n "\.font(\.caption2" WAFishMap/FishingMapView.swift
```

Expected: no output.

- [ ] **Step 4: Build, run the chrome UI tests, capture after**

```bash
~/bin/apple-build.sh test WAFishMap -- -only-testing:WAFishMapUITests/MapChromeUITests
scripts/run_sim.sh --no-location
mkdir -p /tmp/wafishmap-after && scripts/app_store_screenshots.sh -o /tmp/wafishmap-after
```

Expected: tests pass; fresh PNGs in `/tmp/wafishmap-after`.

- [ ] **Step 5: Compare before and after**

Read the light and dark map frames from both folders side by side. Pass when: the species menu is now a pill matching the date pill; all other text is the same size and weight; the top bar is still one row. If the bar wrapped to two rows, stop and report with both screenshots; the pill's extra width is the cause and the fix is a judgement call (shorter label or a glyph-only pill), not something to pick silently.

- [ ] **Step 6: Commit**

```bash
git commit -m "Give the species menu a pill and name the map chrome's type roles

The species menu was bare blue text between two pills, and the faintest
text on the bar in dark mode. It now shares the date pill's style, so the
unpilled time-of-day label reads as status. Every caption2 call in the
map chrome now names DS.TypeScale.control or .legend; sizes are unchanged,
so making chrome text larger is one edit in DesignSystem.swift.

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- WAFishMap/FishingMapView.swift
```

---

### Task 7: Full verification and record

- [ ] **Step 1: Run every test except the known-broken probe**

```bash
cd ~/developer/wa-fish-map
~/bin/apple-build.sh test WAFishMap -- -skip-testing:WAFishMapUITests/PinVoiceOverProbe
```

Expected: success. On a red, re-run once on the now-warm simulator before treating it as a regression (cold-launch timeouts are known). Any failure that survives the re-run is a real defect: stop and report it with the failing lines.

- [ ] **Step 2: Look at a launch sheet at its opening height, light and dark**

```bash
xcrun simctl launch --terminate-running-process booted com.danieldecena.WAFishMap -uiTesting
xcrun simctl io booted screenshot /tmp/wafishmap-sheet-light.png
xcrun simctl ui booted appearance dark
xcrun simctl launch --terminate-running-process booted com.danieldecena.WAFishMap -uiTesting
xcrun simctl io booted screenshot /tmp/wafishmap-sheet-dark.png
xcrun simctl ui booted appearance light
```

Read both (allow the app time to load before each screenshot; re-take if the sheet is not up). Pass when: "What's biting" is visible without scrolling, the fine print is readable, and nothing overlaps.

- [ ] **Step 3: Refresh the code graph**

```bash
graphify update .
```

- [ ] **Step 4: Add the decision log entry**

Append under today's date heading in `STATUS.md`'s decision log (create `### 2026-10-14` if absent), filling the measured ratios from Task 2 Step 5:

```markdown
- Decided: act on the 2026-10-14 design critique's three priorities (plan `docs/superpowers/plans/2026-10-14-design-critique-priorities.md`). "What's biting" now leads the launch and pier sheets, below the protected-area qualifier and above the WDFW footer. Fine print moved from tertiary to `DS.Ink.fineprint` (secondaryLabel; measured light <x>/<y>, dark <x>/<y> on system/secondary background), floor 3.0:1 because secondaryLabel itself sits near 3.5:1. Closed chip rebuilt like RatingBadge. Recentre touch area 44pt, drawing unchanged. Rivers/Heat are button-style Toggles with two literal on-state fills (`DS.Chrome`), since system teal and the dark overlay violet cannot carry white text. Species menu is a pill; map chrome names its type roles. The App Store screenshots predate this and are refreshed at the next submission.
```

- [ ] **Step 5: Commit**

```bash
git commit -m "Record the design critique priorities as shipped to the branch

Co-Authored-By: Claude <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SCgcmXoo3VYZUtJuJwU8kU" -- STATUS.md
```

The branch is then ready for a build. Do not upload: build 10 is in App Review, and whether this goes into the next build is Daniel's call.

---

## Deferred (in the critique, not in this plan)

Each is a separate, smaller decision. None blocks the tasks above.

- **Secondary text app-wide is about 3.5:1 on white.** Raising it is a palette decision touching every sheet.
- **Promote `DS.TypeScale.control` and `.legend` one step** (to `caption`, 12pt). One edit after Task 6; needs a look at whether the top bar still fits one row.
- **Legend gaps:** explain the "!" badge, the faded pin and the three pin glyphs in the info popover.
- **Glyphs:** one boat-launch glyph (map `sailboat.fill` vs sheet `ferry`); stop using the fish for pier and bait as well as species.
- **Row icon column** of fixed width on the sheets.
- **River length in miles.**
- **Fixed font sizes:** "MA n" labels (11pt UIKit), recentre icon (15pt), season-ribbon "?" (7pt).
- **Closed pier:** strip WDFW's "(CLOSED)" suffix from the sheet title only.
- **Stale river readings:** mark readings older than about a day.
- **Sheet title gap** of about 80pt above the rating row.
- **Directions button weight** relative to the rating.
- **Pins under the status bar** at the top of the map.
- **App icon** distinctiveness (nothing says map or Washington).
- **Full type-role adoption** outside the map chrome (about 90 more calls in the sheets).
- **App Store screenshots** refresh, at the next submission.
