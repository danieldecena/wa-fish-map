#!/usr/bin/env python3
"""Spike (2026-10-29): bake depth shading and smooth contours from NOAA CUDEM.

Not part of the page build. Writes only into docs/spikes/2026-10-29-depth-shading/.
Needs numpy, pillow, scipy, scikit-image and tifffile, so run it in a venv outside
the repo, never with the system python:

    /opt/homebrew/bin/python3 -m venv "$SCRATCH/venv"
    "$SCRATCH/venv/bin/pip" install numpy pillow scipy scikit-image tifffile
    "$SCRATCH/venv/bin/python" -I scripts/spike_depth_shading.py fetch --work "$SCRATCH/work"
    "$SCRATCH/venv/bin/python" -I scripts/spike_depth_shading.py build --work "$SCRATCH/work"

`fetch` downloads three DEM windows (about 145 MB in all, refused above 80 MB each)
from NOAA NCEI's public ImageServer and the ENC spot soundings from NOAA's
encdirect service, into --work. `build` reads those plus Artifacts/salmon-rivers/
depth-data.js (never modified) and writes the demo's data, rasters and metrics.json.

Heights come from CUDEM in metres on NAVD88. The page's contours are feet below
MLLW, so each area is shifted by the NAVD88-MLLW separation of its nearest tide
station (CO-OPS datums API), then converted to feet. Not for navigation.
"""

import argparse
import io
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import numpy as np
    import tifffile
    from PIL import Image
    from scipy import ndimage
    from scipy.spatial import cKDTree
    from skimage import measure
except ImportError:  # the unit tests skip when the stack is absent
    np = None

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "docs/spikes/2026-10-29-depth-shading"
DEPTHDATA = REPO / "Artifacts/salmon-rivers/depth-data.js"

IMAGE_SERVER = "https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_tiles_mosaic/ImageServer"
ENC_BASE = "https://encdirect.noaa.gov/arcgis/rest/services/encdirect/"
ENC_BANDS = ["enc_berthing", "enc_harbour", "enc_approach", "enc_coastal"]
MAX_DOWNLOAD = 80 * 1024 * 1024

# The page's projection (geo.js): x = (lon - lon0) * kx, y = (lat0 - lat) * k.
LON0, LAT0, KX, KY = -125.0, 49.1, 69.21431738704068, 100.0
ENC_SCALE = 0.01  # depth-data.js path unit, in map units

FT = 3.280839895
# NAVD88 minus MLLW in metres at the nearest CO-OPS station (datums API, fetched 2026-10-29):
# Tacoma 9446484 0.729, Seattle 9447130 0.715, Port Angeles 9444090 0.129.
AREAS = {
    "tacoma": dict(
        title="Commencement Bay, Tacoma",
        bbox=(-122.50, 47.24, -122.38, 47.32),
        px=(3888, 2592),
        shift_m=0.729,
        station="9446484 Tacoma",
        sites=[("Les Davis Pier", 47.2829, -122.482)],
        width=512,
    ),
    "portangeles": dict(
        title="Port Angeles harbour",
        bbox=(-123.50, 48.08, -123.34, 48.16),
        px=(5184, 2592),
        shift_m=0.129,
        station="9444090 Port Angeles",
        sites=[("Port Angeles City Pier", 48.1208, -123.4285)],
        width=512,
    ),
    "elliott": dict(
        title="Elliott Bay, Seattle",
        bbox=(-122.44, 47.56, -122.32, 47.65),
        px=(3888, 2916),
        shift_m=0.715,
        station="9447130 Seattle",
        exclude=(-122.37, 47.632, -122.32, 47.65),
        note="The top-right corner (Lake Union, Portage Bay) is shaded too, but its depths are wrong: fresh water held above sea level has no tidal datum. Its 219 ENC soundings are left out of the scores.",
        sites=[
            ("Terminal 86 pier", 47.6263, -122.3745),
            ("Seacrest Park Pier", 47.5895, -122.3804),
        ],
        width=512,
    ),
}
LEVELS_FT = [3, 6, 12, 18, 24, 30, 60, 90, 120, 180, 240, 300, 360, 420, 480, 600]
# Calm blue, pale at the shore to ink at depth. Saturation stays well under the
# rating blue (#0088ff) and nothing here is red, orange, amber or yellow.
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


def need_stack():
    if np is None:
        sys.exit(
            "numpy, pillow, scipy, scikit-image and tifffile are required: use a venv outside the repo"
        )


# ---------------------------------------------------------------- pure helpers


def map_to_lonlat(x, y):
    return LON0 + x / KX, LAT0 - y / KY


def lonlat_to_map(lon, lat):
    return (lon - LON0) * KX, (LAT0 - lat) * KY


