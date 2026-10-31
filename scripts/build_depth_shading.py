#!/usr/bin/env python3
"""Write Artifacts/salmon-rivers/depth-shading.js: depth shading for Puget Sound, baked from
NOAA's CUDEM bathymetry, for the map's Depth shading layer.

    build_depth_shading.py fetch --work DIR [--only dem|soundings|vdatum]
    build_depth_shading.py build --work DIR [--check]

Needs numpy, pillow, scipy and tifffile, which the system python on this Mac does not have.
Make a venv outside the repo (never install into the repo or the system python) and run the
script with -I so it reads nothing from the download directory:

    /opt/homebrew/bin/python3 -m venv "$SCRATCH/venv"
    "$SCRATCH/venv/bin/pip" install numpy pillow scipy scikit-image tifffile
    "$SCRATCH/venv/bin/python" -I scripts/build_depth_shading.py fetch --work "$SCRATCH/work"
    "$SCRATCH/venv/bin/python" -I scripts/build_depth_shading.py build --work "$SCRATCH/work"

`fetch` downloads, into --work (an empty directory outside the repo): CUDEM 1/9 arc-second
heights from NOAA NCEI's ImageServer, resampled by the server to 1/3 arc-second, one window
per output tile; the NOAA ENC spot soundings over the same box from encdirect; and NOAA
VDatum's NAVD88-to-MLLW separation on a coarse grid over the water. `build` reads those
plus the marine area outlines in Artifacts/salmon-rivers/marine-areas.js and writes the
generated file and a report (scripts/fixtures/depth-shading-report.json). The page makes no
network request: every image is a data URI inside depth-shading.js.

Heights are metres on NAVD88; the page's contours are feet below low tide (MLLW). The datum
step is the point of this script, see "Datum" below. The result is a model of the seabed,
not a survey and not sonar. Not for navigation.

Datum. One NAVD88-to-MLLW constant per area (the spike's way) left DEM-minus-ENC at
+1.3 to +1.9 ft in deep, flat water. Here the separation is NOAA VDatum's, sampled every
~2 km over the water and interpolated, and the median that remains against the ENC
soundings is measured per sub-region and written to the report; see the README.
"""

import argparse
import base64
import colorsys
import io
import json
import math
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

try:
    import numpy as np
    import tifffile
    from PIL import Image, ImageDraw
    from scipy import ndimage
except ImportError:  # the pure helpers and their tests still work without the stack
    np = None

REPO = Path(__file__).resolve().parent.parent
PAGE = REPO / "Artifacts" / "salmon-rivers"
MARINE = PAGE / "marine-areas.js"
OUT = PAGE / "depth-shading.js"
FIXTURES = REPO / "scripts" / "fixtures"
REPORT = FIXTURES / "depth-shading-report.json"
SOUNDINGS_FIXTURE = FIXTURES / "depth-shading-soundings.json"
DATUM_FIXTURE = FIXTURES / "depth-shading-datum.json"

IMAGE_SERVER = "https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_tiles_mosaic/ImageServer"
ENC_BASE = "https://encdirect.noaa.gov/arcgis/rest/services/encdirect/"
ENC_BANDS = ["enc_berthing", "enc_harbour", "enc_approach", "enc_coastal"]
VDATUM_URL = "https://vdatum.noaa.gov/vdatumweb/api/convert"

# The page's projection (geo.js): x = (lon - LON0) * KX, y = (LAT0 - lat) * KY.
LON0, LAT0, KX, KY = -125.0, 49.1, 69.21431738704068, 100.0
FT = 3.280839895

# WDFW marine areas the layer covers: Admiralty Inlet, Hood Canal, Seattle-Bremerton,
# Tacoma-Vashon, South Puget Sound, and the Whidbey Basin (8-1 Deception Pass, Hope Island
# and Skagit Bay, 8-2 Port Susan and Port Gardner). Areas 5 to 7 (the Strait, the San
# Juans) and the coast are not covered.
AREA_IDS = ["8-1", "8-2", "9", "10", "11", "12", "13"]

# The grid. The server only returns pixels that are square in degrees, so DEM windows are
# requested at 1/3 arc-second in both axes (10.2 m north-south, 6.9 m east-west). An output
# pixel is 2 of those north-south and 3 east-west: 20.5 by 20.9 m on the ground, so about
# square. TILE output pixels make a tile; HALO request pixels of margin are fetched around
# it so the hillshade is continuous across a tile edge.
COS_LAT = 0.6743
W_PX = 1.0 / 3.0 / 3600.0  # request pixel, degrees, both axes
OUT_LAT_PX, OUT_LON_PX = 2, 3  # request pixels per output pixel
W_LAT = W_PX * OUT_LAT_PX  # output pixel height, degrees
W_LON = W_PX * OUT_LON_PX  # output pixel width, degrees
TILE = 512
HALO = 8
WEST0, NORTH0 = (
    -123.17,
    48.47,
)  # the grid's north-west corner, whole degrees of padding past the outlines
COLS, ROWS = 8, 16
MAX_DOWNLOAD = 40 * 1024 * 1024

