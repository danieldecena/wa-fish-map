#!/usr/bin/env python3
"""Write Artifacts/fishing-year/data.js from Artifacts/fishing-year/seasons.json.

    build_fishing_year.py            build data.js, print the report
    build_fishing_year.py --check    build nothing, exit 1 on any error

seasons.json is the one place the Washington Fishing Year page gets its dated
seasons, key dates, migration months, river text and access points. The page
holds no data of its own. Dated seasons and rules are artifact-only: the app
shows month ratings from fisheries.json and never reads them.

Shared sources, so a fact lives in one place:
 * A stop with a site_id takes its coordinates from site/data/sites.json (WDFW's
   access layer, written by build_web_data.py). It must not carry lat/lon too.
 * A stop with site_id null keeps its own lat/lon, because WDFW's layer does not
   list it. It must carry a place_check against OpenStreetMap: confirmed with the
   OSM name and its distance (0 to 250 m), or confirmed false. The page shows
   "Location unconfirmed" on the unconfirmed ones.
 * Each river's line is measured against WAFishMap/Resources/rivers.json. A point
   more than 1.5 km from the named river is an error. The mouth end can be
   excused with line_mouth_points and a line_mouth_note saying why (the tidal
   Duwamish and the Skagit delta are not in rivers.json); the report prints
   what was excused. A line is never silently redrawn.

Errors stop the build: an unknown site_id, a manual stop without coordinates, a
linked stop that also has coordinates, a bad stage, a stop id out of order, a
season with an end before its start. A value the source leaves out is an error,
not a default.
"""

import argparse
import datetime
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Artifacts" / "fishing-year" / "seasons.json"
OUT = ROOT / "Artifacts" / "fishing-year" / "data.js"
SITES = ROOT / "site" / "data" / "sites.json"
RIVERS = ROOT / "WAFishMap" / "Resources" / "rivers.json"

STAGES = {"lower", "mid", "upper"}
CATS = {"salmon", "fish", "crab"}
LINE_WARN_KM = 1.5
SOURCE_HOSTS = (
    "https://wdfw.wa.gov/",
    "https://www.eregulations.com/washington/fishing/",
)
RIVER_FEATURE = {
    "green": "Green River",
    "snoqualmie": "Snoqualmie River",
    "skykomish": "Skykomish River",
    "puyallup": "Puyallup River",
    "skagit": "Skagit River",
}


def seg_km(p, a, b):
    k = math.cos(math.radians(p[1]))
    ax, ay = (a[0] - p[0]) * 111.32 * k, (a[1] - p[1]) * 111.32
    bx, by = (b[0] - p[0]) * 111.32 * k, (b[1] - p[1]) * 111.32
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, -(ax * dx + ay * dy) / (dx * dx + dy * dy or 1.0)))
    return math.hypot(ax + t * dx, ay + t * dy)


def day(text, where, errors):
    try:
        return datetime.date.fromisoformat(text)
    except (TypeError, ValueError):
        errors.append(f"{where}: {text!r} is not a YYYY-MM-DD date")
        return None