def parse_enc_path(d, scale=ENC_SCALE):
    """Polylines, in lon/lat, from a depth-data.js path ('M x y' then relative 'l dx dy ...')."""
    lines = []
    for seg in re.findall(r"M[^M]*", d):
        nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?", seg)]
        if len(nums) < 4:
            continue
        x, y = nums[0], nums[1]
        pts = [(x, y)]
        for i in range(2, len(nums) - 1, 2):
            x += nums[i]
            y += nums[i + 1]
            pts.append((x, y))
        lines.append([map_to_lonlat(px * scale, py * scale) for px, py in pts])
    return lines


def load_depthdata(path=DEPTHDATA):
    t = Path(path).read_text()
    i = t.index("window.DEPTHDATA=") + len("window.DEPTHDATA=")
    d = json.loads(t[i : t.rindex("}") + 1])
    levels = {lv["ft"]: parse_enc_path(lv["d"], d["scale"]) for lv in d["levels"]}
    labs = [(*map_to_lonlat(x, y), ft) for x, y, ft in d["lab"]]
    return levels, labs


def depth_ft_from_navd88(z_m, shift_m):
    """Feet below MLLW from metres on NAVD88: MLLW sits shift_m below NAVD88 here."""
    return -(z_m + shift_m) * FT


def ramp_rgb(depth_ft):
    xs = [s[0] for s in RAMP]
    out = np.zeros(depth_ft.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(depth_ft, xs, [s[1][c] for s in RAMP])
    return out


def hillshade(depth_ft, cell_m, azimuth=315.0, altitude=40.0, exaggeration=3.0):
    z = depth_ft / FT * exaggeration
    gy, gx = np.gradient(z, cell_m)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(gy, -gx)
    az, alt = math.radians(360 - azimuth + 90), math.radians(altitude)
    hs = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    return np.clip(hs, 0, 1)


def shade_factor(hs, altitude=40.0, gain=0.9, lo=0.6, hi=1.18):
    """Colour multiplier from a hillshade; 1.0 on flat bottom, capped so a lit slope never blows out to white."""
    return np.clip(1.0 + gain * (hs - math.sin(math.radians(altitude))), lo, hi)


def box_resize(a, w, h):
    return np.asarray(
        Image.fromarray(a.astype(np.float32), "F").resize((w, h), Image.BOX)
    )


def to_path(coords_xy, scale):
    """'M x y l dx dy ...' in integer units of `scale` map units, the page's own format."""
    pts = [(round(x / scale), round(y / scale)) for x, y in coords_xy]
    out = [pts[0]]
    for p in pts[1:]:
        if p != out[-1]:
            out.append(p)
    if len(out) < 2:
        return ""
    s = "M%d %d" % out[0]
    s += "l" + " ".join(
        "%d %d" % (b[0] - a[0], b[1] - a[1]) for a, b in zip(out, out[1:])
    )
    return s


# ---------------------------------------------------------------- fetch


def get(url, params=None, limit=None):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=180) as r:
        n = r.headers.get("Content-Length")
        if limit and n and int(n) > limit:
            raise SystemExit("refusing %s bytes from %s" % (n, url))
        body = r.read(limit + 1 if limit else None)
        if limit and len(body) > limit:
            raise SystemExit("response over %d bytes from %s" % (limit, url))
        return body


def get_json(url, params, tries=8):
    """NOAA's encdirect services answer 'Could not find service' at random; retry, then say so."""
    for i in range(tries):
        j = json.loads(get(url, params))
        if "error" not in j:
            return j
        time.sleep(2 + i)
    return j