LEVELS_FT = [3, 6, 12, 18, 24, 30, 60, 90, 120, 180, 240, 300, 360, 420, 480, 600]
# Calm blue, pale at the shore to ink at depth (feet below low tide). Nothing is red, orange,
# amber or yellow and no stop is near the rating blue #0088ff; the unit test holds that.
RAMP = [
    (0, (232, 243, 246)),
    (6, (214, 234, 241)),
    (18, (186, 219, 232)),
    (30, (160, 205, 224)),
    (60, (128, 183, 210)),
    (120, (96, 155, 192)),
    (240, (68, 122, 168)),
    (480, (46, 90, 138)),
    (800, (30, 62, 108)),
]
RATING_COLOURS = {
    "prime red": (255, 56, 60),
    "good orange": (255, 141, 40),
    "fair yellow": (255, 204, 0),
    "slow blue": (0, 136, 255),
}


def need_stack():
    if np is None:
        sys.exit(
            "numpy, pillow, scipy and tifffile are required: use a venv outside the repo"
        )


# ---------------------------------------------------------------- pure helpers


def lonlat_to_map(lon, lat):
    return (lon - LON0) * KX, (LAT0 - lat) * KY


def map_to_lonlat(x, y):
    return LON0 + x / KX, LAT0 - y / KY


def parse_path_rings(d):
    """Rings, in map units, from marine-areas.js: 'M x y x y ... Z' repeated."""
    rings = []
    for seg in re.findall(r"M[^Z]*Z", d):
        n = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", seg)]
        rings.append([(n[i], n[i + 1]) for i in range(0, len(n) - 1, 2)])
    return rings


def load_outlines(path=MARINE, ids=AREA_IDS):
    """{area id: [ring of (lon, lat)]} for the covered marine areas, from marine-areas.js."""
    text = Path(path).read_text()
    out = {}
    for m in re.finditer(r'"([0-9\-]+)": \{"title": "([^"]*)", "d": "([^"]*)"', text):
        if m.group(1) in ids:
            out[m.group(1)] = [
                [map_to_lonlat(x, y) for x, y in ring]
                for ring in parse_path_rings(m.group(3))
            ]
    missing = [i for i in ids if i not in out]
    if missing:
        sys.exit("marine-areas.js has no outline for {}".format(", ".join(missing)))
    return out


def tile_box(r, c):
    """(west, south, east, north) in degrees of output tile (row r, column c)."""
    span_lon = TILE * W_LON
    span_lat = TILE * W_LAT
    west = WEST0 + c * span_lon
    north = NORTH0 - r * span_lat
    return west, north - span_lat, west + span_lon, north


def window_box(r, c):
    """The DEM window of a tile (tile plus HALO request pixels all round) and its size (nx, ny) in request pixels."""
    west, south, east, north = tile_box(r, c)
    return (
        (
            west - HALO * W_PX,
            south - HALO * W_PX,
            east + HALO * W_PX,
            north + HALO * W_PX,
        ),
        (TILE * OUT_LON_PX + 2 * HALO, TILE * OUT_LAT_PX + 2 * HALO),
    )


def ramp_stops():
    return RAMP


def calm_blue(rgb):
    """A blue (hue 185-235) that is not the rating blue: well away from #0088ff in RGB.

    Hue alone cannot do it, since the rating blue sits at 208 degrees too.
    """
    h, _, _ = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    return 185 <= h * 360 <= 235 and math.dist(rgb, (0, 136, 255)) > 100


def interp_grid(grid, lon, lat):
    """Bilinear value of a VDatum sample grid at (lon, lat); pure Python.

    grid = {"lon0", "lat0", "dlon", "dlat", "nx", "ny", "z": [[row of nx values or None] ...]}
    with row 0 at lat0 (the north edge). Cells with a None corner are filled from the
    nearest valid sample by the builder, so a None here means the point is off the grid.
    """
    fx = (lon - grid["lon0"]) / grid["dlon"]
    fy = (grid["lat0"] - lat) / grid["dlat"]
    if fx < 0 or fy < 0 or fx > grid["nx"] - 1 or fy > grid["ny"] - 1:
        return None
    x0, y0 = min(int(fx), grid["nx"] - 2), min(int(fy), grid["ny"] - 2)
    tx, ty = fx - x0, fy - y0
    z = grid["z"]
    v = [z[y0][x0], z[y0][x0 + 1], z[y0 + 1][x0], z[y0 + 1][x0 + 1]]
    if any(a is None for a in v):
        return None
    return (
        v[0] * (1 - tx) * (1 - ty)
        + v[1] * tx * (1 - ty)
        + v[2] * (1 - tx) * ty
        + v[3] * tx * ty
    )


def depth_ft(z_navd88_m, mllw_above_m):
    """Feet below low tide (MLLW), from metres on NAVD88 and the height of NAVD88 zero above MLLW."""
    return -(z_navd88_m + mllw_above_m) * FT


# ---------------------------------------------------------------- fetch


def get(url, params=None, limit=None, tries=6):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    last = None
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=240) as r:
                n = r.headers.get("Content-Length")
                if limit and n and int(n) > limit:
                    raise SystemExit(f"refusing {n} bytes from {url}")
                body = r.read(limit + 1 if limit else None)
                if limit and len(body) > limit:
                    raise SystemExit(f"response over {limit} bytes from {url}")
                return body
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            last = e
            time.sleep(2 + 3 * i)
    raise SystemExit(f"gave up on {url[:120]}: {last}")


