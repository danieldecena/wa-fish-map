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
import heapq
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


# The page projects lon/lat with the constants in geo.js; the basemap paths below use the same ones.
GEO = ROOT / "Artifacts" / "salmon-rivers" / "geo.js"
# Washington's land borders that are straight lines, for orientation only: the 49th parallel from
# Semiahmoo Bay to the Idaho line, the 117.04 W meridian south to Lewiston, and the 46th parallel
# from the Columbia to the Snake. Every other edge is a river (already in geo.js) or the coast.
BORDER = [
    [(-122.77, 49.0), (-117.03, 49.0), (-117.04, 46.42)],
    [(-119.0, 46.0), (-116.92, 46.0)],
]


# The land tint and the state outline use only geometry the page already carries. The inland edge is the
# straight borders above plus the Columbia found in geo.js (from the 46th parallel to its mouth); no
# border is typed in by hand. geo.js has no Snake River below Lewiston (the Idaho line), so the tint
# crosses that short edge in a straight line and the outline leaves it open, as the dashed line did. The tint
# polygon is closed through marine-area water (a route listed below, checked to lie inside the WDFW
# polygons), which the page paints over, so the tint only shows on land and never on Canada or Oregon.
LEWISTON = (-117.04, 46.42)
SNAKE_MOUTH = (-116.92, 46.0)  # where the 46th parallel meets the Idaho line
COLUMBIA_46 = (-119.0, 46.0)
TONGUE_POINT = (-123.76, 46.21)
# lon/lat waypoints from the Columbia mouth, offshore to Cape Flattery, along the Strait of Juan de Fuca
# band, then north through Haro and Rosario Straits to Semiahmoo. `free` legs cross land or an estuary.
CLOSURE = [
    ((-124.12, 46.26), True),
    ((-124.95, 46.30), False),
    ((-124.95, 48.40), False),
    ((-124.40, 48.35), True),
    ((-124.18, 48.28), False),
    ((-124.00, 48.19), False),
    ((-122.90, 48.19), False),
    ((-123.00, 48.40), False),
    ((-123.00, 48.65), False),
    ((-122.85, 48.82), False),
    ((-122.90, 48.94), False),
    ((-122.77, 49.0), False),
]


def frags_of(d):
    out = []
    for part in d.split("M"):
        n = [float(v) for v in part.replace("L", " ").split()]
        if len(n) >= 4:
            out.append([(n[i], n[i + 1]) for i in range(0, len(n) - 1, 2)])
    return out


def river_route(frags, start, goal, tol):
    """Shortest path along river fragments (joined where endpoints meet) between the nodes nearest two points."""
    key = lambda q: (round(q[0], 1), round(q[1], 1))
    adj = {}
    for f in frags:
        w = sum(math.dist(f[i], f[i + 1]) for i in range(len(f) - 1))
        adj.setdefault(key(f[0]), []).append((key(f[-1]), w, f))
        adj.setdefault(key(f[-1]), []).append((key(f[0]), w, f[::-1]))
    # Fragments drawn at different resolutions can stop a fraction of a unit apart: join endpoints closer than 1.
    cells = {}
    for q in adj:
        cells.setdefault((int(q[0]), int(q[1])), []).append(q)
    for q in list(adj):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for r in cells.get((int(q[0]) + dx, int(q[1]) + dy), []):
                    if r != q and math.dist(q, r) < 1.0:
                        adj[q].append((r, math.dist(q, r), [q, r]))

    def nearest(pt):
        k = min(adj, key=lambda q: math.dist(q, pt))
        if math.dist(k, pt) > tol:
            sys.exit(f"no river node within {tol} map units of {pt}")
        return k

    src, dst = nearest(start), nearest(goal)
    dist, prev, heap = {src: 0.0}, {}, [(0.0, src)]
    while heap:
        d, u = heapq.heappop(heap)
        if u == dst:
            break
        if d > dist.get(u, 1e18):
            continue
        for v, w, f in adj[u]:
            if d + w < dist.get(v, 1e18):
                dist[v] = d + w
                prev[v] = (u, f)
                heapq.heappush(heap, (d + w, v))
    if dst not in prev and src != dst:
        sys.exit(f"no river route from {start} to {goal}")
    path, u = [], dst
    while u != src:
        u, f = prev[u]
        path = f + path
    out = []
    for q in path:
        if not out or out[-1] != q:
            out.append(q)
    return out


