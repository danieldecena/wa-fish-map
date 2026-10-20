#!/usr/bin/env python3
"""Write Artifacts/salmon-rivers/geo.js: the river map geometry for the Washington Fishing Map.

    build_geo.py             write Artifacts/salmon-rivers/geo.js
    build_geo.py OUT.js      write somewhere else (for a diff)

Input (read-only): WAFishMap/Resources/rivers.json. Output: window.GEO with
  proj    the projection (x = (lon + 125) * kx, y = (49.1 - lat) * 100); rivers-tap.js
          and typical.js use the same one
  base    basemap river paths by stream order (order 3 and up statewide, order 2 only
          in the southwest window), Douglas-Peucker simplified
  hl      the reported reach of each Recent reports river (HL predicates below);
          the rest of that river goes into base
  pins    one pin per reported water, snapped to its highlighted reach, unless
          PIN_OVERRIDES fixes it
  bounds  the statewide and southwest views

Numbers are written the way JSON.stringify writes them (100, not 100.0), so the
file is byte-identical to the published geo.js.

History: this was the session script that first built the map (2026-10-18). On
2026-10-20 the Cowlitz and Lewis highlights were clipped to the reaches their
reports cover (Cowlitz below the Salkum hatchery, west of -122.62; Lewis below
Merwin Dam, west of -122.55). The published file kept the Cowlitz pin from before
that change, so it is pinned in PIN_OVERRIDES rather than re-snapped.
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'WAFishMap', 'Resources', 'rivers.json')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'Artifacts', 'salmon-rivers', 'geo.js')

K = 100.0
LAT0 = 49.1
LON0 = -125.0
KX = K * math.cos(math.radians(46.2))

def px(lon, lat):
    return ((lon - LON0) * KX, (LAT0 - lat) * K)

def dp(pts, eps):
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        ax, ay = pts[a]
        bx, by = pts[b]
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        mi, md = -1, 0.0
        for i in range(a + 1, b):
            x, y = pts[i]
            if L == 0:
                d = math.hypot(x - ax, y - ay)
            else:
                t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / L))
                d = math.hypot(x - (ax + t * dx), y - (ay + t * dy))
            if d > md:
                md, mi = d, i
        if md > eps and mi > 0:
            keep[mi] = True
            stack.append((a, mi))
            stack.append((mi, b))
    return [p for p, k in zip(pts, keep) if k]

def fmt(v):
    s = ('%.1f' % v)
    return s[:-2] if s.endswith('.0') else s

def path_d(runs):
    out = []
    for r in runs:
        if len(r) < 2:
            continue
        out.append('M' + ' '.join(fmt(x) + ' ' + fmt(y) for x, y in r))
    return ''.join(out)

def parts(f):
    g = f['geometry']
    if g['type'] == 'LineString':
        return [g['coordinates']]
    return g['coordinates']

def chain(ps):
    # join consecutive parts that share an endpoint
    runs = []
    for p in ps:
        if runs and runs[-1][-1] == p[0]:
            runs[-1].extend(p[1:])
        else:
            runs.append(list(p))
    return runs

feats = json.load(open(SRC))['features']
by_name = {}
for f in feats:
    by_name.setdefault(f['properties']['name'], []).append(f)

# Highlight definitions: name -> predicate on (lon, lat)
HL = {
    'cowlitz': ('Cowlitz River', lambda lo, la: la <= 46.53 and lo <= -122.62),
    'columbia': ('Columbia River', lambda lo, la: -123.77 <= lo <= -121.94),
    'lewis': ('Lewis River', lambda lo, la: la <= 45.97 and lo <= -122.55),
    'wind': ('Wind River', lambda lo, la: la <= 45.76),
    'klickitat': ('Klickitat River', lambda lo, la: la <= 45.80),
    'kalama': ('Kalama River', lambda lo, la: lo <= -122.70),
    'washougal': ('Washougal River', lambda lo, la: lo <= -122.25),
}

hl_paths = {}
hl_pts = {}
used_ids = set()
for sid, (nm, pred) in HL.items():
    runs_out = []
    allpts = []
    for f in by_name[nm]:
        used_ids.add(id(f))
        for run in chain(parts(f)):
            cur = []
            for lo, la in run:
                if pred(lo, la):
                    cur.append((lo, la))
                else:
                    if len(cur) > 1:
                        runs_out.append(cur)
                    cur = []
            if len(cur) > 1:
                runs_out.append(cur)
    for r in runs_out:
        allpts.extend(r)
    proj = [dp([px(lo, la) for lo, la in r], 0.06) for r in runs_out]
    hl_paths[sid] = path_d(proj)
    hl_pts[sid] = allpts
    print(sid, len(runs_out), 'runs', len(allpts), 'pts', len(hl_paths[sid]), 'bytes')

def snap(sid, lat, lon):
    best = min(hl_pts[sid], key=lambda p: (p[0] - lon) ** 2 * 0.48 + (p[1] - lat) ** 2)
    return best[1], best[0]

targets = {
    'cowlitz': (46.489, -122.607),
    'columbia': (46.22, -123.30),
    'kalama': (46.03, -122.84),
    'washougal': (45.60, -122.32),
    'lewis': (45.93, -122.60),
    'wind': (45.73, -121.80),
    'klickitat': (45.78, -121.22),
}
# Pins kept as published instead of re-snapped: [lat, lon].
# cowlitz: the pre-2026-10-20 snap (target on the old la <= 46.50 reach); the new reach would snap it to [46.5081, -122.628].
PIN_OVERRIDES = {
    'cowlitz': [46.4968, -122.6445],
}

pins = {}
for sid, (la, lo) in targets.items():
    sla, slo = snap(sid, la, lo)
    pins[sid] = [round(sla, 4), round(slo, 4)]
    if sid in PIN_OVERRIDES:
        print('pin', sid, pins[sid], 'overridden ->', PIN_OVERRIDES[sid])
        pins[sid] = PIN_OVERRIDES[sid]
    else:
        print('pin', sid, pins[sid])

# Drano Lake: snap to the mouth of the Little White Salmon River
lws = by_name.get('Little White Salmon River', [])
print('LWS features', len(lws))
if lws:
    pts = [p for f in lws for run in parts(f) for p in run]
    mouth = min(pts, key=lambda p: p[1] * 1.0 + 0 * p[0])  # placeholder, refined below
    # the mouth is the vertex nearest the Columbia (lowest latitude)
    mouth = min(pts, key=lambda p: p[1])
    print('LWS mouth', mouth, 'extent lat', min(p[1] for p in pts), max(p[1] for p in pts), 'lon', min(p[0] for p in pts), max(p[0] for p in pts))
    pins['drano'] = [round(mouth[1] + 0.012, 4), round(mouth[0], 4)]
else:
    pins['drano'] = [45.72, -121.64]

# Pin order as published: Kalama and Washougal were added after Drano Lake.
PIN_ORDER = ['cowlitz', 'columbia', 'lewis', 'wind', 'klickitat', 'drano', 'kalama', 'washougal']
assert sorted(PIN_ORDER) == sorted(pins), (PIN_ORDER, list(pins))
pins = {k: pins[k] for k in PIN_ORDER}

# Basemap: order >=3 statewide, order 2 only in the SW view
SW = (-123.9, -120.6, 45.2, 47.4)
buckets = {}
for f in feats:
    if id(f) in used_ids:
        continue
    o = f['properties']['streamOrder']
    runs_all = chain(parts(f))
    if o < 3:
        # keep order 2 only if it touches the SW window
        keep = any(SW[0] <= lo <= SW[1] and SW[2] <= la <= SW[3] for run in runs_all for lo, la in run)
        if not keep or o < 2:
            continue
    nm = f['properties']['name']
    # Skip the unclipped remainder of the Columbia and highlighted rivers' upstream parts? keep them as basemap.
    key = min(o, 7)
    proj = [dp([px(lo, la) for lo, la in r], 0.1 if o >= 3 else 0.08) for r in runs_all]
    buckets.setdefault(key, []).append(path_d(proj))

# Unclipped remainders of highlighted rivers go in the basemap too
for sid, (nm, pred) in HL.items():
    for f in by_name[nm]:
        o = min(f['properties']['streamOrder'], 7)
        for run in chain(parts(f)):
            cur = []
            runs_out = []
            for lo, la in run:
                if not pred(lo, la):
                    cur.append((lo, la))
                else:
                    if len(cur) > 1:
                        runs_out.append(cur)
                    cur = []
            if len(cur) > 1:
                runs_out.append(cur)
            proj = [dp([px(lo, la) for lo, la in r], 0.1) for r in runs_out]
            buckets.setdefault(o, []).append(path_d(proj))

base = {str(k): ''.join(v) for k, v in sorted(buckets.items())}
for k, v in base.items():
    print('order', k, len(v), 'bytes')

# Landmarks with projected coords
def P(lon, lat):
    x, y = px(lon, lat)
    return [round(x, 2), round(y, 2)]

data = {
    'proj': {'kx': KX, 'k': K, 'lat0': LAT0, 'lon0': LON0},
    'base': base,
    'hl': hl_paths,
    'pins': {k: {'ll': v, 'xy': P(v[1], v[0])} for k, v in pins.items()},
    'bounds': {
        'state': [P(-124.9, 49.05), P(-116.9, 45.5)],
        'sw': [P(-123.65, 46.9), P(-120.95, 45.35)],
    },
}
def js_numbers(v):
    # JSON.stringify writes an integral float without '.0'
    if isinstance(v, float) and v.is_integer():
        return int(v)
    if isinstance(v, dict):
        return {k: js_numbers(x) for k, x in v.items()}
    if isinstance(v, list):
        return [js_numbers(x) for x in v]
    return v

with open(OUT, 'w') as fh:
    fh.write('window.GEO = ' + json.dumps(js_numbers(data), separators=(',', ':')) + ';\n')
print('wrote', OUT, os.path.getsize(OUT), 'bytes')