def get_json(url, params, tries=10):
    """NOAA's encdirect services answer 'Could not find service' at random; retry, then say so."""
    j = {}
    for i in range(tries):
        try:
            j = json.loads(get(url, params))
        except ValueError:
            j = {"error": "not json"}
        if "error" not in j:
            return j
        time.sleep(2 + i)
    return j


def water_mask_full(outlines):
    """Boolean raster of the covered water at output resolution over the whole grid (even-odd, islands are holes)."""
    need_stack()
    w, h = COLS * TILE, ROWS * TILE
    acc = np.zeros((h, w), np.uint8)
    ol_lon, ol_lat = W_LON, W_LAT
    for rings in outlines.values():
        for ring in rings:
            im = Image.new("1", (w, h), 0)
            ImageDraw.Draw(im).polygon(
                [((lo - WEST0) / ol_lon, (NORTH0 - la) / ol_lat) for lo, la in ring],
                fill=1,
            )
            acc ^= np.asarray(im).astype(np.uint8)
    return acc.astype(bool)


def tiles_with_water(mask):
    out = []
    for r in range(ROWS):
        for c in range(COLS):
            if mask[r * TILE : (r + 1) * TILE, c * TILE : (c + 1) * TILE].any():
                out.append((r, c))
    return out


def fetch_dem(work, tiles):
    for r, c in tiles:
        tif = work / f"dem-r{r:02d}-c{c:02d}.tif"
        if tif.exists():
            continue
        (west, south, east, north), (nx, ny) = window_box(r, c)
        body = get(
            IMAGE_SERVER + "/exportImage",
            {
                "bbox": f"{west:.9f},{south:.9f},{east:.9f},{north:.9f}",
                "bboxSR": 4326,
                "imageSR": 4326,
                "size": f"{nx},{ny}",
                "format": "tiff",
                "pixelType": "F32",
                "interpolation": "RSP_BilinearInterpolation",
                "f": "image",
            },
            MAX_DOWNLOAD,
        )
        tmp = tif.with_suffix(".part")
        tmp.write_bytes(body)
        tmp.rename(tif)
        print("fetched", tif.name, len(body), flush=True)


def fetch_soundings(work):
    dst = work / "soundings.json"
    if dst.exists():
        return
    west, south, east, north = (
        WEST0,
        NORTH0 - ROWS * TILE * W_LAT,
        WEST0 + COLS * TILE * W_LON,
        NORTH0,
    )
    rows, skipped = [], []
    for band in ENC_BANDS:
        resp = get_json(ENC_BASE + band + "/MapServer/layers", {"f": "json"})
        if "layers" not in resp:
            # A band that is down is recorded, never counted as zero soundings.
            print("SKIPPED band", band, ":", str(resp)[:160], flush=True)
            skipped.append(band)
            continue
        lid = [l["id"] for l in resp["layers"] if l["name"].endswith("Sounding_point")]
        if not lid:
            skipped.append(band + " (no sounding layer)")
            continue
        off, n0 = 0, len(rows)
        while True:
            j = get_json(
                ENC_BASE + band + f"/MapServer/{lid[0]}/query",
                {
                    "geometry": f"{west},{south},{east},{north}",
                    "geometryType": "esriGeometryEnvelope",
                    "inSR": 4326,
                    "outSR": 4326,
                    "outFields": "Z,SORDAT",
                    "returnGeometry": "true",
                    "resultOffset": off,
                    "resultRecordCount": 1000,
                    "f": "json",
                },
            )
            if "error" in j:
                raise SystemExit(f"query failed for {band}: {str(j)[:200]}")
            for f in j.get("features", []):
                g = f["geometry"]
                rows.append(
                    {
                        "band": band,
                        "lon": g["x"],
                        "lat": g["y"],
                        "z_m": f["attributes"]["Z"],
                        "sordat": f["attributes"]["SORDAT"],
                    }
                )
            if not j.get("exceededTransferLimit"):
                break
            off += 1000
        print("band", band, len(rows) - n0, "soundings", flush=True)
    dst.write_text(json.dumps({"skipped": skipped, "rows": rows}))


VD_SENTINEL = 100.0  # metres; no real NAVD88-to-MLLW separation is anywhere near this
VD_STEP_LAT = 0.02  # about 2.2 km
VD_STEP_LON = VD_STEP_LAT / COS_LAT


def vdatum_points(mask):
    """Sample points for VDatum: a regular grid, kept where the water mask is within about 3 km."""
    need_stack()
    near = ndimage.binary_dilation(
        mask[::8, ::8], iterations=16
    )  # 8 px = 164 m, so 16 steps = 2.6 km
    ny = int((NORTH0 - (NORTH0 - ROWS * TILE * W_LAT)) / VD_STEP_LAT) + 1
    nx = int(COLS * TILE * W_LON / VD_STEP_LON) + 1
    pts = []
    for j in range(ny):
        for i in range(nx):
            lon, lat = WEST0 + i * VD_STEP_LON, NORTH0 - j * VD_STEP_LAT
            col = int((lon - WEST0) / W_LON / 8)
            row = int((NORTH0 - lat) / W_LAT / 8)
            if 0 <= row < near.shape[0] and 0 <= col < near.shape[1] and near[row, col]:
                pts.append((i, j, lon, lat))
    return nx, ny, pts


