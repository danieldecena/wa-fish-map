# Figma Library Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Figma component library (file `ribqki97SaOhwvwyOsRIj2`) match `WAFishMap/DesignSystem.swift` exactly, and leave behind a repeatable check that reports any future drift.

**Architecture:** The app resolves its own tokens (a Swift test prints a one-line JSON manifest of every `DS` color in light and dark, every radius, and every type role's point size and weight, as the device resolves them). A read-only Figma script exports the library's variables, text styles and component descriptions to JSON. A Python diff compares the two through a hand-written name map and exits non-zero on any drift. Fixes are applied in Figma in place, then the diff is re-run to zero.

**Tech Stack:** Swift Testing (iOS 26 simulator), Figma MCP `use_figma` (Plugin API), Python 3 stdlib (`/opt/homebrew/bin/python3`, `unittest`).

**Spec:** No separate spec. The source of truth is `WAFishMap/DesignSystem.swift`, plus the CLAUDE.md paragraph "Figma component library for the app" (values come from `DesignSystem.swift`, not the published design system page; Inter stands in for SF Pro; `Icon/<symbol name>` stands in for SF Symbols; washes are a separate layer at node opacity because paint opacity on a variable-bound fill is ignored).

## Global Constraints

- Code wins. Figma is changed to match the app, never the reverse. Any case where the right answer is unclear is put to Daniel before a fix (Task 5).
- Resolved values, not source literals: system colors (`Color.red`, `.secondarySystemFill`, ...) are compared as the iOS 26 simulator resolves them in each appearance.
- Color tolerance: a channel may differ by at most 1/255 (rounding); anything more is drift.
- Fonts: Figma text styles use family `Inter`. Size and weight must match the resolved SF Pro role; the family difference is expected and is not drift.
- Edit in place: never delete and recreate a variable, style or component. Existing ids and every instance on the Screens page must keep resolving.
- No new variables, styles or components unless the diff shows a code token with no Figma counterpart, and then only after Task 5's review.
- `use_figma` calls are strictly sequential, and none run while another agent is writing to the same file.
- Python is `/opt/homebrew/bin/python3`. Swift tests run through `scripts/run_sim.sh test` with `-testPlan WAFishMapUnit`; take the exit status from the command, never through a pipe.
- No emoji anywhere.

---

### Task 1: The app prints its resolved token manifest

**Files:**
- Create: `WAFishMapTests/DesignTokenManifestTests.swift`

**Interfaces:**
- Produces: one log line `DSMANIFEST {json}` from the unit test run, where json is
  `{"colors": {"<token>": {"light": "#rrggbb", "dark": "#rrggbb"}}, "radii": {"<token>": <number>}, "type": {"<role>": {"size": <number>, "weight": "<regular|semibold|bold>"}}}`.
  Token names are `rating.slow`, `rating.fair`, `rating.good`, `rating.prime`, `rating.unrated`, `overlay.density`, `chrome.riversOn`, `chrome.heatOn`, `surface.advisory`, `surface.speciesRow`, `ink.fineprint`; radii `surface.chromeRadius`, `surface.advisoryRadius`, `surface.speciesRowRadius`; type roles `sectionTitle`, `itemTitle`, `supporting`, `control`, `legend`, `mapLabel`, `meta`, `fineprint`, `clusterCount`, `badge`, `tideValue`.

- [ ] **Step 1: Write the test**

```swift
import SwiftUI
import Testing
import UIKit
@testable import WAFishMap

/// Prints every design token as this device resolves it, for the Figma
/// library diff (scripts/figma_ds_diff.py). The assertions keep the manifest
/// honest: a token that failed to resolve must fail the run, not print a zero.
///
/// SwiftUI `Font` cannot be read back, so the type roles are restated here as
/// UIKit text styles. Keep this table in step with `DS.TypeScale`.
struct DesignTokenManifestTests {

    static func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
        let c = { (v: CGFloat) in String(format: "%02x", Int((min(1, max(0, v)) * 255).rounded())) }
        return "#" + c(r) + c(g) + c(b)
    }

    static let colors: [(String, Color)] = [
        ("rating.slow", DS.Rating.slow), ("rating.fair", DS.Rating.fair),
        ("rating.good", DS.Rating.good), ("rating.prime", DS.Rating.prime),
        ("rating.unrated", DS.Rating.unrated), ("overlay.density", DS.Overlay.density),
        ("chrome.riversOn", DS.Chrome.riversOn), ("chrome.heatOn", DS.Chrome.heatOn),
        ("surface.advisory", DS.Surface.advisory), ("surface.speciesRow", DS.Surface.speciesRow),
        ("ink.fineprint", DS.Ink.fineprint),
    ]

    static let radii: [(String, CGFloat)] = [
        ("surface.chromeRadius", DS.Surface.chromeRadius),
        ("surface.advisoryRadius", DS.Surface.advisoryRadius),
        ("surface.speciesRowRadius", DS.Surface.speciesRowRadius),
    ]

    static let type: [(String, UIFont.TextStyle, String)] = [
        ("sectionTitle", .headline, "semibold"), ("itemTitle", .subheadline, "semibold"),
        ("supporting", .subheadline, "regular"), ("control", .caption2, "semibold"),
        ("legend", .caption2, "regular"), ("mapLabel", .caption2, "semibold"),
        ("meta", .caption1, "regular"), ("fineprint", .caption2, "regular"),
        ("clusterCount", .caption2, "bold"), ("badge", .caption1, "bold"),
        ("tideValue", .subheadline, "regular"),
    ]

    @Test func printsManifest() throws {
        let large = UITraitCollection(preferredContentSizeCategory: .large)
        var colorOut: [String: [String: String]] = [:]
        for (name, color) in Self.colors {
            colorOut[name] = ["light": Self.hex(color, .light), "dark": Self.hex(color, .dark)]
        }
        var typeOut: [String: [String: Any]] = [:]
        for (role, style, weight) in Self.type {
            let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: large).pointSize
            #expect(size > 0, "\(role) resolved to no size")
            typeOut[role] = ["size": Double(size), "weight": weight]
        }
        let manifest: [String: Any] = [
            "colors": colorOut,
            "radii": Dictionary(uniqueKeysWithValues: Self.radii.map { ($0.0, Double($0.1)) }),
            "type": typeOut,
        ]
        #expect(colorOut.count == Self.colors.count)
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        print("DSMANIFEST " + String(decoding: data, as: UTF8.self))
    }
}
```

Note on `headline`: UIKit's `.headline` is already semibold, and `subheadline.weight(.semibold)` is the same size as `.subheadline`. The weight column records what `DS.TypeScale` asks for, not what UIKit's base style carries.

- [ ] **Step 2: Run it and capture the line**

```bash
./scripts/run_sim.sh test -d "iPhone 18 Pro" -- -testPlan WAFishMapUnit -only-testing:WAFishMapTests/DesignTokenManifestTests > /tmp/ds-manifest.log 2>&1; rc=$?
echo "rc=$rc"
grep -o 'DSMANIFEST .*' /tmp/ds-manifest.log | head -1 | sed 's/^DSMANIFEST //' > docs/design/ds-manifest.json
/opt/homebrew/bin/python3 -c "import json;d=json.load(open('docs/design/ds-manifest.json'));print(len(d['colors']),len(d['radii']),len(d['type']))"
```

Expected: `rc=0`, and `11 3 11`. If `run_sim.sh` does not pass extra arguments through `--`, read its usage and pass `-testPlan`/`-only-testing` the way it documents; do not hardcode a device name in the script.

- [ ] **Step 3: Check the manifest against numbers already proven**

The rating stops must equal what the design system page and the web map test hold (both proven against `RampLightnessTests` on device):
light prime `#ff383c`, good `#ff8d28`, fair `#ffcc00`, slow `#0088ff`; dark `#ff4245`, `#ff9230`, `#ffd600`, `#0091ff`.

```bash
/opt/homebrew/bin/python3 -c "
import json; c=json.load(open('docs/design/ds-manifest.json'))['colors']
want={'prime':('#ff383c','#ff4245'),'good':('#ff8d28','#ff9230'),'fair':('#ffcc00','#ffd600'),'slow':('#0088ff','#0091ff')}
for k,(l,d) in want.items(): print(k, c['rating.'+k]['light']==l, c['rating.'+k]['dark']==d)"
```

Expected: eight `True`. Any `False` means the manifest is wrong (or the simulator runtime is not iOS 26); stop and find out which before going on.

- [ ] **Step 4: Commit**

```bash
git add WAFishMapTests/DesignTokenManifestTests.swift docs/design/ds-manifest.json
git commit -m "Print the app's resolved design tokens for the Figma diff"
```

---

### Task 2: Export the Figma library to JSON

**Files:**
- Create: `docs/design/figma-inventory.json` (written from the tool result)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `figma-inventory.json` shaped
  `{"variables": [{"id","name","collection","type","values": {"<modeName>": "#rrggbb" | number}}], "textStyles": [{"id","name","family","style","size","lineHeight"}], "components": [{"id","name","type","description"}]}`.

- [ ] **Step 1: Confirm the file is free**

No other agent or session may be writing to `ribqki97SaOhwvwyOsRIj2`. Check `ListAgents` for a running Figma agent; if one is running, wait for its completion notice.

- [ ] **Step 2: Load skills and open a session**

Load `figma:figma-use` (mandatory before `use_figma`) and `figma:figma-generate-library`. Call `whoami`; the account must be `danieldecena10@gmail.com`, else stop and report. `create_session` with the file key.

- [ ] **Step 3: Run the read-only export**

`use_figma` on the file, `skillNames: "figma-generate-library"`:

```js
const toHex = (c) => '#' + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
const collections = await figma.variables.getLocalVariableCollectionsAsync();
const variables = [];
for (const col of collections) {
  for (const id of col.variableIds) {
    const v = await figma.variables.getVariableByIdAsync(id);
    const values = {};
    for (const m of col.modes) {
      let val = v.valuesByMode[m.modeId];
      while (val && val.type === 'VARIABLE_ALIAS') {
        const target = await figma.variables.getVariableByIdAsync(val.id);
        val = target.valuesByMode[Object.keys(target.valuesByMode)[0]];
      }
      values[m.name] = v.resolvedType === 'COLOR' ? toHex(val) : val;
    }
    variables.push({ id: v.id, name: v.name, collection: col.name, type: v.resolvedType, values });
  }
}
const textStyles = (await figma.getLocalTextStylesAsync()).map(s => ({
  id: s.id, name: s.name, family: s.fontName.family, style: s.fontName.style,
  size: s.fontSize, lineHeight: s.lineHeight,
}));
const page = figma.root.children.find(p => p.name === 'Components');
await page.loadAsync();
const components = page.findAll(n => n.type === 'COMPONENT_SET' || (n.type === 'COMPONENT' && n.parent.type !== 'COMPONENT_SET'))
  .map(n => ({ id: n.id, name: n.name, type: n.type, description: n.description }));
return { variables, textStyles, components };
```

A note on aliases: the loop follows an alias into its target's first mode. If any alias points across collections with several modes, the export must instead pick the target mode matching this mode's name; check the result for that case before trusting it.

- [ ] **Step 4: Save and sanity-check**

Write the returned object verbatim to `docs/design/figma-inventory.json`. Expected: a non-empty `variables` list with a Light and a Dark mode on the color collection, 10+ text styles, and the eight components named in CLAUDE.md (Rating Badge, Closed Badge, Site Marker, Site Cluster, Layer Toggle, Rating Legend, Glass Card, Guidance Footer) plus the `Icon/...` components. An empty list is a failed export, not an empty library: stop.

- [ ] **Step 5: Commit**

```bash
git add docs/design/figma-inventory.json
git commit -m "Snapshot the Figma library's variables, text styles and components"
```

---

### Task 3: The diff, tested against good and bad inputs

**Files:**
- Create: `scripts/figma_ds_diff.py`
- Create: `scripts/test_figma_ds_diff.py`
- Create: `docs/design/figma-token-map.json`

**Interfaces:**
- Consumes: `ds-manifest.json` (Task 1), `figma-inventory.json` (Task 2).
- Produces: `figma_ds_diff.diff(manifest, inventory, token_map, repo_root) -> list[dict]`, each dict `{"kind", "token", "code", "figma"}`; CLI `figma_ds_diff.py MANIFEST INVENTORY MAP` prints one line per drift and exits 1 if any, 0 if none. `kind` is one of `color`, `missing-variable`, `unmapped-variable`, `radius`, `type-size`, `type-weight`, `missing-style`, `description`.

`figma-token-map.json` shape:

```json
{
  "colors": {"rating.prime": "rating/prime"},
  "radii": {"surface.chromeRadius": "radius/chrome"},
  "type": {"badge": "Badge"},
  "modes": {"light": "Light", "dark": "Dark"},
  "ignoreVariables": []
}
```

- [ ] **Step 1: Write the failing tests**

```python
"""Tests for figma_ds_diff: a known-good pair must pass and each kind of drift must fire."""
import copy
import os
import tempfile
import unittest

import figma_ds_diff as d

MANIFEST = {
    "colors": {"rating.prime": {"light": "#ff383c", "dark": "#ff4245"}},
    "radii": {"surface.chromeRadius": 14.0},
    "type": {"badge": {"size": 12.0, "weight": "bold"}},
}
INVENTORY = {
    "variables": [
        {"id": "V1", "name": "rating/prime", "collection": "Color", "type": "COLOR",
         "values": {"Light": "#ff383c", "Dark": "#ff4245"}},
        {"id": "V2", "name": "radius/chrome", "collection": "Radius", "type": "FLOAT",
         "values": {"Value": 14}},
    ],
    "textStyles": [{"id": "S1", "name": "Badge", "family": "Inter", "style": "Bold",
                    "size": 12, "lineHeight": {"unit": "AUTO"}}],
    "components": [{"id": "C1", "name": "Rating Badge", "type": "COMPONENT_SET",
                    "description": "RatingBadge in WAFishMap/Views/RatingBadge.swift"}],
}
MAP = {
    "colors": {"rating.prime": "rating/prime"},
    "radii": {"surface.chromeRadius": "radius/chrome"},
    "type": {"badge": "Badge"},
    "modes": {"light": "Light", "dark": "Dark"},
    "ignoreVariables": [],
}


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.root, "WAFishMap/Views"))
        open(os.path.join(self.root, "WAFishMap/Views/RatingBadge.swift"), "w").close()

    def run_diff(self, manifest=MANIFEST, inventory=INVENTORY, token_map=MAP):
        return d.diff(manifest, inventory, token_map, self.root)

    def kinds(self, rows):
        return sorted(r["kind"] for r in rows)

    def test_known_good_pair_has_no_drift(self):
        self.assertEqual(self.run_diff(), [])

    def test_one_unit_rounding_is_not_drift(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][0]["values"]["Light"] = "#ff383d"
        self.assertEqual(self.run_diff(inventory=inv), [])

    def test_color_drift_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][0]["values"]["Dark"] = "#ff3b30"
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["color"])

    def test_missing_variable_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"] = inv["variables"][1:]
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["missing-variable"])

    def test_unmapped_figma_variable_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"].append({"id": "V9", "name": "rating/extra", "collection": "Color",
                                 "type": "COLOR", "values": {"Light": "#000000", "Dark": "#000000"}})
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["unmapped-variable"])

    def test_ignored_variable_does_not_fire(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"].append({"id": "V9", "name": "map/water", "collection": "Color",
                                 "type": "COLOR", "values": {"Light": "#000000", "Dark": "#000000"}})
        m = copy.deepcopy(MAP)
        m["ignoreVariables"] = ["map/water"]
        self.assertEqual(self.run_diff(inventory=inv, token_map=m), [])

    def test_radius_drift_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][1]["values"]["Value"] = 12
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["radius"])

    def test_type_size_and_weight_fire(self):
        inv = copy.deepcopy(INVENTORY)
        inv["textStyles"][0].update(size=11, style="Semi Bold")
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["type-size", "type-weight"])

    def test_missing_style_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["textStyles"] = []
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["missing-style"])

    def test_description_naming_a_missing_file_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "RatingBadge in WAFishMap/Views/Gone.swift"
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["description"])

    def test_description_with_no_swift_path_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "A badge."
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["description"])

    def test_icon_components_need_no_swift_path(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"].append({"id": "C2", "name": "Icon/fish.fill", "type": "COMPONENT", "description": ""})
        self.assertEqual(self.run_diff(inventory=inv), [])

    def test_empty_inventory_is_an_error_not_a_pass(self):
        with self.assertRaises(ValueError):
            self.run_diff(inventory={"variables": [], "textStyles": [], "components": []})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to see it fail**

```bash
cd scripts && /opt/homebrew/bin/python3 -m unittest test_figma_ds_diff -v; echo rc=$?
```

Expected: errors with `ModuleNotFoundError: No module named 'figma_ds_diff'`, rc non-zero.

- [ ] **Step 3: Write the implementation**

```python
#!/opt/homebrew/bin/python3
"""Diff the app's resolved design tokens against the Figma library export.

Usage: figma_ds_diff.py MANIFEST INVENTORY MAP
Prints one line per drift and exits 1 if there is any. An empty Figma
export is an error, not a pass: it means the export failed.
"""
import json
import os
import re
import sys

WEIGHTS = {"Regular": "regular", "Semi Bold": "semibold", "SemiBold": "semibold", "Bold": "bold"}
SWIFT_PATH = re.compile(r"WAFishMap/[\w/]+\.swift")


def _rgb(hex_str):
    h = hex_str.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def _close(a, b):
    return all(abs(x - y) <= 1 for x, y in zip(_rgb(a), _rgb(b)))


def diff(manifest, inventory, token_map, repo_root):
    if not inventory.get("variables") and not inventory.get("textStyles"):
        raise ValueError("Figma export has no variables or text styles; the export failed")
    rows = []
    by_name = {v["name"]: v for v in inventory["variables"]}
    styles = {s["name"]: s for s in inventory["textStyles"]}
    modes = token_map["modes"]

    for token, values in manifest["colors"].items():
        name = token_map["colors"].get(token)
        var = by_name.get(name) if name else None
        if var is None:
            rows.append({"kind": "missing-variable", "token": token, "code": values, "figma": name})
            continue
        for appearance, figma_mode in modes.items():
            got = var["values"].get(figma_mode)
            if got is None or not _close(values[appearance], got):
                rows.append({"kind": "color", "token": f"{token} ({appearance})",
                             "code": values[appearance], "figma": got})

    for token, value in manifest["radii"].items():
        name = token_map["radii"].get(token)
        var = by_name.get(name) if name else None
        if var is None:
            rows.append({"kind": "missing-variable", "token": token, "code": value, "figma": name})
            continue
        got = next(iter(var["values"].values()))
        if abs(float(got) - float(value)) > 0.01:
            rows.append({"kind": "radius", "token": token, "code": value, "figma": got})

    mapped = set(token_map["colors"].values()) | set(token_map["radii"].values()) | set(token_map["ignoreVariables"])
    for var in inventory["variables"]:
        if var["name"] not in mapped:
            rows.append({"kind": "unmapped-variable", "token": var["name"], "code": None, "figma": var["values"]})

    for role, spec in manifest["type"].items():
        style = styles.get(token_map["type"].get(role, ""))
        if style is None:
            rows.append({"kind": "missing-style", "token": role, "code": spec, "figma": None})
            continue
        if abs(float(style["size"]) - float(spec["size"])) > 0.01:
            rows.append({"kind": "type-size", "token": role, "code": spec["size"], "figma": style["size"]})
        if WEIGHTS.get(style["style"]) != spec["weight"]:
            rows.append({"kind": "type-weight", "token": role, "code": spec["weight"], "figma": style["style"]})

    for comp in inventory["components"]:
        if comp["name"].startswith("Icon/"):
            continue
        paths = SWIFT_PATH.findall(comp.get("description") or "")
        missing = [p for p in paths if not os.path.exists(os.path.join(repo_root, p))]
        if not paths or missing:
            rows.append({"kind": "description", "token": comp["name"],
                         "code": missing or "no Swift path", "figma": comp.get("description")})
    return rows


def main(argv):
    manifest, inventory, token_map = (json.load(open(p)) for p in argv[1:4])
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rows = diff(manifest, inventory, token_map, root)
    for r in rows:
        print(f"[x] {r['kind']}: {r['token']}  code={r['code']}  figma={r['figma']}")
    print(f"{len(rows)} drift" if rows else "[ok] no drift")
    return 1 if rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Run the tests to green**

```bash
cd scripts && /opt/homebrew/bin/python3 -m unittest test_figma_ds_diff -v; echo rc=$?
```

Expected: 13 tests, `OK`, rc=0.

- [ ] **Step 5: Prove the detector fires on a real mutation**

Temporarily change `_close`'s tolerance from `1` to `-1` (every color now differs). Run the tests; `test_known_good_pair_has_no_drift` must fail. Confirm the edit applied (`grep -n '<= -1' scripts/figma_ds_diff.py`) before reading the result, then restore `1` and re-run to green.

- [ ] **Step 6: Write the name map from the real inventory**

Open `docs/design/figma-inventory.json`. For each of the 11 colors, 3 radii and 11 type roles in `ds-manifest.json`, find the Figma variable or text style that represents it and write the pair into `docs/design/figma-token-map.json` in the shape above. Use the real mode names from the inventory in `modes`. Leave a code token unmapped if Figma has nothing for it (it will report as `missing-variable` or `missing-style`, which is the finding). Put a Figma variable in `ignoreVariables` only if it represents something with no `DS` token on purpose (for example a map basemap fill used only on the Screens page), and say why in the commit message.

- [ ] **Step 7: Commit**

```bash
git add scripts/figma_ds_diff.py scripts/test_figma_ds_diff.py docs/design/figma-token-map.json
git commit -m "Diff the Figma library against the app's resolved tokens"
```

---

### Task 4: Run the diff and write the drift report

**Files:**
- Create: `docs/research/2026-10-27-figma-library-drift.md`

- [ ] **Step 1: Run**

```bash
/opt/homebrew/bin/python3 scripts/figma_ds_diff.py docs/design/ds-manifest.json docs/design/figma-inventory.json docs/design/figma-token-map.json > /tmp/drift.txt; rc=$?; echo rc=$rc; cat /tmp/drift.txt
```

rc=0 means no drift: write the report saying so, with the counts compared, skip Task 5 and Task 6, and go to Task 7.

- [ ] **Step 2: Write the report**

One row per drift line: token, code value with its source (`DesignSystem.swift:<line>`), Figma value with its node or variable id, and a proposed fix. Mark each row either **clear** (code is unambiguous, the fix is to set Figma to the code value) or **ask** (two readings are reasonable: for example a Figma variable with no code token that the Screens page uses, or a type role whose weight differs only because UIKit's base style already carries that weight).

- [ ] **Step 3: Commit**

```bash
git add docs/research/2026-10-27-figma-library-drift.md
git commit -m "Record the Figma library drift against DesignSystem.swift"
```

---

### Task 5: Daniel decides the ask rows

- [ ] **Step 1:** Put every **ask** row to Daniel in one `AskUserQuestion` (or several if over four), recommended option first with a one-line reason. If there are no ask rows, skip this task.
- [ ] **Step 2:** Record each answer in the drift report beside its row, and commit the report.

---

### Task 6: Fix the drift in Figma, in place

**Files:**
- Modify: `docs/design/figma-inventory.json` (re-exported)

- [ ] **Step 1: Apply fixes**

One `use_figma` call per kind of fix, sequential, each returning the ids it touched:
- color: `variable.setValueForMode(modeId, {r, g, b, a: 1})` on the existing variable (values 0-1).
- radius: `setValueForMode` on the existing FLOAT variable.
- type-size / type-weight: load `{family: 'Inter', style}` with `figma.loadFontAsync`, then set `fontSize` / `fontName` on the existing text style.
- description: set the component set's `description` to name the Swift view and its real path.
- missing-variable / missing-style: create only those Daniel approved in Task 5, with scopes set (never `ALL_SCOPES`) and iOS code syntax set to the `DS` path (for example `DS.Rating.prime`).

Never delete and recreate.

- [ ] **Step 2: Re-export and re-diff**

Re-run Task 2 Step 3, overwrite `figma-inventory.json`, then re-run Task 4 Step 1. Expected: `[ok] no drift`, rc=0. Any remaining row loops back to Step 1 for that row only.

- [ ] **Step 3: Check nothing came unlinked**

`use_figma`, read-only: on the Components page and the Screens page, count instances whose `mainComponent` is null, and text nodes whose `textStyleId` is empty. Expected: 0 and 0. Then take one `get_screenshot` of the Components page's review frame and look at it: every rating state, both badges, the marker and cluster draw.

- [ ] **Step 4: Commit**

```bash
git add docs/design/figma-inventory.json
git commit -m "Re-export the Figma library after reconciling it to the app"
```

---

### Task 7: Write it down

**Files:**
- Modify: `STATUS.md` (decision log, newest first)
- Modify: `CLAUDE.md` (the "Figma component library for the app" paragraph)

- [ ] **Step 1:** Add a `### 2026-10-27 (Figma library reconciled to DesignSystem.swift)` entry: counts compared, drift found and fixed (or none), the ask decisions, and the re-diff result with its exit status. Say what was checked by screenshot and what was not.
- [ ] **Step 2:** In CLAUDE.md's Figma library paragraph, add one sentence: drift is checked with `scripts/figma_ds_diff.py` against `docs/design/ds-manifest.json` (refresh it with `DesignTokenManifestTests`) and a fresh `figma-inventory.json`.
- [ ] **Step 3: Commit**

```bash
git add STATUS.md CLAUDE.md
git commit -m "Log the Figma library reconciliation and how to rerun the check"
```

---

## Self-review

- Coverage: colors, radii, type roles and component descriptions are each compared (Tasks 1-4), fixed in place (Task 6) and re-verified to zero (Task 6 Step 2). Instances and styles staying linked is checked (Task 6 Step 3). Ambiguity goes to Daniel (Task 5).
- Known limit, stated rather than hidden: component geometry (padding, sizes inside a component) is not diffed, because `DS` holds no tokens for it beyond the three radii; the `LayerToggleStyle` padding (10 x 5) and `tertiarySystemFill` off-state are in Swift but not in `DS`, so they are checked only by the screenshot in Task 6 Step 3.
- The diff has a known-good input, a mutation proven to fire, and refuses an empty export.