def land_outline(areas, proj):
    """(land polygon path, outline path) in map units. Checks the water route and the river borders as it goes."""
    t = GEO.read_text()
    geo = json.loads(t[t.index("{") : t.rindex("}") + 1])
    columbia = river_route(
        frags_of(geo["hl"]["columbia"])
        + frags_of(geo["base"]["7"])
        + frags_of(geo["base"]["6"]),
        proj(*COLUMBIA_46),
        proj(*TONGUE_POINT),
        6,
    )
    # The Columbia route must end at Tongue Point and start at the 46th parallel, and be long enough to be the river.
    if (
        math.dist(columbia[-1], proj(*TONGUE_POINT)) > 6
        or math.dist(columbia[0], proj(*COLUMBIA_46)) > 6
    ):
        sys.exit("the Columbia route does not reach both ends")
    if (
        sum(math.dist(columbia[i], columbia[i + 1]) for i in range(len(columbia) - 1))
        < 380
    ):
        sys.exit("the Columbia route is too short to be the river")
    # Every non-free leg of the closure must lie inside a marine-area polygon (or one of its island holes, which is
    # Washington land), so the tint can never reach Canadian land or water.
    x0, y0 = proj(0.0, 0.0)
    kx, ky = proj(1.0, 0.0)[0] - x0, proj(0.0, 1.0)[1] - y0
    unproj = lambda x, y: ((x - x0) / kx, (y - y0) / ky)
    here = columbia[-1]
    legs = []
    for (lon, lat), free in CLOSURE:
        a = here
        b = proj(lon, lat)
        if not free:
            n = max(2, int(math.dist(a, b) / 0.5))
            for i in range(n + 1):
                x, y = a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n
                lo, la = unproj(x, y)
                # A sample on a polygon edge can read as outside; a 300 m nudge in any direction settles it.
                if not any(
                    ring_contains(r, lo + dx, la + dy)
                    for dx, dy in (
                        (0, 0),
                        (0.003, 0),
                        (-0.003, 0),
                        (0, 0.003),
                        (0, -0.003),
                    )
                    for ar in areas
                    for r in ar.rings
                ):
                    sys.exit(
                        f"closure leg to ({lon}, {lat}) leaves the marine-area water at map ({x:.1f}, {y:.1f})"
                    )
        legs.append(b)
        here = b
    top_left = proj(-122.77, 49.0)
    ne = proj(-117.03, 49.0)
    lewiston = proj(-117.04, 46.42)
    tail = proj(*SNAKE_MOUTH)
    mcnary = proj(*COLUMBIA_46)
    land = [top_left, ne, lewiston, tail, mcnary] + columbia + legs
    outline = [[top_left, ne, lewiston], [tail, mcnary] + columbia]
    return land, outline


def projection():
    m = re.search(
        r'"proj":\{"kx":([\d.]+),"k":([\d.]+),"lat0":([\d.]+),"lon0":(-?[\d.]+)\}',
        GEO.read_text()[:400],
    )
    if not m:
        sys.exit("could not read the projection from geo.js")
    kx, k, lat0, lon0 = (float(g) for g in m.groups())
    return lambda lon, lat: ((lon - lon0) * kx, (lat0 - lat) * k)


def path_of(rings, proj, close):
    """SVG path in map units, one decimal like geo.js, repeated points dropped."""
    parts = []
    for ring in rings:
        pts = []
        for lon, lat in ring:
            x, y = proj(lon, lat)
            q = (round(x, 1), round(y, 1))
            if not pts or pts[-1] != q:
                pts.append(q)
        if len(pts) >= 2:
            parts.append(
                "M" + " ".join(f"{x:g} {y:g}" for x, y in pts) + ("Z" if close else "")
            )
    return "".join(parts)


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

    land, outline = land_outline(areas, projection())
    land_path = (
        "M" + " ".join(f"{round(x, 1):g} {round(y, 1):g}" for x, y in land) + "Z"
    )
    outline_path = "".join(
        "M" + " ".join(f"{round(x, 1):g} {round(y, 1):g}" for x, y in ln)
        for ln in outline
    )

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
        "basemap": {
            "water": path_of([r for a in areas for r in a.rings], projection(), True),
            "border": path_of(BORDER, projection(), False),
            "land": land_path,
            "outline": outline_path,
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
