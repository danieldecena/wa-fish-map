#!/usr/bin/env python3
"""Write Artifacts/salmon-rivers/typical.js: the statewide "Typical season" snapshot.

    build_typical_sites.py [--refresh]

Sites come from site/data/sites.json (WDFW MajorFishingArea layers 0 and 1,
written by build_web_data.py: 477 access sites and 63 piers, the same endpoints
and counts the app reads). Marine areas are fetched from layer 6 with the URL
parameters MapScope.swift uses, and the raw response is cached in
.cache/wdfw/ (gitignored) so a rebuild does not need the network. --refresh
fetches again.

Each site is matched to its guidance exactly as FishingMapModel does it:
 1. marine area by point-in-polygon, else the nearest area edge within
    shoreSnapMeters (MarineArea.matching), except a facility curated onto a
    waterbody that has its own rows keeps that waterbody;
 2. a matched area that fisheries.json lists uses that area's species rows;
 3. everything else uses the freshwater table: statewide rows, refined by the
    county, refined by the waterbody, and (launches only) narrowed to the
    species WDFW lists for the lake the ramp sits on (Lake.match).
Months are copied verbatim from fisheries.json. The page does the rating.
"""

import argparse
import datetime
import json
import math
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "WAFishMap" / "Resources"
SWIFT = ROOT / "WAFishMap" / "Models"
SITES = ROOT / "site" / "data" / "sites.json"
CACHE = ROOT / ".cache" / "wdfw" / "marine-areas.geojson"
OUT = ROOT / "Artifacts" / "salmon-rivers" / "typical.js"

AREAS_URL = (
    "https://geodataservices.wdfw.wa.gov/arcgis/rest/services/FP_Projects/MajorFishingArea/MapServer/6/query"
    "?where=1%3D1&outFields=AreaName%2CAreaTitle%2CWAC&f=geojson&outSR=4326&maxAllowableOffset=0.002"
)
METRES_PER_DEGREE = 111_320.0
# Keys kept from a species row. bait and bestTime are not shown on the page.
ROW_KEYS = ("species", "bestMonths", "goodMonths", "note", "years", "seasonRisk")
SIZE_CAP = 1_500_000


def swift(name):
    return (SWIFT / name).read_text()


def swift_constants():
    """Read the matching constants out of the Swift source so they cannot drift."""
    marine = swift("MarineArea.swift")
    lake = swift("Lake.swift")
    river = swift("River.swift")
    snap = float(re.search(r"shoreSnapMeters: Double = ([\d.]+)", marine).group(1))
    reach = float(re.search(r"reachFactor = ([\d.]+)", lake).group(1))
    pad = float(re.search(r"reachPaddingMeters = ([\d.]+)", lake).group(1))
    wb = float(re.search(r"waterbodyMatchMeters: Double = ([\d.]+)", river).group(1))
    ignored = set(
        re.search(r"ignoredWords: Set<String> = \[(.*?)\]", lake, re.DOTALL)
        .group(1)
        .replace('"', "")
        .replace("\n", "")
        .replace(" ", "")
        .strip(",")
        .split(",")
    )
    qual = set(
        re.search(r"qualifierWords: Set<String> = \[(.*?)\]", lake, re.DOTALL)
        .group(1)
        .replace('"', "")
        .replace(" ", "")
        .split(",")
    )
    block = re.search(
        r"wdfwLakeSpecies: \[String: Set<String>\] = \[(.*?)\n    \]",
        swift("Fishery.swift"),
        re.DOTALL,
    ).group(1)
    mapping = {}
    for m in re.finditer(r'"([^"]+)": \[(.*?)\]', block):
        mapping[m.group(1)] = set(re.findall(r'"([^"]+)"', m.group(2)))
    if not mapping or not ignored or not qual:
        sys.exit("could not read the Swift constants; the source layout changed")
    return snap, reach, pad, wb, ignored, qual, mapping


SNAP, REACH, PAD, WB_METERS, IGNORED, QUALIFIERS, LAKE_SPECIES = swift_constants()


# ---- geometry ---------------------------------------------------------------