def vdatum_one(lon, lat):
    q = {
        "s_x": f"{lon:.6f}",
        "s_y": f"{lat:.6f}",
        "s_z": 0,
        "s_h_frame": "NAD83_2011",
        "t_h_frame": "IGS14",  # the west coast tidal region only accepts IGS14 as the target frame
        "s_v_frame": "NAVD88",
        "t_v_frame": "MLLW",
        "region": "westcoast",
    }
    for i in range(5):
        try:
            j = json.loads(get(VDATUM_URL, q, tries=3))
        except SystemExit:
            j = {"errorCode": -1}
        if "t_z" in j:
            # VDatum answers -999999 for a point off its model; that is "no answer", never a height.
            z = float(j["t_z"])
            return (z if abs(z) < VD_SENTINEL else None), j.get("uncertainty")
        if i < 4 and "Uncaught" in str(j.get("message", "")):
            time.sleep(1 + i)
            continue
        return None, j.get("message")
    return None, "retries"


def fetch_vdatum(work, mask):
    dst = work / "vdatum.json"
    if dst.exists():
        return
    nx, ny, pts = vdatum_points(mask)
    print("vdatum:", len(pts), "points", flush=True)

    def one(p):
        i, j, lon, lat = p
        z, u = vdatum_one(lon, lat)
        return i, j, lon, lat, z, u

    with ThreadPoolExecutor(4) as ex:
        res = list(ex.map(one, pts))
    ok = sum(1 for r in res if r[4] is not None)
    print(f"vdatum: {ok} of {len(res)} points answered", flush=True)
    dst.write_text(
        json.dumps(
            {
                "nx": nx,
                "ny": ny,
                "lon0": WEST0,
                "lat0": NORTH0,
                "dlon": VD_STEP_LON,
                "dlat": VD_STEP_LAT,
                "points": [
                    {"i": i, "j": j, "lon": lo, "lat": la, "z": z, "u": u}
                    for i, j, lo, la, z, u in res
                ],
            }
        )
    )


# ---------------------------------------------------------------- datum


class Datum:
    """Height of NAVD88 zero above MLLW (metres) at any point, on a ~2 km grid, bilinear between nodes."""

    def __init__(self, geom, grid):
        need_stack()
        self.geom = geom
        self.grid = np.asarray(grid, float)

    @classmethod
    def from_vdatum(cls, vd):
        """NOAA VDatum's samples, filled and ready: a cell VDatum would not answer takes the nearest answer."""
        z = np.full((vd["ny"], vd["nx"]), np.nan)
        for p in vd["points"]:
            if p["z"] is not None and abs(p["z"]) < VD_SENTINEL:
                z[p["j"], p["i"]] = p["z"]
        idx = ndimage.distance_transform_edt(
            ~np.isfinite(z), return_distances=False, return_indices=True
        )
        geom = {k: vd[k] for k in ("lon0", "lat0", "dlon", "dlat", "nx", "ny")}
        d = cls(geom, z[tuple(idx)])
        d.answered = int(np.isfinite(z).sum())
        d.asked = len(vd["points"])
        return d

    def shift_m(self, lon, lat):
        g = self.geom
        fx = (np.atleast_1d(lon) - g["lon0"]) / g["dlon"]
        fy = (g["lat0"] - np.atleast_1d(lat)) / g["dlat"]
        fx, fy = np.broadcast_arrays(fx, fy)
        return ndimage.map_coordinates(self.grid, [fy, fx], order=1, mode="nearest")


# ---------------------------------------------------------------- reading the data


def load_soundings(work):
    """ENC spot soundings (metres below MLLW), the same spot in two bands counted once."""
    doc = json.loads((work / "soundings.json").read_text())
    seen, rows = set(), []
    for s in doc["rows"]:
        if s["z_m"] is None:
            continue
        k = (round(s["lon"], 5), round(s["lat"], 5))
        if k in seen:
            continue
        seen.add(k)
        rows.append(s)
    return doc.get("skipped", []), rows


def read_dem(work, r, c):
    return tifffile.imread(work / f"dem-r{r:02d}-c{c:02d}.tif").astype(np.float32)


def sample_dem(work, lon, lat):
    """CUDEM height (m, NAVD88) at points; NaN where the point is in no downloaded window."""
    lon, lat = np.asarray(lon, float), np.asarray(lat, float)
    out = np.full(len(lon), np.nan)
    cc = np.floor((lon - WEST0) / (TILE * W_LON)).astype(int)
    rr = np.floor((NORTH0 - lat) / (TILE * W_LAT)).astype(int)
    for r, c in sorted(set(zip(rr.tolist(), cc.tolist()))):
        f = work / f"dem-r{r:02d}-c{c:02d}.tif"
        if not f.exists():
            continue
        sel = (rr == r) & (cc == c)
        (w, _s, _e, n), _ = window_box(r, c)
        z = read_dem(work, r, c)
        out[sel] = ndimage.map_coordinates(
            z,
            [(n - lat[sel]) / W_PX - 0.5, (lon[sel] - w) / W_PX - 0.5],
            order=1,
            mode="nearest",
        )
    return out


