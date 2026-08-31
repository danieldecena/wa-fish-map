#!/usr/bin/env python3
"""Validate the statewide WDFW contract WAFishMap depends on (Linux CI friendly).

Checks, in order:
1. Marine layer (6): the live AreaName set matches the known statewide set.
2. fisheries.json: valid JSON, schema shape, months 1-12, and every areaName
   exists in the live marine layer (exact-string match — the app does no
   normalization).
3. Access-site layer (0) and pier layer (1): reachable, non-trivial feature
   counts, and safely under the server's maxRecordCount (the app rejects
   truncated responses; this warns before that ever fires).
4. Spot checks that the bundled fixtures' anchor features still exist live.
"""
from __future__ import annotations

import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

MAP_SERVER = (
    "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/"
    "FP_Projects/MajorFishingArea/MapServer"
)

# The full statewide AreaName set as of 2026-08-30. "Oregon" (North of Falcon)
# exists in the layer but is deliberately unseeded in fisheries.json.
EXPECTED_AREA_NAMES = {
    "1", "2", "2-1", "2-2", "3", "4", "5", "6", "7",
    "8-1", "8-2", "9", "10", "11", "12", "13", "Oregon",
}

FISHERIES_PATH = (
    Path(__file__).resolve().parent.parent / "WAFishMap" / "Resources" / "fisheries.json"
)

# Headroom before a layer's feature count approaches maxRecordCount and the
# app's truncation guard would start rejecting responses.
COUNT_HEADROOM = 0.8


def fetch(layer: int, params: dict) -> dict:
    url = f"{MAP_SERVER}/{layer}/query?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.load(resp)


def layer_meta(layer: int) -> dict:
    url = f"{MAP_SERVER}/{layer}?f=json"
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.load(resp)


def feature_count(layer: int, where: str = "1=1") -> int:
    return fetch(layer, {"where": where, "returnCountOnly": "true", "f": "json"})["count"]


def check_marine_areas(failures: list[str]) -> set[str]:
    data = fetch(6, {
        "where": "1=1",
        "outFields": "AreaName,AreaTitle",
        "returnGeometry": "false",
        "f": "json",
    })
    live = {f["attributes"]["AreaName"] for f in data.get("features", [])}
    if live != EXPECTED_AREA_NAMES:
        missing = EXPECTED_AREA_NAMES - live
        extra = live - EXPECTED_AREA_NAMES
        failures.append(
            f"marine AreaName drift — missing: {sorted(missing)}, new: {sorted(extra)}"
        )
    print(f"live marine areas: {len(live)}")
    return live


def check_fisheries(live_areas: set[str], failures: list[str]) -> None:
    try:
        guide = json.loads(FISHERIES_PATH.read_text())
    except (OSError, json.JSONDecodeError) as e:
        failures.append(f"fisheries.json unreadable: {e}")
        return

    for key in ("updated", "disclaimer", "wdfwURL", "areas"):
        if key not in guide:
            failures.append(f"fisheries.json missing top-level '{key}'")

    def check_species(owner: str, entries: list) -> None:
        for s in entries:
            name = s.get("species", "<unnamed>")
            if not s.get("bestMonths"):
                failures.append(f"{owner}/{name}: empty bestMonths")
            for m in s.get("bestMonths", []) + s.get("goodMonths", []):
                if not (isinstance(m, int) and 1 <= m <= 12):
                    failures.append(f"{owner}/{name}: bad month {m!r}")

    seeded = []
    for area in guide.get("areas", []):
        name = area.get("areaName", "<missing>")
        seeded.append(name)
        if name not in live_areas:
            failures.append(f"fisheries area {name!r} not in live WDFW layer")
        if not area.get("species"):
            failures.append(f"fisheries area {name!r} has no species")
        check_species(f"area {name}", area.get("species", []))

    if len(seeded) != len(set(seeded)):
        dupes = sorted({n for n in seeded if seeded.count(n) > 1})
        failures.append(f"duplicate fisheries areaNames: {dupes}")

    freshwater = guide.get("freshwater", {})
    check_species("freshwater default", freshwater.get("species", []))
    for county, entries in (freshwater.get("byCounty") or {}).items():
        if county.endswith("County"):
            failures.append(f"byCounty key {county!r} must not carry a 'County' suffix")
        check_species(f"county {county}", entries)

    print(f"fisheries.json: {len(seeded)} areas, "
          f"{len((freshwater.get('byCounty') or {}))} counties, updated {guide.get('updated')}")


def check_point_layer(layer: int, label: str, minimum: int, failures: list[str]) -> None:
    count = feature_count(layer)
    max_records = layer_meta(layer).get("maxRecordCount", 0)
    print(f"live {label}: {count} features (server limit {max_records})")
    if count < minimum:
        failures.append(f"{label}: only {count} features (expected >= {minimum})")
    if max_records and count >= max_records * COUNT_HEADROOM:
        failures.append(
            f"{label}: {count} features is within {int((1 - COUNT_HEADROOM) * 100)}% of "
            f"maxRecordCount {max_records} — the app has no pagination; add it before "
            f"the layer truncates"
        )


def check_fixture_anchors(failures: list[str]) -> None:
    sites = fetch(0, {
        "where": "Launch=1 AND CountyName='Thurston'",
        "outFields": "FacilityName",
        "returnGeometry": "false",
        "f": "json",
    })
    names = {f["attributes"]["FacilityName"] for f in sites.get("features", [])}
    anchors = ("Boston Harbor", "Luhr's Landing")
    for required in anchors:
        if required not in names:
            failures.append(f"fixture anchor launch {required!r} gone from live layer")
    print(f"fixture anchors present: {sorted(names & set(anchors))}")


def main() -> int:
    failures: list[str] = []
    live_areas = check_marine_areas(failures)
    check_fisheries(live_areas, failures)
    check_point_layer(0, "access sites", minimum=100, failures=failures)
    check_point_layer(1, "piers", minimum=10, failures=failures)
    check_fixture_anchors(failures)

    if failures:
        print("FAIL:", "; ".join(failures), file=sys.stderr)
        return 1
    print("OK: statewide WDFW contract validates")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