def ring_contains(ring, lon, lat):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        ax, ay = ring[i]
        bx, by = ring[j]
        if (ay > lat) != (by > lat) and lon < ax + (lat - ay) / (by - ay) * (bx - ax):
            inside = not inside
        j = i
    return inside


def seg_distance(lon, lat, a, b):
    scale = math.cos(math.radians(lat))
    ax, ay = (a[0] - lon) * scale * METRES_PER_DEGREE, (a[1] - lat) * METRES_PER_DEGREE
    bx, by = (b[0] - lon) * scale * METRES_PER_DEGREE, (b[1] - lat) * METRES_PER_DEGREE
    dx, dy = bx - ax, by - ay
    sq = dx * dx + dy * dy
    if sq <= 0:
        return math.hypot(ax, ay)
    t = min(1.0, max(0.0, -(ax * dx + ay * dy) / sq))
    return math.hypot(ax + t * dx, ay + t * dy)


class Area:
    def __init__(self, name, title, wac, rings):
        self.name, self.title, self.wac = name, title, wac
        self.rings = rings
        self.bounds = [
            (
                min(p[1] for p in r),
                max(p[1] for p in r),
                min(p[0] for p in r),
                max(p[0] for p in r),
            )
            for r in rings
        ]

    def contains(self, lon, lat):
        inside = False
        for r in self.rings:
            if ring_contains(r, lon, lat):
                inside = not inside
        return inside

    def edge_distance(self, lon, lat, within):
        best = math.inf
        lat_slack = within / METRES_PER_DEGREE
        lon_slack = within / (METRES_PER_DEGREE * math.cos(math.radians(lat)))
        for r, (la0, la1, lo0, lo1) in zip(self.rings, self.bounds):
            if len(r) < 2 or not (
                la0 - lat_slack <= lat <= la1 + lat_slack
                and lo0 - lon_slack <= lon <= lo1 + lon_slack
            ):
                continue
            j = len(r) - 1
            for i in range(len(r)):
                best = min(best, seg_distance(lon, lat, r[j], r[i]))
                j = i
        return best if best <= within else None


def load_areas(refresh):
    if refresh or not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(AREAS_URL, timeout=120) as r:
            CACHE.write_bytes(r.read())
    gj = json.loads(CACHE.read_text())
    areas = []
    for f in gj["features"]:
        p, g = f["properties"], f["geometry"]
        if p["AreaName"] == "Oregon":  # MapScope.filter: Oregon regulates it
            continue
        raw = (
            g["coordinates"]
            if g["type"] == "Polygon"
            else [r for poly in g["coordinates"] for r in poly]
        )
        rings = []
        for ring in raw:
            pts = [(c[0], c[1]) for c in ring if len(c) >= 2]
            if len(pts) >= 2 and pts[0] == pts[-1]:
                pts = pts[:-1]
            if len(pts) >= 3:
                rings.append(pts)
        if rings:
            areas.append(Area(p["AreaName"], p["AreaTitle"], p.get("WAC") or "", rings))
    return areas


def match_area(lon, lat, areas):
    for a in areas:
        if a.contains(lon, lat):
            return a
    best = None
    for a in areas:
        d = a.edge_distance(lon, lat, SNAP)
        if d is not None and (best is None or d < best[1]):
            best = (a, d)
    return best[0] if best else None


# ---- lakes (Lake.swift) -----------------------------------------------------