def check_source(src, where, errors):
    if not isinstance(src, dict):
        errors.append(f"{where}: source must be an object with label, url and checked")
        return
    if not str(src.get("label", "")).strip():
        errors.append(f"{where}: source needs a label")
    if not str(src.get("url", "")).startswith(SOURCE_HOSTS):
        errors.append(f"{where}: source url must start with one of {SOURCE_HOSTS}")
    checked = day(src.get("checked"), f"{where} source checked", errors)
    if checked and checked > datetime.date.today():
        errors.append(f"{where}: source checked {src['checked']} is in the future")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    src = json.loads(SRC.read_text())
    sites = {s["id"]: s for s in json.loads(SITES.read_text())["sites"]}
    features = json.loads(RIVERS.read_text())["features"]
    errors, warnings, notes, unconfirmed = [], [], [], []

    ids = set()
    for s in src["seasons"]:
        where = f"season {s.get('id')}"
        if s["id"] in ids:
            errors.append(f"{where}: duplicate id")
        ids.add(s["id"])
        if s["cat"] not in CATS:
            errors.append(f"{where}: cat {s['cat']!r} not in {sorted(CATS)}")
        a, b = day(s["start"], where, errors), day(s["end"], where, errors)
        if a and b and b < a:
            errors.append(f"{where}: ends {s['end']} before it starts {s['start']}")
        if "pending" in s:
            if "source" in s:
                errors.append(f"{where}: a season is either sourced or pending, not both")
            if not str(s["pending"]).strip():
                errors.append(f"{where}: pending needs the reason the source is not out yet")
        if "source" in s:
            for n, x in enumerate(s["source"] if isinstance(s["source"], list) else [s["source"]]):
                check_source(x, f"{where} source {n}", errors)
    for m in src["milestones"]:
        day(m["date"], f"milestone {m.get('label')}", errors)
    for p in src["migration"]:
        for key in ("run", "spawn"):
            for lo, hi in p[key]:
                if not (0 <= lo < hi <= 12):
                    errors.append(
                        f"migration {p['name']} {key}: {lo}-{hi} outside 0-12"
                    )

    rivers, manual = [], 0
    for r in src["rivers"]:
        where = f"river {r['id']}"
        for n, rule in enumerate(r["rules"]):
            if "source" in rule:
                check_source(rule["source"], f"{where} rule {n}", errors)
        for n, s in enumerate(r.get("sources", [])):
            check_source(s, f"{where} sources[{n}]", errors)
        out_stops = []
        for i, st in enumerate(r["stops"], 1):
            sw = f"{where} stop {st.get('id')}"
            if st["id"] != i:
                errors.append(f"{sw}: ids must run 1..n in river order, expected {i}")
            if st["stage"] not in STAGES:
                errors.append(f"{sw}: stage {st['stage']!r} not in {sorted(STAGES)}")
            sid = st.get("site_id")
            has_xy = "lat" in st or "lon" in st
            stop = {k: v for k, v in st.items() if k != "site_id"}
            if sid:
                if sid not in sites:
                    errors.append(f"{sw}: site_id {sid!r} is not in sites.json")
                    continue
                if has_xy:
                    errors.append(f"{sw}: has site_id and its own lat/lon, keep one")
                stop["lat"], stop["lon"] = sites[sid]["lat"], sites[sid]["lon"]
            else:
                manual += 1
                pc = st.get("place_check")
                if not isinstance(pc, dict) or pc.get("source") != "OpenStreetMap":
                    errors.append(f"{sw}: a stop outside WDFW's layer needs a place_check against OpenStreetMap")
                else:
                    day(pc.get("checked"), f"{sw} place_check checked", errors)
                    if not isinstance(pc.get("confirmed"), bool):
                        errors.append(f"{sw}: place_check.confirmed must be true or false")
                    elif pc["confirmed"] and not (
                        str(pc.get("name", "")).strip()
                        and isinstance(pc.get("meters"), int)
                        and 0 <= pc["meters"] <= 250
                    ):
                        errors.append(f"{sw}: a confirmed place needs the OSM name and meters 0 to 250")
                    elif not pc["confirmed"]:
                        unconfirmed.append(f"{where} stop {st['id']} {st['name']}")
                if not (
                    isinstance(st.get("lat"), float)
                    and isinstance(st.get("lon"), float)
                ):
                    errors.append(f"{sw}: no site_id, so lat and lon are required")
            stop["pass"] = bool(st.get("pass", False))
            out_stops.append(stop)

        name = RIVER_FEATURE.get(r["id"])
        segs = [
            (ln[i], ln[i + 1])
            for f in features
            if f["properties"].get("name") == name
            for ln in f["geometry"]["coordinates"]
            for i in range(len(ln) - 1)
        ]
        if not segs:
            warnings.append(f"{where}: no {name!r} in rivers.json, line not checked")
        else:
            gaps = [min(seg_km(p, a, b) for a, b in segs) for p in r["line"]]
            skip = r.get("line_mouth_points", 0)
            if skip and not str(r.get("line_mouth_note", "")).strip():
                errors.append(f"{where}: line_mouth_points needs a line_mouth_note saying why")
            for n, g in enumerate(gaps[skip:], skip):
                if g > LINE_WARN_KM:
                    errors.append(
                        f"{where}: line point {n} is {g:.1f} km from rivers.json {name!r}"
                    )
            if skip:
                notes.append(
                    f"{where}: first {skip} line points ({max(gaps[:skip]):.1f} km at most) "
                    f"are outside rivers.json: {r['line_mouth_note']}"
                )
        rivers.append(
            {**{k: v for k, v in r.items() if k != "stops"}, "stops": out_stops}
        )

    print(
        f"seasons {len(src['seasons'])}, milestones {len(src['milestones'])}, "
        f"migration rows {len(src['migration'])}, rivers {len(rivers)}"
    )
    print(
        f"stops: {sum(len(r['stops']) for r in rivers)} "
        f"({manual} not in WDFW's access layer, own coordinates)"
    )
    unsourced = [s["id"] for s in src["seasons"] if "source" not in s]
    print(f"seasons with a WDFW source: {len(src['seasons']) - len(unsourced)} of {len(src['seasons'])}")
    for w in warnings:
        print("warning:", w)
    for n in notes:
        print("note:", n)
    for u in unconfirmed:
        print("unconfirmed place:", u)
    for e in errors:
        print("error:", e)
    if errors:
        return 1
    if args.check:
        return 0

    data = {
        "updated": src["updated"],
        "seasons": src["seasons"],
        "milestones": src["milestones"],
        "migration": src["migration"],
        "rivers": rivers,
    }
    OUT.write_text(
        "window.FY="
        + json.dumps(data, ensure_ascii=False, separators=(",", ":"))
        + ";\n"
    )
    print("wrote", OUT.relative_to(ROOT), OUT.stat().st_size, "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