def fetch(work):
    work.mkdir(parents=True, exist_ok=True)
    for name, a in AREAS.items():
        tif = work / (name + ".tif")
        if not tif.exists():
            w, h = a["px"]
            if w * h * 4 > MAX_DOWNLOAD:
                raise SystemExit(
                    "%s would be %d bytes, over the limit" % (name, w * h * 4)
                )
            west, south, east, north = a["bbox"]
            body = get(
                IMAGE_SERVER + "/exportImage",
                {
                    "bbox": "%s,%s,%s,%s" % (west, south, east, north),
                    "bboxSR": 4326,
                    "imageSR": 4326,
                    "size": "%d,%d" % (w, h),
                    "format": "tiff",
                    "pixelType": "F32",
                    "interpolation": "RSP_NearestNeighbor",
                    "f": "image",
                },
                MAX_DOWNLOAD,
            )
            tif.write_bytes(body)
            print("fetched", tif.name, len(body))
        snd = work / (name + "-soundings.json")
        if not snd.exists():
            rows, skipped = [], []
            for band in ENC_BANDS:
                resp = get_json(ENC_BASE + band + "/MapServer/layers", {"f": "json"})
                if "layers" not in resp:
                    # NOAA's enc_approach service was down on 2026-10-29: say so, never treat it as zero soundings.
                    print("SKIPPED band", band, "for", name, ":", str(resp)[:160])
                    skipped.append(band)
                    continue
                lid = [
                    l["id"]
                    for l in resp["layers"]
                    if l["name"].endswith("Sounding_point")
                ]
                if not lid:
                    continue
                west, south, east, north = a["bbox"]
                off = 0
                while True:
                    j = get_json(
                        ENC_BASE + band + "/MapServer/%d/query" % lid[0],
                        {
                            "geometry": "%s,%s,%s,%s" % (west, south, east, north),
                            "geometryType": "esriGeometryEnvelope",
                            "inSR": 4326,
                            "outSR": 4326,
                            "outFields": "Z,SORDAT,DSNM",
                            "returnGeometry": "true",
                            "resultOffset": off,
                            "resultRecordCount": 1000,
                            "f": "json",
                        },
                    )
                    if "error" in j:
                        raise SystemExit("query failed: %s" % str(j)[:200])
                    for f in j.get("features", []):
                        g = f["geometry"]
                        rows.append(
                            dict(
                                band=band,
                                lon=g["x"],
                                lat=g["y"],
                                z_m=f["attributes"]["Z"],
                                sordat=f["attributes"]["SORDAT"],
                            )
                        )
                    if not j.get("exceededTransferLimit"):
                        break
                    off += 1000
            snd.write_text(json.dumps({"skipped": skipped, "rows": rows}))
            print("fetched", snd.name, len(rows), "soundings")


# ---------------------------------------------------------------- build


def contour_paths(work_ft, bbox, scale, sigma_px, simplify_px, min_len_px):
    """Smooth, trace and simplify contours; returns {ft: path string} and vertex arrays in lon/lat."""
    west, south, east, north = bbox
    h, w = work_ft.shape
    sm = ndimage.gaussian_filter(work_ft, sigma_px, mode="nearest")
    paths, polys = {}, {}
    for ft in LEVELS_FT:
        segs, ll = [], []
        for c in measure.find_contours(sm, ft):
            if len(c) < min_len_px:
                continue
            c = measure.approximate_polygon(c, simplify_px)
            lon = west + (c[:, 1] + 0.5) / w * (east - west)
            lat = north - (c[:, 0] + 0.5) / h * (north - south)
            xs, ys = lonlat_to_map(lon, lat)
            p = to_path(list(zip(xs, ys)), scale)
            if p:
                segs.append(p)
                ll.append(np.column_stack([lon, lat]))
        paths[ft] = "".join(segs)
        polys[ft] = ll
    return paths, polys


def metres_xy(lon, lat, lat_ref):
    return np.column_stack(
        [
            np.asarray(lon) * 111320.0 * math.cos(math.radians(lat_ref)),
            np.asarray(lat) * 110574.0,
        ]
    )