def area_of(outlines, lon, lat):
    """Marine area id of each point ('' outside all covered areas), by the outlines; islands are holes."""
    need_stack()
    lon, lat = np.asarray(lon, float), np.asarray(lat, float)
    out = np.full(len(lon), "", dtype=object)
    x = (lon - WEST0) / W_LON
    y = (NORTH0 - lat) / W_LAT
    w, h = COLS * TILE, ROWS * TILE
    for aid, rings in outlines.items():
        acc = np.zeros((h, w), np.uint8)
        for ring in rings:
            im = Image.new("1", (w, h), 0)
            ImageDraw.Draw(im).polygon(
                [((lo - WEST0) / W_LON, (NORTH0 - la) / W_LAT) for lo, la in ring],
                fill=1,
            )
            acc ^= np.asarray(im).astype(np.uint8)
        xi, yi = np.clip(x.astype(int), 0, w - 1), np.clip(y.astype(int), 0, h - 1)
        out[(acc[yi, xi] == 1) & (out == "")] = aid
    return out


def fetch(work, only):
    work.mkdir(parents=True, exist_ok=True)
    outlines = load_outlines()
    mask = water_mask_full(outlines)
    tiles = tiles_with_water(mask)
    print(f"{len(tiles)} tiles with water of {COLS * ROWS}", flush=True)
    if only in (None, "soundings"):
        fetch_soundings(work)
    if only in (None, "vdatum"):
        fetch_vdatum(work, mask)
    if only in (None, "dem"):
        fetch_dem(work, tiles)


# ---------------------------------------------------------------- shading

SS = 4  # outline mask supersampling
SMOOTH = (
    1.0,
    1.5,
)  # gaussian sigma in request pixels (rows, columns) before the hillshade
M_PER_PX_Y = W_PX * 110574.0
M_PER_PX_X = W_PX * 111320.0 * COS_LAT
WEBP_QUALITY = 74
WEBP_ALPHA_QUALITY = 60
OUT_PX = (
    TILE + 1
)  # each image runs one output pixel into its east and south neighbours, so tiles overlap and no seam shows


def ramp_rgb(depth):
    xs = [s[0] for s in RAMP]
    out = np.zeros(depth.shape + (3,), np.float32)
    for k in range(3):
        out[..., k] = np.interp(depth, xs, [s[1][k] for s in RAMP])
    return out


def hillshade(depth, azimuth=315.0, altitude=40.0, exaggeration=2.5):
    z = depth / FT * exaggeration
    gy = np.gradient(z, M_PER_PX_Y, axis=0)
    gx = np.gradient(z, M_PER_PX_X, axis=1)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(gy, -gx)
    az, alt = math.radians(360 - azimuth + 90), math.radians(altitude)
    hs = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    return np.clip(hs, 0, 1)


def shade_factor(hs, altitude=40.0, gain=0.9, lo=0.6, hi=1.18):
    """Colour multiplier from a hillshade: 1.0 on flat bottom, capped so a lit slope never glints to white."""
    return np.clip(1.0 + gain * (hs - math.sin(math.radians(altitude))), lo, hi)


