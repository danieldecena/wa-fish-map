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
            sys.exit(
                f"two lakes share coordinate {(lon, lat)}; the species join needs them unique"
            )
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
                sys.exit(
                    f"{species} row {f['attributes']['LakeName']!r} matches no lake point"
                )
            lake["species"].append(species)

    if len(lakes) < MIN_LAKES:
        sys.exit(f"only {len(lakes)} lakes, expected at least {MIN_LAKES}")
    names = {lake["name"] for lake in lakes.values()}
    missing = [n for n in MUST_HAVE if n not in names]
    if missing:
        sys.exit(f"expected lakes missing: {missing}")

    print(
        f"{len(lakes)} lakes, {skipped_null} null-name species rows skipped",
        file=sys.stderr,
    )
    ordered = sorted(
        lakes.values(), key=lambda x: (x["name"], x["longitude"], x["latitude"])
    )
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
    args.out.write_text(
        json.dumps(data, indent=1, ensure_ascii=False, sort_keys=False) + "\n"
    )


if __name__ == "__main__":
    main()
