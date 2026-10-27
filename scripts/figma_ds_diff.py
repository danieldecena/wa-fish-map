#!/opt/homebrew/bin/python3
"""Diff the app's resolved design tokens against the Figma library export.

Usage: figma_ds_diff.py MANIFEST INVENTORY MAP
Prints one line per drift and exits 1 if there is any. An empty Figma
export is an error, not a pass: it means the export failed.

Drift kinds: color, alpha, type-mismatch, missing-variable, unmapped-variable,
radius, type-size, type-weight, missing-style, description.
"""
import html
import json
import os
import re
import sys

WEIGHTS = {"Regular": "regular", "Semi Bold": "semibold", "SemiBold": "semibold", "Bold": "bold"}
SWIFT_PATH = re.compile(r"[\w/]*\w+\.swift")


def _swift_exists(repo_root, path):
    """A full repo path, or a bare file name found anywhere under WAFishMap/."""
    if os.path.exists(os.path.join(repo_root, path)):
        return True
    name = os.path.basename(path)
    return any(name in files for _, _, files in os.walk(os.path.join(repo_root, "WAFishMap")))


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
        if var["type"] != "COLOR":
            rows.append({"kind": "type-mismatch", "token": token, "code": "COLOR", "figma": f"{name} is {var['type']}"})
            continue
        for appearance, figma_mode in modes.items():
            got = var["values"].get(figma_mode)
            if got is None or not _close(values[appearance], got):
                rows.append({"kind": "color", "token": f"{token} ({appearance})",
                             "code": values[appearance], "figma": got})
                continue
            code_a = values.get(f"{appearance}Alpha")
            figma_a = (var.get("alphas") or {}).get(figma_mode)
            if code_a is not None and figma_a is not None and abs(code_a - figma_a) > 0.01:
                rows.append({"kind": "alpha", "token": f"{token} ({appearance})",
                             "code": code_a, "figma": figma_a})

    for token, value in manifest["radii"].items():
        name = token_map["radii"].get(token)
        var = by_name.get(name) if name else None
        if var is None:
            rows.append({"kind": "missing-variable", "token": token, "code": value, "figma": name})
            continue
        if var["type"] != "FLOAT":
            rows.append({"kind": "type-mismatch", "token": token, "code": "FLOAT", "figma": f"{name} is {var['type']}"})
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
        desc = html.unescape(comp.get("description") or "")
        paths = SWIFT_PATH.findall(desc)
        missing = [p for p in paths if not _swift_exists(repo_root, p)]
        if not paths or missing:
            rows.append({"kind": "description", "token": comp["name"],
                         "code": missing or "no Swift path", "figma": desc})
    return rows


def main(argv):
    manifest, inventory, token_map = (json.load(open(p)) for p in argv[1:4])
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rows = diff(manifest, inventory, token_map, root)
    # A Figma variable with no DS token is not drift: it is a value the check
    # cannot judge. List it apart so it is reviewed, never silently ignored.
    drift = [r for r in rows if r["kind"] != "unmapped-variable"]
    uncovered = [r for r in rows if r["kind"] == "unmapped-variable"]
    for r in drift:
        print(f"[x] {r['kind']}: {r['token']}  code={r['code']}  figma={r['figma']}")
    for r in uncovered:
        print(f"[--] not covered by code tokens: {r['token']}  figma={r['figma']}")
    print(f"{len(drift)} drift, {len(uncovered)} not covered" if drift else f"[ok] no drift, {len(uncovered)} not covered")
    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
