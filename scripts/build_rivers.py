#!/usr/bin/env python3
"""Generate WAFishMap/Resources/rivers.json from the USGS NHD small-scale flowlines.

The app draws named fishable rivers, not the full state hydrography — tens of
thousands of creek segments would recreate the pin-legibility problem the
clustering work just solved. So this keeps flowlines whose GNIS name ends in
"River" and whose segments total at least MIN_LENGTH_KM, then merges each
river's segments into one MultiLineString.

FTYPE is the trap here. NHD models any river wide enough to be mapped as an
*area* with ArtificialPath flowlines threaded through that polygon, so a
StreamRiver-only filter silently drops the biggest rivers in the state: the
Skagit is 186km of ArtificialPath against 4.9km of StreamRiver, and the
Columbia is 1068km against 8.8km. The output still looked healthy — 315 rivers
with a plausible stream-order spread — which is why EXPECTED_RIVERS exists
below and is checked before anything is written.

Simplification is done server-side via maxAllowableOffset, the same knob
MapScope.swift already uses for the marine-area polygons, rather than
reimplementing Douglas-Peucker here.

Output is deterministic: rivers sorted by name, segments sorted by their first
coordinate, coordinates rounded to COORD_PLACES. Re-running on unchanged
upstream data produces a byte-identical file.

    ./scripts/build_rivers.py [--out PATH]
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

LAYER = "https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/4/query"

# Washington, generously bounded. The layer is national, so this is the filter
# that makes the query tractable; segments of a river that leave the state
# (the Columbia, the Snake) are clipped at the box and that is fine.
WA_ENVELOPE = "-124.85,45.50,-116.90,49.10"

# ArcGIS caps a single response; the layer reports maxRecordCount 2000.
PAGE_SIZE = 2000

# Degrees. 0.002 is what MapScope uses for marine areas — about 150m, which is
# below a hairline at every zoom the app draws rivers at.
MAX_ALLOWABLE_OFFSET = 0.002

# Rivers shorter than this are omitted. A named river under 8km is a tributary
# nobody drives to, and keeping them triples the file for no legibility gain.
MIN_LENGTH_KM = 8.0

COORD_PLACES = 5

# The envelope above reaches into Oregon and Idaho, so rivers are clipped to the
# actual state polygon. A river counts as Washington's if any vertex lands in it.
STATE_LAYER = (
    "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/"
    "State_County/MapServer/0/query"
)
WA_FIPS = "53"

# Anchors. Every one of these was missing or a fragment under the StreamRiver
# filter, so this list is the check that would have caught it. It is checked
# against a known-good expectation, not merely against "the query returned rows".
EXPECTED_RIVERS = {
    "Columbia River",
    "Snake River",
    "Skagit River",
    "Skykomish River",
    "Yakima River",
    "Cowlitz River",
    "Methow River",
    "Chehalis River",
    "Hoh River",
    "Wenatchee River",
}

DEFAULT_OUT = Path(__file__).resolve().parent.parent / "WAFishMap/Resources/rivers.json"


def fetch_page(offset: int) -> dict:
    params = {
        "where": (
            "FTYPE IN ('StreamRiver','ArtificialPath','Connector') "
            "AND GNIS_NAME LIKE '% River'"
        ),
        "geometry": WA_ENVELOPE,
        "geometryType": "esriGeometryEnvelope",
        "inSR": "4326",
        "spatialRel": "esriSpatialRelIntersects",
        "outFields": "GNIS_NAME,StreamOrde,LENGTHKM",
        "maxAllowableOffset": str(MAX_ALLOWABLE_OFFSET),
        "outSR": "4326",
        "orderByFields": "OBJECTID",
        "resultOffset": str(offset),
        "resultRecordCount": str(PAGE_SIZE),
        "f": "geojson",
    }
    url = f"{LAYER}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=120) as response:
        return json.load(response)


def fetch_all() -> list[dict]:
    features: list[dict] = []
    offset = 0
    while True:
        page = fetch_page(offset)
        if "error" in page:
            raise SystemExit(f"NHD query failed at offset {offset}: {page['error']}")
        batch = page.get("features", [])
        features.extend(batch)
        print(f"  offset {offset}: {len(batch)} features", file=sys.stderr)
        if len(batch) < PAGE_SIZE:
            return features
        offset += PAGE_SIZE


def fetch_state_rings() -> list[list[list[float]]]:
    params = {
        "where": f"STATE='{WA_FIPS}'",
        "outFields": "NAME",
        "maxAllowableOffset": "0.01",
        "outSR": "4326",
        "f": "geojson",
    }
    url = f"{STATE_LAYER}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=120) as response:
        collection = json.load(response)
    rings: list[list[list[float]]] = []
    for feature in collection.get("features", []):
        geometry = feature.get("geometry") or {}
        if geometry.get("type") == "Polygon":
            rings.extend(geometry["coordinates"])
        elif geometry.get("type") == "MultiPolygon":
            for polygon in geometry["coordinates"]:
                rings.extend(polygon)
    if not rings:
        raise SystemExit("state boundary query returned no geometry")
    return rings


def ring_contains(ring: list[list[float]], lon: float, lat: float) -> bool:
    """Ray cast, matching LonLat.polygon(_:contains:) in the app."""
    inside = False
    count = len(ring)
    for i in range(count):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[(i + 1) % count][0], ring[(i + 1) % count][1]
        if (y1 > lat) != (y2 > lat):
            if lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
                inside = not inside
    return inside


def touches_state(lines: list[list[list[float]]], rings: list[list[list[float]]]) -> bool:
    for line in lines:
        for lon, lat in line:
            if any(ring_contains(ring, lon, lat) for ring in rings):
                return True
    return False


def segments(geometry: dict) -> list[list[list[float]]]:
    """A flowline arrives as LineString or, rarely, MultiLineString."""
    kind = geometry.get("type")
    if kind == "LineString":
        return [geometry["coordinates"]]
    if kind == "MultiLineString":
        return list(geometry["coordinates"])
    return []


def round_line(line: list[list[float]]) -> list[list[float]]:
    rounded = [[round(pt[0], COORD_PLACES), round(pt[1], COORD_PLACES)] for pt in line]
    # Simplification can collapse consecutive vertices onto each other.
    deduped = [rounded[0]]
    for point in rounded[1:]:
        if point != deduped[-1]:
            deduped.append(point)
    return deduped


def build(features: list[dict], rings: list[list[list[float]]]) -> dict:
    rivers: dict[str, dict] = {}
    for feature in features:
        props = feature.get("properties") or {}
        name = (props.get("GNIS_NAME") or "").strip()
        geometry = feature.get("geometry")
        if not name or not geometry:
            continue
        river = rivers.setdefault(name, {"lines": [], "order": 0, "lengthKm": 0.0})
        for line in segments(geometry):
            if len(line) >= 2:
                river["lines"].append(round_line(line))
        river["order"] = max(river["order"], int(props.get("StreamOrde") or 0))
        river["lengthKm"] += float(props.get("LENGTHKM") or 0.0)

    out = []
    for name in sorted(rivers):
        river = rivers[name]
        lines = [line for line in river["lines"] if len(line) >= 2]
        if not lines or river["lengthKm"] < MIN_LENGTH_KM:
            continue
        if not touches_state(lines, rings):
            continue
        lines.sort()
        out.append(
            {
                "type": "Feature",
                "geometry": {"type": "MultiLineString", "coordinates": lines},
                "properties": {
                    "name": name,
                    "streamOrder": river["order"],
                    "lengthKm": round(river["lengthKm"], 1),
                },
            }
        )
    return {"type": "FeatureCollection", "features": out}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    print("Fetching NHD small-scale flowlines for Washington…", file=sys.stderr)
    try:
        features = fetch_all()
    except (urllib.error.URLError, TimeoutError) as error:
        raise SystemExit(f"NHD unreachable: {error}")
    print(f"{len(features)} flowline segments", file=sys.stderr)

    print("Fetching the Washington boundary…", file=sys.stderr)
    rings = fetch_state_rings()

    collection = build(features, rings)
    found = {feature["properties"]["name"] for feature in collection["features"]}
    missing = sorted(EXPECTED_RIVERS - found)
    if missing:
        raise SystemExit(
            "anchor rivers absent from the build, so the filter is wrong rather "
            f"than the data: {', '.join(missing)}"
        )
    args.out.write_text(
        json.dumps(collection, sort_keys=True, separators=(",", ":")) + "\n"
    )
    vertices = sum(
        len(line)
        for feature in collection["features"]
        for line in feature["geometry"]["coordinates"]
    )
    size_kb = args.out.stat().st_size / 1024
    print(
        f"{len(collection['features'])} rivers, {vertices} vertices, "
        f"{size_kb:.0f} KB -> {args.out}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