def densify(poly, step_m, lat_ref):
    xy = metres_xy(poly[:, 0], poly[:, 1], lat_ref)
    out = [xy[0]]
    for a, b in zip(xy, xy[1:]):
        n = max(1, int(np.hypot(*(b - a)) // step_m))
        for t in range(1, n + 1):
            out.append(a + (b - a) * t / n)
    return np.array(out)


def sample(dem_ft, bbox, lon, lat):
    west, south, east, north = bbox
    h, w = dem_ft.shape
    col = (np.asarray(lon) - west) / (east - west) * w - 0.5
    row = (north - np.asarray(lat)) / (north - south) * h - 0.5
    return ndimage.map_coordinates(dem_ft, [row, col], order=1, mode="nearest")


def pct(a, q):
    return [round(float(x), 2) for x in np.percentile(a, q)] if len(a) else None


def build_area(name, a, work, enc_levels, enc_labs, scale, out):
    t0 = time.time()
    bbox = a["bbox"]
    west, south, east, north = bbox
    z = tifffile.imread(work / (name + ".tif")).astype(np.float32)
    h0, w0 = z.shape
    t_load = time.time() - t0
    full_ft = depth_ft_from_navd88(z, a["shift_m"]).astype(
        np.float32
    )  # >0 below MLLW, <=0 land
    lat_c = (south + north) / 2
    width_m = (east - west) * 111320.0 * math.cos(math.radians(lat_c))
    height_m = (north - south) * 110574.0

    # Output raster: equal-metre pixels, 512 px wide by default.
    ow = a["width"]
    oh = round(ow * height_m / width_m)
    t1 = time.time()
    # Work grid 2x the output so smoothing does not depend on the output size.
    ww, wh = ow * 2, oh * 2
    work_ft = box_resize(full_ft, ww, wh)
    cell_m = width_m / ww
    t_resample = time.time() - t1

    t2 = time.time()
    paths, polys = contour_paths(
        work_ft, bbox, scale, sigma_px=1.2, simplify_px=0.6, min_len_px=14
    )
    t_contour = time.time() - t2

    t3 = time.time()
    shade_in = ndimage.gaussian_filter(work_ft, 1.0, mode="nearest")
    rgb_w = ramp_rgb(np.clip(work_ft, 0, None))
    hs = hillshade(shade_in, cell_m, exaggeration=2.5)
    water_w = work_ft > 0
    # Lighten toward the sun, darken away; centred so flat bottom keeps its ramp colour.
    k = np.where(water_w, shade_factor(hs), 1.0)[..., None]
    rgb_w = np.clip(rgb_w * k, 0, 255)
    rgb = np.stack([box_resize(rgb_w[..., c], ow, oh) for c in range(3)], axis=-1)
    water = box_resize(water_w.astype(np.float32), ow, oh) > 0.5
    # Quantise the water pixels to a fixed palette, land is the one transparent index.
    strip = Image.fromarray(rgb[water].astype(np.uint8).reshape(-1, 1, 3))
    pal_img = strip.quantize(
        colors=63, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    pal = pal_img.getpalette()[: 63 * 3]
    land_fill = rgb.copy()
    land_fill[~water] = rgb[water].mean(axis=0)
    p_img = Image.fromarray(land_fill.astype(np.uint8)).quantize(
        palette=pal_img, dither=Image.Dither.NONE
    )
    idx = np.asarray(p_img).copy()
    idx[~water] = 63
    pal = pal + [0, 0, 0] * (64 - len(pal) // 3)
    out_img = Image.fromarray(idx, "P")
    out_img.putpalette(pal)
    png = out / (name + "-relief.png")
    out_img.save(png, optimize=True, transparency=63)
    mask_img = Image.fromarray((~water).astype(np.uint8), "P")
    mask_img.putpalette([223, 234, 240, 0, 0, 0])
    mask_img.save(out / (name + "-mask.png"), optimize=True, transparency=1)
    t_shade = time.time() - t3

    # Size at other widths and as lossy WebP, for the report.
    sizes = {"png_%d" % ow: png.stat().st_size}
    rgba = np.dstack([rgb.astype(np.uint8), (water * 255).astype(np.uint8)])
    buf = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buf, "WEBP", quality=80)
    sizes["webp80_%d" % ow] = buf.tell()
    for alt in (256, 1024):
        ah = round(alt * height_m / width_m)
        wk = box_resize(full_ft, alt, ah)
        c = (
            ramp_rgb(np.clip(wk, 0, None))
            * np.where(
                wk > 0,
                shade_factor(
                    hillshade(
                        ndimage.gaussian_filter(wk, 1.0),
                        width_m / alt,
                        exaggeration=2.5,
                    )
                ),
                1.0,
            )[..., None]
        )
        wm = wk > 0
        s = Image.fromarray(
            np.clip(c, 0, 255)[wm].astype(np.uint8).reshape(-1, 1, 3)
        ).quantize(colors=63, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        cf = np.clip(c, 0, 255).copy()
        cf[~wm] = cf[wm].mean(axis=0)
        pi = Image.fromarray(cf.astype(np.uint8)).quantize(
            palette=s, dither=Image.Dither.NONE
        )
        ix = np.asarray(pi).copy()
        ix[~wm] = 63
        im = Image.fromarray(ix, "P")
        im.putpalette(s.getpalette()[: 63 * 3] + [0, 0, 0])
        b2 = io.BytesIO()
        im.save(b2, "PNG", optimize=True, transparency=63)
        sizes["png_%d" % alt] = b2.tell()

    # ---- measurements against the page's ENC contours
    enc_xy_all, enc_ft_all = [], []
    inside = lambda p: (west <= p[0] <= east) and (south <= p[1] <= north)
    my_pts, my_ft = [], []
    for ft in LEVELS_FT:
        for poly in polys[ft]:
            d = densify(poly, 2.0, lat_c)
            my_pts.append(d)
            my_ft.append(np.full(len(d), ft))
    my_pts = np.vstack(my_pts) if my_pts else np.zeros((0, 2))
    my_ft = np.concatenate(my_ft) if my_ft else np.zeros(0)
    per_level = {}
    enc_vertices = 0
    for ft in LEVELS_FT:
        v = [p for line in enc_levels.get(ft, []) for p in line if inside(p)]
        enc_vertices += len(v)
        if not v:
            per_level[str(ft)] = None
            continue
        v = np.array(v)
        enc_xy_all.append(v)
        enc_ft_all.append(np.full(len(v), ft))
        dem_at = sample(full_ft, bbox, v[:, 0], v[:, 1])
        diff = dem_at - ft
        vxy = metres_xy(v[:, 0], v[:, 1], lat_c)
        sel = my_pts[my_ft == ft]
        if len(sel):
            dist = cKDTree(sel).query(vxy)[0]
            dd = pct(dist, [50, 90])
        else:
            dd = None
        per_level[str(ft)] = dict(
            n=int(len(v)),
            dem_minus_enc_ft_p10_p50_p90=pct(diff, [10, 50, 90]),
            horiz_m_to_my_contour_p50_p90=dd,
            share_within_3ft=round(float((np.abs(diff) <= 3).mean()), 3),
        )
    enc_all = np.vstack(enc_xy_all) if enc_xy_all else np.zeros((0, 2))
    enc_ft_arr = np.concatenate(enc_ft_all) if enc_ft_all else np.zeros(0)
    # Point-wise error also carries the ENC's own 11 m coordinate rounding, so report a
    # slope-corrected figure: the smallest |DEM - ENC level| within 12 m of the vertex.
    ring = []
    for dx, dy in [
        (0, 0),
        (12, 0),
        (-12, 0),
        (0, 12),
        (0, -12),
        (8.5, 8.5),
        (-8.5, 8.5),
        (8.5, -8.5),
        (-8.5, -8.5),
    ]:
        lon = enc_all[:, 0] + dx / (111320.0 * math.cos(math.radians(lat_c)))
        lat = enc_all[:, 1] + dy / 110574.0
        ring.append(sample(full_ft, bbox, lon, lat))
    ring = np.array(ring)
    best = np.min(np.abs(ring - enc_ft_arr), axis=0) if len(enc_all) else np.zeros(0)
    pointwise = np.abs(ring[0] - enc_ft_arr) if len(enc_all) else np.zeros(0)

    # Five+ specific ENC label points: the ENC says this spot is at `ft`.
    labs = [
        (lo, la, ft)
        for lo, la, ft in enc_labs
        if west + 0.004 < lo < east - 0.004 and south + 0.004 < la < north - 0.004
    ]
    labs.sort(key=lambda t: (t[2], t[0]))
    picked, seen = [], {}
    for lo, la, ft in labs:
        if seen.get(ft, 0) < 1 and sample(full_ft, bbox, [lo], [la])[0] > -5:
            seen[ft] = seen.get(ft, 0) + 1
            picked.append((lo, la, ft))
    check_points = []
    for lo, la, ft in picked[:8]:
        r = [
            float(
                sample(
                    full_ft,
                    bbox,
                    [lo + dx / (111320.0 * math.cos(math.radians(lat_c)))],
                    [la + dy / 110574.0],
                )[0]
            )
            for dx, dy in [(0, 0), (12, 0), (-12, 0), (0, 12), (0, -12)]
        ]
        check_points.append(
            dict(
                lon=round(lo, 5),
                lat=round(la, 5),
                enc_ft=ft,
                dem_ft_at_point=round(r[0], 1),
                dem_ft_range_within_12m=[round(min(r), 1), round(max(r), 1)],
                diff_at_point=round(r[0] - ft, 1),
            )
        )

    # Independent-ish spot soundings (the ENC's own SOUNDG points, metres to MLLW)
    snd_doc = json.loads((work / (name + "-soundings.json")).read_text())
    snd = snd_doc["rows"]
    s_lon = np.array([s["lon"] for s in snd if s["z_m"] is not None])
    s_lat = np.array([s["lat"] for s in snd if s["z_m"] is not None])
    s_ft = np.array([s["z_m"] * FT for s in snd if s["z_m"] is not None])
    s_band = [s["band"] for s in snd if s["z_m"] is not None]
    s_year = [
        int(s["sordat"][:4]) if s.get("sordat") and s["sordat"][:4].isdigit() else None
        for s in snd
        if s["z_m"] is not None
    ]
    in_water = s_ft > 0
    # Dedupe the same spot repeated across scale bands.
    keyseen, keep = set(), []
    for i in range(len(s_ft)):
        k = (round(s_lon[i], 5), round(s_lat[i], 5))
        if k in keyseen:
            continue
        keyseen.add(k)
        keep.append(i)
    keep = np.array(keep, int)
    s_lon, s_lat, s_ft, in_water = s_lon[keep], s_lat[keep], s_ft[keep], in_water[keep]
    s_year = [s_year[i] for i in keep]
    s_band = [s_band[i] for i in keep]
    dem_s = sample(full_ft, bbox, s_lon, s_lat)
    # A sounding where the DEM says land (a pier, a lake held at its surface, a dredged-since
    # berth) is counted apart, not scored as a huge depth error.
    ex = a.get("exclude")
    n_excluded = 0
    if ex:
        in_ex = (s_lon > ex[0]) & (s_lon < ex[2]) & (s_lat > ex[1]) & (s_lat < ex[3])
        n_excluded = int((in_water & in_ex).sum())
        in_water = in_water & ~in_ex
    n_dem_dry = int((in_water & ~(dem_s > 0)).sum())
    in_water = in_water & (dem_s > 0)
    d = (dem_s - s_ft)[in_water]
    sf = s_ft[in_water]
    classes = {}
    for lo_, hi_ in [(0, 30), (30, 100), (100, 300), (300, 2000)]:
        m = (sf >= lo_) & (sf < hi_)
        if m.sum():
            classes["%d-%d ft" % (lo_, hi_)] = dict(
                n=int(m.sum()),
                mean_diff=round(float(d[m].mean()), 1),
                mae=round(float(np.abs(d[m]).mean()), 1),
                p90_abs=round(float(np.percentile(np.abs(d[m]), 90)), 1),
                within_3ft=round(float((np.abs(d[m]) <= 3).mean()), 3),
            )
    years = [y for y, w in zip(s_year, in_water) if y]
    yr = np.array([(y or 0) for y, w in zip(s_year, in_water) if w])
    by_year = {}
    for lo_, hi_ in [(0, 2000), (2000, 2015), (2015, 2100)]:
        m = (yr >= lo_) & (yr < hi_)
        if m.sum() >= 10:
            by_year["%d-%d" % (lo_, hi_)] = dict(
                n=int(m.sum()),
                median_diff=round(float(np.median(d[m])), 2),
                mae=round(float(np.abs(d[m]).mean()), 2),
            )
    deep = sf > 150
    deep_stats = None
    if deep.sum() >= 10:
        deep_stats = dict(
            n=int(deep.sum()),
            diff_ft_p10_p50_p90=pct(d[deep], [10, 50, 90]),
            mae_after_removing_median=round(
                float(np.abs(d[deep] - np.median(d[deep])).mean()), 2
            ),
        )
    soundings = dict(
        deep_over_150ft=deep_stats,
        by_survey_year=by_year,
        mae_after_removing_median_ft=round(float(np.abs(d - np.median(d)).mean()), 2),
        within_3ft_after_removing_median=round(
            float((np.abs(d - np.median(d)) <= 3).mean()), 3
        ),
        n=int(in_water.sum()),
        skipped_bands=snd_doc.get("skipped"),
        n_where_dem_says_land=n_dem_dry,
        n_excluded_lake_soundings=n_excluded,
        bands=dict((b, s_band.count(b)) for b in set(s_band)),
        mean_diff_ft=round(float(d.mean()), 2),
    )
    soundings.update(
        dict(
            n=int(in_water.sum()),
            mean_diff_ft=round(float(d.mean()), 2),
            median_diff_ft=round(float(np.median(d)), 2),
            mae_ft=round(float(np.abs(d).mean()), 2),
            p90_abs_ft=round(float(np.percentile(np.abs(d), 90)), 2),
            within_3ft=round(float((np.abs(d) <= 3).mean()), 3),
            within_10pct=round(float((np.abs(d) <= 0.1 * sf + 1).mean()), 3),
            by_depth=classes,
            survey_years=pct(years, [0, 50, 100]) if years else None,
        )
    )
    # Resolution test: box-average the DEM to coarser grids and re-score it against the same
    # soundings. A simulation from CUDEM, not the real GEBCO or CRM files. The shared datum
    # bias is removed so only the resolution effect shows.
    resolution_sim = {}
    for label, arcsec in [
        ("1/3 arc-second (10 m)", 1 / 3),
        ("3 arc-second (90 m, Coastal Relief Model class)", 3),
        ("15 arc-second (GEBCO grid, about 460 x 310 m)", 15),
    ]:
        gw = max(2, round((east - west) * 3600 / arcsec))
        gh = max(2, round((north - south) * 3600 / arcsec))
        g = box_resize(full_ft, gw, gh)
        e = sample(g, bbox, s_lon[in_water], s_lat[in_water]) - s_ft[in_water]
        e = e - np.median(e)
        resolution_sim[label] = dict(
            grid=[gw, gh],
            mae_ft=round(float(np.abs(e).mean()), 2),
            within_3ft=round(float((np.abs(e) <= 3).mean()), 3),
        )
    big = np.argsort(-np.abs(d - np.median(d)))[:6]
    largest_misses = [
        dict(
            lon=round(float(s_lon[in_water][i]), 5),
            lat=round(float(s_lat[in_water][i]), 5),
            enc_sounding_ft=round(float(sf[i]), 1),
            dem_ft=round(float(sf[i] + d[i]), 1),
            diff_ft=round(float(d[i]), 1),
            survey_year=int(yr[i]) or None,
        )
        for i in big
    ]
    # Five named soundings, spread across the depth range.
    order = np.argsort(sf)
    named = []
    wl, wa = s_lon[in_water], s_lat[in_water]
    for q in (0.05, 0.25, 0.5, 0.75, 0.95):
        i = order[int(q * (len(order) - 1))]
        named.append(
            dict(
                lon=round(float(wl[i]), 5),
                lat=round(float(wa[i]), 5),
                enc_sounding_ft=round(float(sf[i]), 1),
                dem_ft=round(float(dem_s[in_water][i]), 1),
                diff_ft=round(float(d[i]), 1),
            )
        )

    # Features the contour lines miss: water far from any ENC contour but with real relief.
    sm_w = ndimage.gaussian_filter(work_ft, 1.0, mode="nearest")
    relief = ndimage.maximum_filter(
        sm_w, size=int(round(150 / cell_m))
    ) - ndimage.minimum_filter(sm_w, size=int(round(150 / cell_m)))
    grid_ll = np.stack(
        np.meshgrid(
            west + (np.arange(ww) + 0.5) / ww * (east - west),
            north - (np.arange(wh) + 0.5) / wh * (north - south),
        ),
        -1,
    )
    gxy = metres_xy(grid_ll[..., 0].ravel(), grid_ll[..., 1].ravel(), lat_c)
    # ENC reaches slightly past the box; use all of its vertices near the box.
    near = [
        p
        for ft in LEVELS_FT
        for line in enc_levels.get(ft, [])
        for p in line
        if west - 0.02 < p[0] < east + 0.02 and south - 0.02 < p[1] < north + 0.02
    ]
    if near:
        dist_enc = (
            cKDTree(metres_xy(*np.array(near).T, lat_c)).query(gxy)[0].reshape(wh, ww)
        )
    else:
        dist_enc = np.full((wh, ww), 1e9)
    deep_enough = work_ft > 10
    gap = deep_enough & (dist_enc > 250)
    missed = gap & (relief > 15)
    features = dict(
        water_share_with_no_enc_contour_within_250m=round(
            float(gap.sum() / max(1, deep_enough.sum())), 3
        ),
        share_of_that_with_over_15ft_relief_in_150m=round(
            float(missed.sum() / max(1, gap.sum())), 3
        ),
        area_km2_missed=round(float(missed.sum() * cell_m * cell_m / 1e6), 2),
    )
    # Largest missed blob centre, to point at in the screenshots.
    lab_im, nl = ndimage.label(missed)
    blobs = []
    if nl:
        sizes_b = ndimage.sum(missed, lab_im, range(1, nl + 1))
        for i in np.argsort(sizes_b)[::-1][:3]:
            ys, xs = np.where(lab_im == i + 1)
            cy, cx = int(ys.mean()), int(xs.mean())
            blobs.append(
                dict(
                    lon=round(float(grid_ll[cy, cx, 0]), 4),
                    lat=round(float(grid_ll[cy, cx, 1]), 4),
                    km2=round(float(sizes_b[i] * cell_m * cell_m / 1e6), 2),
                    depth_ft_range=[
                        round(float(work_ft[lab_im == i + 1].min()), 0),
                        round(float(work_ft[lab_im == i + 1].max()), 0),
                    ],
                )
            )
    features["largest_blobs"] = blobs

    water_px = int(water.sum())
    metrics = dict(
        title=a["title"],
        bbox=list(bbox),
        station=a["station"],
        navd88_to_mllw_shift_m=a["shift_m"],
        source_px=[w0, h0],
        output_px=[ow, oh],
        metres_per_output_px=round(width_m / ow, 1),
        source_m_px=[round(width_m / w0, 2), round(height_m / h0, 2)],
        area_km2=round(width_m * height_m / 1e6, 1),
        water_share=round(water_px / (ow * oh), 3),
        dem_depth_ft_p1_p50_p99_of_water=pct(full_ft[full_ft > 0], [1, 50, 99]),
        dem_max_depth_ft=round(float(full_ft.max()), 0),
        sizes_bytes=sizes,
        contour_bytes={str(ft): len(paths[ft].encode()) for ft in LEVELS_FT},
        contour_bytes_total=sum(len(p.encode()) for p in paths.values()),
        enc_vertices_in_box=enc_vertices,
        enc_contour_bytes_estimate=None,
        vs_enc_contours=dict(
            per_level=per_level,
            pointwise_abs_diff_ft_p50_p90=pct(pointwise, [50, 90])
            if len(pointwise)
            else None,
            best_within_12m_abs_diff_ft_p50_p90=pct(best, [50, 90])
            if len(best)
            else None,
            share_within_3ft_pointwise=round(float((pointwise <= 3).mean()), 3)
            if len(pointwise)
            else None,
            share_within_3ft_best12m=round(float((best <= 3).mean()), 3)
            if len(best)
            else None,
        ),
        enc_label_points=check_points,
        soundings=soundings,
        five_soundings=named,
        resolution_simulation=resolution_sim,
        largest_sounding_misses=largest_misses,
        features_missed=features,
        seconds=dict(
            load_tif=round(t_load, 2),
            resample=round(t_resample, 2),
            contours=round(t_contour, 2),
            shade_and_png=round(t_shade, 2),
            total=round(time.time() - t0, 2),
        ),
    )
    meta = dict(
        title=a["title"],
        bbox=list(bbox),
        map=[
            round(v, 4)
            for v in (*lonlat_to_map(west, north), *lonlat_to_map(east, south))
        ],
        png=png.name,
        mask=name + "-mask.png",
        sites=[dict(name=n, lat=la, lon=lo) for n, la, lo in a["sites"]],
        size=[ow, oh],
        levels=[dict(ft=ft, d=paths[ft]) for ft in LEVELS_FT if paths[ft]],
    )
    return meta, metrics


def enc_bytes_in_box(enc_levels, bbox):
    """Bytes of ENC path text that fall inside the box (vertices counted at ~6 bytes each)."""
    west, south, east, north = bbox
    n = sum(
        1
        for ft in LEVELS_FT
        for line in enc_levels.get(ft, [])
        for p in line
        if west <= p[0] <= east and south <= p[1] <= north
    )
    return n * 6


def build(work, scale):
    need_stack()
    OUT.mkdir(parents=True, exist_ok=True)
    enc_levels, enc_labs = load_depthdata()
    areas, metrics = {}, {}
    for name, a in AREAS.items():
        meta, m = build_area(name, a, work, enc_levels, enc_labs, scale, OUT)
        m["enc_contour_bytes_estimate"] = enc_bytes_in_box(enc_levels, a["bbox"])
        sn = m["soundings"]
        meta["stats"] = dict(
            png_bytes=m["sizes_bytes"]["png_512"],
            webp_bytes=m["sizes_bytes"]["webp80_512"],
            contour_bytes=m["contour_bytes_total"],
            enc_bytes=m["enc_contour_bytes_estimate"],
            m_per_px=m["metres_per_output_px"],
            source_m_px=m["source_m_px"],
            note=a.get("note"),
            snd_n=sn["n"],
            snd_median=sn["median_diff_ft"],
            snd_mae=sn["mae_ft"],
            snd_within3=sn["within_3ft"],
            snd_mae_after=sn["mae_after_removing_median_ft"],
            contour_within3=m["vs_enc_contours"]["share_within_3ft_best12m"],
        )
        areas[name], metrics[name] = meta, m
        print(
            name,
            m["sizes_bytes"],
            "contours",
            m["contour_bytes_total"],
            "enc~",
            m["enc_contour_bytes_estimate"],
            m["seconds"],
        )
    legend = [dict(ft=ft, rgb=list(rgb)) for ft, rgb in RAMP]
    js = (
        "/* Generated by scripts/spike_depth_shading.py on %s; do not edit.\n * Smoothed contours from NOAA NCEI CUDEM (1/9 arc-second, NAVD88 shifted to MLLW), feet below low tide. Not for navigation. */\nwindow.SHADING=%s;\n"
        % (
            time.strftime("%Y-%m-%d"),
            json.dumps(
                dict(
                    scale=scale,
                    proj=dict(lon0=LON0, lat0=LAT0, kx=KX, k=KY),
                    legend=legend,
                    areas=areas,
                ),
                separators=(",", ":"),
            ),
        )
    )
    (OUT / "shading-data.js").write_text(js)
    (OUT / "metrics.json").write_text(json.dumps(metrics, indent=1))
    print(
        "wrote",
        OUT / "shading-data.js",
        (OUT / "shading-data.js").stat().st_size,
        "bytes",
    )


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("step", choices=["fetch", "build"])
    ap.add_argument(
        "--work",
        required=True,
        help="scratch directory outside the repo for the downloaded files",
    )
    ap.add_argument(
        "--scale",
        type=float,
        default=0.005,
        help="contour path unit in map units (the page's own is 0.01)",
    )
    args = ap.parse_args(argv)
    work = Path(args.work)
    if REPO in work.resolve().parents or work.resolve() == REPO:
        sys.exit("--work must be outside the repo")
    if args.step == "fetch":
        fetch(work)
    else:
        build(work, args.scale)


if __name__ == "__main__":
    main()
