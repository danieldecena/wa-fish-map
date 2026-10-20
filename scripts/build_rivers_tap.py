#!/usr/bin/env python3
"""Write Artifacts/salmon-rivers/rivers-tap.js: tappable named rivers + monthly USGS flow percentiles.

Each name is split into connected groups (features whose vertices come within
GROUP_KM of each other, transitively); one entry per group, ids slugged west->east.
Flow attaches to one group only: the sole group, or the group nearest ANCHORS[name].
A gauged name with several groups and no anchor gets no flow (never guessed).

Inputs (read-only): WAFishMap/Resources/rivers.json, river_stats.json.
Projection, dp(), fmt(), path_d() and chain() are copied from scripts/build_geo.py
so paths land in the same GEO coordinate space as geo.js.

The flow is each gauge's historical range for the month (p10..p90 averaged from the
daily percentiles in river_stats.json), never today's reading. The page links the
gauge's live USGS page instead of fetching it.

Usage: build_rivers_tap.py [--eps 0.12]
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'WAFishMap', 'Resources')
SRC = os.path.join(RES, 'rivers.json')
STATS = os.path.join(RES, 'river_stats.json')
OUT = os.path.join(ROOT, 'Artifacts', 'salmon-rivers', 'rivers-tap.js')

MIN_ORDER = 4
MAX_BYTES = 450 * 1024
GROUP_KM = 2.0      # features within this distance are one river
KM_PER_UNIT = 1.1119  # one projection unit = 0.01 deg lat

# Gauge anchors (lon, lat) for names whose features split into several groups.
# Flow attaches only to the group nearest the anchor.
ANCHORS = {
    'Clearwater River': ('12097820', (-121.97, 47.15)),  # near Buckley
    'Cedar River': ('12117500', (-121.96, 47.38)),       # Landsburg
    'Green River': (None, (-121.79, 47.28)),             # below Howard A Hanson Dam
    'White River': (None, (-121.98, 47.17)),             # near Buckley
}
GEO_KX = 69.21431738704068  # constant baked into geo.js

# ---- copied from build_geo.py --------------------------------------------------
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
# -------------------------------------------------------------------------------

def sig3(v):
    if v == 0:
        return 0
    r = round(v, 2 - int(math.floor(math.log10(abs(v)))))
    return int(r) if r == int(r) else r

def monthly(months):
    out = {}
    for m in range(1, 13):
        days = months.get(str(m)) or []
        cols = []
        for i in range(5):
            vals = [d[i] for d in days
                    if isinstance(d, list) and len(d) > i and isinstance(d[i], (int, float))]
            cols.append(sig3(sum(vals) / len(vals)) if vals else None)
        out[str(m)] = cols
    return out

def fmt_dedupe(run):
    # drop consecutive vertices that print identically (no visual change)
    out = []
    last = None
    for x, y in run:
        key = (fmt(x), fmt(y))
        if key != last:
            out.append((x, y))
            last = key
    return out

def slug(name):
    out = ''.join(c if c.isalnum() else '-' for c in name.lower())
    while '--' in out:
        out = out.replace('--', '-')
    return out.strip('-')

def connected_groups(items, gap_units):
    """Union-find over point lists; two lists join if any vertices are within gap_units."""
    n = len(items)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    cell = gap_units
    grid = {}
    for i, pts in enumerate(items):
        for x, y in pts:
            grid.setdefault((int(x // cell), int(y // cell)), set()).add(i)
    g2 = gap_units * gap_units
    for i, pts in enumerate(items):
        for x, y in pts:
            cx, cy = int(x // cell), int(y // cell)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for j in grid.get((cx + dx, cy + dy), ()):
                        if find(j) == find(i):
                            continue
                        if any((x - a) ** 2 + (y - b) ** 2 <= g2 for a, b in items[j]):
                            parent[find(j)] = find(i)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())

def build(eps):
    feats = json.load(open(SRC))['features']
    stats = json.load(open(STATS))['rivers']
    by_name = {}
    for f in feats:
        by_name.setdefault(f['properties']['name'], []).append(f)

    want = sorted(n for n, fs in by_name.items()
                  if max(f['properties']['streamOrder'] for f in fs) >= MIN_ORDER)
    stats_missing = sorted(n for n in stats if n not in by_name)
    want = sorted(set(want) | {n for n in stats if n in by_name})

    entries, split, dropped, unflowed, anchored = [], [], [], [], []
    for name in want:
        fs = by_name[name]
        fpts = [[px(lo, la) for part in parts(f) for lo, la in part] for f in fs]
        groups = connected_groups(fpts, GROUP_KM / KM_PER_UNIT)
        ginfo = []
        for g in groups:
            pts = [p for i in g for p in fpts[i]]
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            ginfo.append((cx, cy, g, pts))
        ginfo.sort(key=lambda t: t[0])  # west -> east
        if len(ginfo) > 1:
            split.append((name, len(ginfo)))

        st = stats.get(name)
        flow_idx = None
        if st:
            if len(ginfo) == 1:
                flow_idx = 0
            elif name in ANCHORS:
                gauge, (alo, ala) = ANCHORS[name]
                if gauge is not None:
                    assert st['gauge'] == gauge, (name, st['gauge'], gauge)
                ax, ay = px(alo, ala)
                dists = [min(math.hypot(x - ax, y - ay) for x, y in t[3]) for t in ginfo]
                flow_idx = min(range(len(ginfo)), key=lambda k: dists[k])
                anchored.append((name, flow_idx, round(dists[flow_idx] * KM_PER_UNIT, 2)))
            else:
                unflowed.append((name, len(ginfo)))

        base = slug(name)
        for k, (cx, cy, g, _) in enumerate(ginfo):
            gid = base if k == 0 else '%s-%d' % (base, k + 1)
            simp = []
            for i in g:
                for run in chain(parts(fs[i])):
                    s = fmt_dedupe(dp([px(lo, la) for lo, la in run], eps))
                    if len(s) >= 2:
                        simp.append(s)
            d = path_d(simp)
            if not d:
                dropped.append(gid)
                continue
            flow = None
            if k == flow_idx:
                flow = {'gauge': st['gauge'], 'gaugeName': st['gaugeName'],
                        'beginYear': st['beginYear'], 'endYear': st['endYear'],
                        'months': monthly(st['months'])}
            entries.append({
                'id': gid,
                'name': name,
                'order': max(fs[i]['properties']['streamOrder'] for i in g),
                'lengthKm': round(sum(fs[i]['properties']['lengthKm'] for i in g), 1),
                'center': [round(cx, 1), round(cy, 1)],
                'd': d,
                'flow': flow,
            })
    return entries, split, dropped, unflowed, anchored, stats_missing

def write(entries, path):
    obj = {'proj': {'kx': KX, 'k': 100, 'lat0': LAT0, 'lon0': -125}, 'rivers': entries}
    txt = 'window.RIVERTAP = ' + json.dumps(obj, separators=(',', ':')) + ';\n'
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fh:
        fh.write(txt)
    return len(txt.encode())

def main():
    eps = 0.12
    if '--eps' in sys.argv:
        eps = float(sys.argv[sys.argv.index('--eps') + 1])

    # projection check against geo.js's constant and a known point
    assert abs(KX - GEO_KX) < 1e-9, (KX, GEO_KX)
    x, y = px(-122.6445, 46.4968)
    ex, ey = (-122.6445 + 125) * GEO_KX, (49.1 - 46.4968) * 100
    assert abs(x - ex) < 1e-9 and abs(y - ey) < 1e-9
    print('projection: kx=%.14f matches geo.js; (-122.6445, 46.4968) -> x=%.2f y=%.2f'
          % (KX, x, y))

    while True:
        entries, split, dropped, unflowed, anchored, missing = build(eps)
        size = write(entries, OUT)
        if size <= MAX_BYTES:
            break
        print('size %d > %d at eps %.3f, raising' % (size, MAX_BYTES, eps))
        eps = round(eps + 0.02, 3)

    ids = [e['id'] for e in entries]
    assert len(ids) == len(set(ids)), 'duplicate ids'
    flowed = [e for e in entries if e['flow']]
    assert len({e['name'] for e in flowed}) == len(flowed), 'flow on two groups of one name'
    print('eps:', eps)
    print('entries:', len(entries), ' names:', len({e['name'] for e in entries}),
          ' entries with flow:', len(flowed), ' names split:', len(split))
    print('file:', OUT, size, 'bytes (%.1f KB)' % (size / 1024))
    byid = {e['id']: e for e in entries}
    for name, k, dkm in anchored:
        gid = slug(name) if k == 0 else '%s-%d' % (slug(name), k + 1)
        e = byid[gid]
        print('anchored flow: %-17s -> %-20s center %s gauge %s (%s), anchor %.2f km from line'
              % (name, gid, e['center'], e['flow']['gauge'], e['flow']['gaugeName'], dkm))
    print('gauged names left WITHOUT flow (multi-group, no anchor):', unflowed or 'none')
    if missing:
        print('river_stats names absent from rivers.json:', missing)
    if dropped:
        print('dropped groups (no run >= 2 pts after simplification):', dropped)
    print('split names (name: groups):', ', '.join('%s: %d' % t for t in split))

if __name__ == '__main__':
    main()
