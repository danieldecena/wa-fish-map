#!/usr/bin/env python3
"""Validate WDFW endpoints and GeoJSON fixture shape for WAFishMap (Linux CI)."""
from __future__ import annotations

import json
import sys
import urllib.parse
import urllib.request

MAP_SERVER = (
    "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/"
    "FP_Projects/MajorFishingArea/MapServer"
)


def fetch_geojson(layer: int, where: str, extra: dict | None = None) -> dict:
    params = {
        "where": where,
        "f": "geojson",
        "outSR": "4326",
        **(extra or {}),
    }
    url = f"{MAP_SERVER}/{layer}/query?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.load(resp)


def outer_ring_vertices(feature: dict) -> int:
    rings = feature["geometry"]["coordinates"]
    return len(rings[0]) - 1 if rings[0][0] == rings[0][-1] else len(rings[0])


def main() -> int:
    failures: list[str] = []

    marine = fetch_geojson(
        6,
        "AreaName='13'",
        {
            "outFields": "AreaName,AreaTitle,WAC",
            "maxAllowableOffset": "0.002",
        },
    )
    feats = marine.get("features", [])
    if len(feats) != 1:
        failures.append(f"expected 1 marine feature, got {len(feats)}")
    else:
        props = feats[0]["properties"]
        if props.get("AreaName") != "13":
            failures.append(f"AreaName={props.get('AreaName')!r}")
        if props.get("AreaTitle") != "South Puget Sound":
            failures.append(f"AreaTitle={props.get('AreaTitle')!r}")
        verts = outer_ring_vertices(feats[0])
        if verts < 10:
            failures.append(f"area 13 outer ring too small: {verts} verts")

    sites = fetch_geojson(
        0,
        "Launch=1 AND CountyName='Thurston'",
        {
            "outFields": "FacilityName,CountyName,Launch,LaunchType",
        },
    )
    site_feats = sites.get("features", [])
    names = {f["properties"]["FacilityName"] for f in site_feats}
    for required in ("Boston Harbor", "Luhr's Landing"):
        if required not in names:
            failures.append(f"missing launch {required!r}")
    if len(site_feats) < 2:
        failures.append(f"expected >=2 Thurston launches, got {len(site_feats)}")

    print(f"live marine area 13: {len(feats)} feature(s), {verts if feats else 0} outer verts")
    print(f"live Thurston launches: {len(site_feats)} sites")
    print(f"  includes Boston Harbor: {'Boston Harbor' in names}")
    print(f"  includes Luhr's Landing: {\"Luhr's Landing\" in names}")

    if failures:
        print("FAIL:", "; ".join(failures), file=sys.stderr)
        return 1
    print("OK: WDFW live slice validates for Area 13 + Thurston")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