def block_mean(a, by, bx):
    h, w = a.shape[:2]
    return a.reshape(h // by, by, w // bx, bx, *a.shape[2:]).mean(axis=(1, 3))


def outline_alpha(outlines, west, north):
    """Fraction (0..1) of each extended-tile output pixel inside a covered area, supersampled SS times."""
    h = w = OUT_PX * SS
    acc = np.zeros((h, w), bool)
    for rings in outlines.values():
        one = np.zeros((h, w), np.uint8)
        for ring in rings:
            pts = [
                ((lo - west) / W_LON * SS, (north - la) / W_LAT * SS) for lo, la in ring
            ]
            if max(p[0] for p in pts) < 0 or min(p[0] for p in pts) > w:
                continue
            if max(p[1] for p in pts) < 0 or min(p[1] for p in pts) > h:
                continue
            im = Image.new("1", (w, h), 0)
            ImageDraw.Draw(im).polygon(pts, fill=1)
            one ^= np.asarray(im).astype(np.uint8)
        acc |= one.astype(bool)
    return block_mean(acc.astype(np.float32), SS, SS)


def depth_window(z, r, c, datum):
    """Feet below MLLW over a tile's whole DEM window; land and no-data are negative."""
    (w, _s, _e, n), (nx, ny) = window_box(r, c)
    lon = w + (np.arange(nx) + 0.5) * W_PX
    lat = n - (np.arange(ny) + 0.5) * W_PX
    shift = datum.shift_m(lon[None, :], lat[:, None])
    valid = np.isfinite(z) & (z > -1000)
    depth = np.where(valid, -(z.astype(np.float64) + shift) * FT, -1000.0)
    return depth.astype(np.float32), valid


def render_tile(work, r, c, datum, outlines):
    """RGBA uint8 of one extended tile, or None when it holds no water."""
    z = read_dem(work, r, c)
    west, _south, _east, north = tile_box(r, c)
    depth, valid = depth_window(z, r, c, datum)
    water = valid & (depth > 0)
    # The bottom's shape comes from smoothed depth with the land held flat, so the shoreline is not a cliff.
    sm = ndimage.gaussian_filter(np.maximum(depth, -3.0), SMOOTH, mode="nearest")
    k = shade_factor(hillshade(sm))
    rgb = np.clip(ramp_rgb(np.clip(depth, 0, None)) * k[..., None], 0, 255)
    h0, w0 = HALO, HALO
    hh, ww = OUT_PX * OUT_LAT_PX, OUT_PX * OUT_LON_PX
    sl = (slice(h0, h0 + hh), slice(w0, w0 + ww))
    wf = water[sl].astype(np.float32)
    cover = block_mean(wf, OUT_LAT_PX, OUT_LON_PX)
    num = block_mean(rgb[sl] * wf[..., None], OUT_LAT_PX, OUT_LON_PX)
    ol = outline_alpha(outlines, west, north)
    alpha = cover * ol
    if alpha.max() < 0.02:
        return None
    ok = cover > 0.02
    rgb_out = np.zeros_like(num)
    rgb_out[ok] = num[ok] / cover[ok][:, None]
    # Pixels with no water borrow the mean water colour so the encoder has nothing sharp to spend bytes on.
    rgb_out[~ok] = rgb_out[ok].mean(axis=0) if ok.any() else 0
    out = np.dstack([rgb_out, alpha * 255.0])
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def encode_webp(rgba):
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(
        buf,
        "WEBP",
        quality=WEBP_QUALITY,
        alpha_quality=WEBP_ALPHA_QUALITY,
        method=6,
    )
    return buf.getvalue()


def hex_rgb(rgb):
    return "#{:02x}{:02x}{:02x}".format(*tuple(rgb))


# ---------------------------------------------------------------- datum calibration and the report

CAL_CELL_WEIGHT_CAP = 25
CAL_CLIP_M = (
    3.0  # one wild sounding (a drying height, a wreck) must not steer the field
)
CAL_MAX_M = (
    1.6  # the largest local correction ever applied; the real ones are 0.3 to 1.2 m
)
# Kernel widths tried in turn until a node has enough neighbours. Picked by cross-validation:
# 8, 20 and 60 km over-corrected the Whidbey Basin by 1.5 ft; 3, 8 and 40 km leave every area within 0.3 ft.
CAL_SIGMAS_KM = (3.0, 8.0, 40.0)
BANDS_FT = [(0, 30), (30, 100), (100, 300), (300, 100000)]
SEATTLE_CONSTANT_M = 0.715  # the spike's NAVD88-minus-MLLW constant (CO-OPS Seattle 9447130), the "before" column


def usable_soundings(work, outlines):
    """Soundings with a CUDEM height under them, inside a covered area, where both the chart and the DEM say water."""
    skipped, rows = load_soundings(work)
    lon = np.array([s["lon"] for s in rows])
    lat = np.array([s["lat"] for s in rows])
    zm = np.array([s["z_m"] for s in rows], float)
    band = np.array([s["band"] for s in rows])
    zdem = sample_dem(work, lon, lat)
    area = area_of(outlines, lon, lat)
    ok = np.isfinite(zdem) & (zm > 0) & (area != "") & (zdem < 0)
    return {
        "skipped": skipped,
        "n_all": len(rows),
        "lon": lon[ok],
        "lat": lat[ok],
        "zm": zm[ok],
        "zdem": zdem[ok],
        "band": band[ok],
        "area": area[ok],
    }


def split_fixture(S, per_cell=10):
    """A fixed, evenly spread subset (area x depth band) kept out of the calibration and saved as the regression fixture."""
    held = np.zeros(len(S["zm"]), bool)
    order = np.lexsort((S["lat"], S["lon"]))
    for aid in AREA_IDS:
        for lo, hi in BANDS_FT:
            idx = [
                i for i in order if S["area"][i] == aid and lo <= S["zm"][i] * FT < hi
            ]
            if not idx:
                continue
            pick = (
                np.linspace(0, len(idx) - 1, min(per_cell, len(idx)))
                .round()
                .astype(int)
            )
            for k in sorted(set(pick.tolist())):
                held[idx[k]] = True
    return held


def fold_of(lon, lat, folds=5):
    """Spatial block for cross-validation: 0.2 degree blocks hashed into folds."""
    bx = np.floor(np.asarray(lon) / 0.2).astype(int)
    by = np.floor(np.asarray(lat) / 0.2).astype(int)
    return (bx * 7919 + by * 104729) % folds


def fit_correction(lon, lat, resid_m, geom):
    """Smooth field (metres) to add to the VDatum shift so it matches the chart's soundings.

    Soundings are first reduced to the median per grid node (a marina packed with soundings
    counts once, not a thousand times), then each node takes a kernel-weighted mean of
    nearby node medians, widening the kernel where the data are thin. A node with no
    neighbour inside the widest kernel takes zero, which is VDatum on its own.
    """
    ny, nx = geom["ny"], geom["nx"]
    resid_m = np.clip(resid_m, -CAL_CLIP_M, CAL_CLIP_M)
    ci = np.clip(np.rint((lon - geom["lon0"]) / geom["dlon"]).astype(int), 0, nx - 1)
    cj = np.clip(np.rint((geom["lat0"] - lat) / geom["dlat"]).astype(int), 0, ny - 1)
    cells = {}
    for i, j, r in zip(ci.tolist(), cj.tolist(), resid_m.tolist()):
        cells.setdefault((i, j), []).append(r)
    keys = list(cells)
    med = np.array([np.median(cells[k]) for k in keys])
    wt = np.array([min(len(cells[k]), CAL_CELL_WEIGHT_CAP) for k in keys], float)
    kx = np.array([geom["lon0"] + k[0] * geom["dlon"] for k in keys])
    ky = np.array([geom["lat0"] - k[1] * geom["dlat"] for k in keys])
    gi, gj = np.meshgrid(np.arange(nx), np.arange(ny))
    gx = geom["lon0"] + gi * geom["dlon"]
    gy = geom["lat0"] - gj * geom["dlat"]
    dx = (gx[..., None] - kx) * 111.32 * COS_LAT
    dy = (gy[..., None] - ky) * 110.574
    d2 = dx * dx + dy * dy
    out = np.zeros((ny, nx))
    done = np.zeros((ny, nx), bool)
    for sg in CAL_SIGMAS_KM:
        w = wt * np.exp(-d2 / (2 * sg * sg))
        tot = w.sum(axis=-1)
        enough = (tot >= 3.0) & ~done
        out[enough] = (w * med).sum(axis=-1)[enough] / tot[enough]
        done |= enough
    return np.clip(out, -CAL_MAX_M, CAL_MAX_M)


def model_depth_diff_ft(zdem, shift_m, zm):
    """DEM depth below MLLW minus the chart sounding, feet; positive means the DEM is deeper."""
    return (-(zdem + shift_m) - zm) * FT


def stats(d):
    if len(d) == 0:
        return None
    return {
        "n": len(d),
        "median_ft": round(float(np.median(d)), 2),
        "mae_ft": round(float(np.abs(d).mean()), 2),
        "within_3ft": round(float((np.abs(d) <= 3).mean()), 3),
    }


def per_area(S, shift_m, mask=None):
    m = np.ones(len(S["zm"]), bool) if mask is None else mask
    d = model_depth_diff_ft(S["zdem"], shift_m, S["zm"])
    out = {"all": stats(d[m])}
    for aid in AREA_IDS:
        out[aid] = stats(d[m & (S["area"] == aid)])
    return out


def grid_json(geom, z):
    return {
        "lon0": geom["lon0"],
        "lat0": geom["lat0"],
        "dlon": geom["dlon"],
        "dlat": geom["dlat"],
        "nx": geom["nx"],
        "ny": geom["ny"],
        "z": [[round(float(v), 4) for v in row] for row in z],
    }


# ---------------------------------------------------------------- build

MAX_BYTES = 1_500_000
CREDIT_SOURCE = (
    "Source: NOAA NCEI CUDEM (CIRES / NCEI, doi:10.25921/ds9v-ky35), public domain."
)
HEADER = (
    "/* Generated by scripts/build_depth_shading.py; do not edit by hand. Depth shading for Puget Sound: image tiles baked from NOAA NCEI CUDEM,\n"
    " * with data-URI images in the page's map units (geo.js projection). A model of the seabed, not a survey and not sonar. Not for navigation. */\n"
)
TEMPLATE = """(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.DEPTHSHADE = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  return __BODY__;
});
"""


def build(work):
    need_stack()
    FIXTURES.mkdir(parents=True, exist_ok=True)
    outlines = load_outlines()
    mask = water_mask_full(outlines)
    tiles = tiles_with_water(mask)
    vd = json.loads((work / "vdatum.json").read_text())
    d_vd = Datum.from_vdatum(vd)
    geom = d_vd.geom
    S = usable_soundings(work, outlines)
    held = split_fixture(S)
    fit = ~held
    s_vd = d_vd.shift_m(S["lon"], S["lat"])
    resid = (
        -S["zdem"] - S["zm"] - s_vd
    )  # metres still to add to VDatum's shift to meet the chart
    corr = fit_correction(S["lon"][fit], S["lat"][fit], resid[fit], geom)
    d_cal = Datum(geom, d_vd.grid + corr)
    s_cal = d_cal.shift_m(S["lon"], S["lat"])
    # Out-of-fold: refit without one 0.2 degree block of the fit set, score that block.
    fold = fold_of(S["lon"], S["lat"])
    s_oof = s_cal.copy()
    for k in range(5):
        tr, te = fit & (fold != k), fit & (fold == k)
        c = fit_correction(S["lon"][tr], S["lat"][tr], resid[tr], geom)
        s_oof[te] = Datum(geom, d_vd.grid + c).shift_m(S["lon"][te], S["lat"][te])
    const = np.full(len(S["zm"]), SEATTLE_CONSTANT_M)
    report = {
        "generated": time.strftime("%Y-%m-%d"),
        "soundings": {
            "fetched_after_dedupe": S["n_all"],
            "scored": len(S["zm"]),
            "in_fit": int(fit.sum()),
            "held_out_fixture": int(held.sum()),
            "bands": {b: int((S["band"] == b).sum()) for b in sorted(set(S["band"]))},
            "bands_skipped": S["skipped"],
        },
        "vdatum": {
            "asked": d_vd.asked,
            "answered": d_vd.answered,
            "grid_step_km": round(VD_STEP_LAT * 110.574, 2),
            "shift_m_range": [
                round(float(d_vd.grid.min()), 3),
                round(float(d_vd.grid.max()), 3),
            ],
            "correction_m_range": [
                round(float(corr.min()), 3),
                round(float(corr.max()), 3),
            ],
        },
        "median_dem_minus_enc_ft": {
            "before_single_constant": per_area(S, const),
            "vdatum_only": per_area(S, s_vd),
            "vdatum_plus_calibration_in_sample": per_area(S, s_cal, fit),
            "vdatum_plus_calibration_out_of_fold": per_area(S, s_oof, fit),
            "vdatum_plus_calibration_held_out_fixture": per_area(S, s_cal, held),
        },
    }
    # Fixtures for the test: the held-out soundings with the raw DEM height under each, and the shipped datum grid.
    fx = [
        {
            "area": str(S["area"][i]),
            "lon": round(float(S["lon"][i]), 5),
            "lat": round(float(S["lat"][i]), 5),
            "enc_ft": round(float(S["zm"][i] * FT), 1),
            "dem_navd88_m": round(float(S["zdem"][i]), 3),
        }
        for i in np.flatnonzero(held)
    ]
    about = (
        "NOAA ENC spot soundings (feet below MLLW) held out of the datum calibration, with the NCEI "
        "CUDEM height under each (metres, NAVD88). Written by scripts/build_depth_shading.py."
    )
    SOUNDINGS_FIXTURE.write_text(
        '{{"about": {},\n"rows": [\n{}\n]}}\n'.format(
            json.dumps(about), ",\n".join(json.dumps(r) for r in fx)
        )
    )
    DATUM_FIXTURE.write_text(
        json.dumps(
            {
                "about": "Height of NAVD88 zero above MLLW in metres on a grid over Puget Sound: NOAA VDatum plus a smooth local correction to NOAA's charted soundings. Written by scripts/build_depth_shading.py.",
                "grid": grid_json(geom, d_cal.grid),
            }
        )
        + "\n"
    )

    out_tiles, total = [], 0
    for r, c in tiles:
        rgba = render_tile(work, r, c, d_cal, outlines)
        if rgba is None:
            continue
        webp = encode_webp(rgba)
        west, _south, _east, north = tile_box(r, c)
        x0, y0 = lonlat_to_map(west, north)
        x1, y1 = lonlat_to_map(west + OUT_PX * W_LON, north - OUT_PX * W_LAT)
        out_tiles.append(
            {
                "x": round(x0, 4),
                "y": round(y0, 4),
                "w": round(x1 - x0, 4),
                "h": round(y1 - y0, 4),
                "px": [OUT_PX, OUT_PX],
                "uri": "data:image/webp;base64," + base64.b64encode(webp).decode(),
            }
        )
        total += len(webp)
        print(f"tile r{r:02d} c{c:02d} {len(webp)} bytes", flush=True)
    oof = report["median_dem_minus_enc_ft"]["vdatum_plus_calibration_out_of_fold"][
        "all"
    ]
    body = {
        "generated": report["generated"],
        "credit": CREDIT_SOURCE
        + " Heights are matched to low tide with NOAA VDatum and a local correction to NOAA's charted soundings."
        f" Against those soundings the shading is off by {oof['mae_ft']:.1f} ft on average"
        f" and {round(oof['within_3ft'] * 100)}% are within 3 ft; steep walls such as Hood Canal's are much worse.",
        "datum": "feet below MLLW (low tide)",
        "areas": AREA_IDS,
        "pixel_m": [round(W_LAT * 110574.0, 1), round(W_LON * 111320.0 * COS_LAT, 1)],
        "ramp": [[ft, hex_rgb(rgb)] for ft, rgb in RAMP],
        "accuracy": {
            "mae_ft": oof["mae_ft"],
            "within_3ft": oof["within_3ft"],
            "n": oof["n"],
        },
        "tiles": out_tiles,
    }
    js = HEADER + TEMPLATE.replace("__BODY__", json.dumps(body, indent=1))
    if len(js.encode()) > MAX_BYTES:
        sys.exit(
            f"depth-shading.js would be {len(js.encode())} bytes, over {MAX_BYTES}"
        )
    OUT.write_text(js)
    report["output"] = {
        "tiles": len(out_tiles),
        "webp_bytes": total,
        "file_bytes": len(js.encode()),
        "tile_px": OUT_PX,
        "pixel_m": body["pixel_m"],
    }
    REPORT.write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps(report["output"]))
    print(json.dumps(report["median_dem_minus_enc_ft"], indent=1))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--work", required=True, type=Path)
    f.add_argument("--only", choices=["dem", "soundings", "vdatum"])
    b = sub.add_parser("build")
    b.add_argument("--work", required=True, type=Path)
    a = ap.parse_args()
    need_stack()
    if a.cmd == "fetch":
        fetch(a.work, a.only)
    else:
        build(a.work)


if __name__ == "__main__":
    main()