def haversine(lon1, lat1, lon2, lat2):
    r = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    h = (
        math.sin((p2 - p1) / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    )
    return 2 * r * math.asin(min(1.0, math.sqrt(h)))


def words(name):
    n = name.lower().replace("’", "'").replace("'s", "").replace("saint", "st")
    return [w for w in re.split(r"[^\w]+|_", n) if w]


def tokens(name):
    out = set()
    for w in words(name):
        if w in IGNORED:
            continue
        out.add(w[:-1] if len(w) > 3 and w.endswith("s") else w)
    return out


def within_one_edit(a, b):
    if a == b:
        return True
    if abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        return sum(1 for x, y in zip(a, b) if x != y) == 1
    short, long_ = (a, b) if len(a) < len(b) else (b, a)
    return any(long_[:i] + long_[i + 1 :] == short for i in range(len(long_)))


def names_agree(facility, lake):
    if not re.search(r"\b(lake|lakes|pond|ponds|reservoir)\b", facility, re.IGNORECASE):
        return True
    if set(words(facility)) & QUALIFIERS != set(words(lake)) & QUALIFIERS:
        return False
    ft, lt = tokens(facility), tokens(lake)
    if not ft or not lt:
        return words(facility) == words(lake)
    return any(
        a == b or (len(a) >= 3 and len(b) >= 3 and within_one_edit(a, b))
        for a in ft
        for b in lt
    )


def match_lake(facility, lon, lat, lakes):
    reach = []
    for lk in lakes:
        if not lk.get("acres") or lk["acres"] <= 0:
            continue
        radius = math.sqrt(lk["acres"] * 4046.86 / math.pi)
        if haversine(lon, lat, lk["longitude"], lk["latitude"]) <= REACH * radius + PAD:
            reach.append(lk)
    if len(reach) == 1 and names_agree(facility, reach[0]["name"]):
        return reach[0]
    return None


# ---- guidance (Fishery.swift) -----------------------------------------------


def clean(row):
    return {k: row[k] for k in ROW_KEYS if k in row}


def county_rows(fw, county):
    overrides = (fw.get("byCounty") or {}).get(county)
    if not overrides:
        return list(fw["species"])
    names = {r["species"] for r in overrides}
    return overrides + [r for r in fw["species"] if r["species"] not in names]


def water_rows(fw, county, waterbody):
    base = county_rows(fw, county)
    rows = (fw.get("byWaterbody") or {}).get(waterbody) if waterbody else None
    if not rows:
        return base
    names = {r["species"] for r in rows}
    return rows + [r for r in base if r["species"] not in names]


def lake_filtered(fw, county, waterbody, lake_species):
    merged = water_rows(fw, county, waterbody)
    if not lake_species:
        return merged
    listed = set(lake_species)
    curated = (
        {r["species"] for r in (fw.get("byWaterbody") or {}).get(waterbody, [])}
        if waterbody
        else set()
    )
    kept = []
    for r in merged:
        s = r["species"]
        if s in curated or s not in LAKE_SPECIES or LAKE_SPECIES[s] & listed:
            kept.append(r)
    return kept or None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--refresh", action="store_true", help="fetch marine areas again")
    args = ap.parse_args()

    fish = json.loads((RES / "fisheries.json").read_text())
    fw = fish["freshwater"]
    area_rows = {a["areaName"]: a["species"] for a in fish["areas"]}
    lakes = json.loads((RES / "lakes.json").read_text())["lakes"]
    areas = load_areas(args.refresh)
    src = json.loads(SITES.read_text())

    # A river name used as a waterbody key would need River.nearest; none is today.
    river_names = {
        f["properties"]["name"]
        for f in json.loads((RES / "rivers.json").read_text())["features"]
        if f["properties"].get("kind") == "river"
        and f["properties"].get("id") == f["properties"]["name"]
    }
    clash = [k for k in (fw.get("byWaterbody") or {}) if k in river_names]
    if clash:
        sys.exit(
            f"byWaterbody now keys a river ({clash}); this script does not resolve rivers yet"
        )
    curated = {
        fac: wb for wb, facs in (fw.get("waterbodySites") or {}).items() for fac in facs
    }

    guides, guide_index, sites, counts = [], {}, [], {}

    def guide_for(scope, kind, area, rows):
        key = json.dumps([scope, [clean(r) for r in rows]], sort_keys=True)
        if key not in guide_index:
            guide_index[key] = len(guides)
            guides.append(
                {
                    "scope": scope,
                    "kind": kind,
                    "area": area,
                    "rows": [clean(r) for r in rows],
                }
            )
        return guide_index[key]

    for s in src["sites"]:
        is_pier = s["kind"] == "pier"
        kind = "pier" if is_pier else ("launch" if s["launch"] else "access")
        lon, lat = s["lon"], s["lat"]
        wb = curated.get(s["name"])
        area = None
        # FishingMapModel.marineArea: containment wins; the shore snap does not.
        inside = next((a for a in areas if a.contains(lon, lat)), None)
        if inside:
            area = inside
        elif not (wb and (fw.get("byWaterbody") or {}).get(wb)):
            area = match_area(lon, lat, areas)
        g = None
        if area is not None and area.name in area_rows:
            g = guide_for(
                "area:" + area.name, "marine", area.name, area_rows[area.name]
            )
        else:
            lake_sp = None
            if not is_pier and area is None:
                lk = match_lake(s["name"], lon, lat, lakes)
                lake_sp = lk["species"] if lk else None
            rows = lake_filtered(fw, s["county"], wb if area is None else None, lake_sp)
            if rows:
                scope = (
                    f"waterbody:{wb}"
                    if wb and area is None and (fw.get("byWaterbody") or {}).get(wb)
                    else (
                        f"county:{s['county']}"
                        if (fw.get("byCounty") or {}).get(s["county"])
                        else "statewide"
                    )
                )
                g = guide_for(scope, "fresh", None, rows)
        site = {
            "id": s["id"],
            "name": s["name"],
            "kind": kind,
            "lat": round(lat, 4),
            "lon": round(lon, 4),
            "county": s["county"],
            "area": area.name if area else None,
            "guide": g,
        }
        if is_pier and re.search(r"\(closed\)", s["name"], re.IGNORECASE):
            site["closed"] = True
        sites.append(site)
        counts[
            (
                kind,
                "area" if area else "no area",
                "guidance" if g is not None else "gray",
            )
        ] = (
            counts.get(
                (
                    kind,
                    "area" if area else "no area",
                    "guidance" if g is not None else "gray",
                ),
                0,
            )
            + 1
        )

    used = {r["species"] for g in guides for r in g["rows"]}
    marine = {r["species"] for g in guides if g["kind"] == "marine" for r in g["rows"]}
    fresh = {r["species"] for g in guides if g["kind"] == "fresh" for r in g["rows"]}
    species = [
        {
            "name": n,
            "water": "both"
            if n in marine and n in fresh
            else ("salt" if n in marine else "fresh"),
        }
        for n in sorted(used)
    ]

    data = {
        "generated": datetime.datetime.now().astimezone().date().isoformat(),
        "guideUpdated": fish["updated"],
        "wdfwURL": fish["wdfwURL"],
        "seasonRisk": fish["seasonRisk"],
        "areas": {
            a.name: {"title": a.title, "wac": a.wac}
            for a in areas
            if a.name in area_rows
        },
        "species": species,
        "guides": guides,
        "sites": sites,
    }
    body = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    js = (
        "/* Generated by scripts/build_typical_sites.py on "
        + data["generated"]
        + "; Generated, do not edit.\n"
        " * Statewide WDFW shore access, launches and piers matched to the WA Fish Map seasonal guidance.\n"
        " * Typical timing from the app's curated guidance, not a catch report and not a claim a fishery is open. */\n"
        "(function (root, factory) {\n"
        "  if (typeof module === 'object' && module.exports) module.exports = factory();\n"
        "  else root.TypicalData = factory();\n"
        "})(typeof self !== 'undefined' ? self : this, function () {\n"
        "  'use strict';\n"
        "  return " + body + ";\n"
        "});\n"
    )
    if len(js.encode()) > SIZE_CAP:
        sys.exit(
            f"typical.js would be {len(js.encode())} bytes, over the {SIZE_CAP} cap; nothing written"
        )
    OUT.write_text(js)

    by_kind = {}
    for (k, a, g), n in sorted(counts.items()):
        by_kind.setdefault(k, {})[f"{a}/{g}"] = n
    print(
        f"wrote {OUT}: {len(sites)} sites, {len(guides)} guides, {len(species)} species, {len(js.encode()) // 1024} KB"
    )
    for k, v in by_kind.items():
        print(f"  {k}: {sum(v.values())} {v}")


if __name__ == "__main__":
    main()
