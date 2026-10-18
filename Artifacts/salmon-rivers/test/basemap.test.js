const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const T = require('../typical.js');

const dir = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
global.window = {};
require('../geo.js');
const GEO = window.GEO;
delete global.window;

const nums = d => d.replace(/[MZL]/g, ' ').trim().split(/\s+/).map(Number);
const pairs = d => { const n = nums(d); const o = []; for (let i = 0; i < n.length; i += 2) o.push([n[i], n[i + 1]]); return o; };
const ringsOf = d => d.split('M').filter(Boolean).map(pairs);
const inRing = (x, y, r) => { let c = false; for (let i = 0, j = r.length - 1; i < r.length; j = i++) { const a = r[i], b = r[j]; if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; };
const water = ringsOf(T.basemap.water);
// 300 m is 0.3 map units wide in y (100 units per degree) and a little more in x.
const inWater = (x, y) => [[0, 0], [0.3, 0], [-0.3, 0], [0, 0.3], [0, -0.3]].some(([dx, dy]) => water.some(r => inRing(x + dx, y + dy, r)));
const land = pairs(T.basemap.land);
const rivers = [GEO.hl.columbia, ...Object.values(GEO.base)].flatMap(pairs);
const cell = new Map();
rivers.forEach(p => { const k = Math.floor(p[0]) + ',' + Math.floor(p[1]); (cell.get(k) || cell.set(k, []).get(k)).push(p); });
const onRiver = p => { for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) for (const q of cell.get((Math.floor(p[0]) + dx) + ',' + (Math.floor(p[1]) + dy)) || []) if (near(p, q, 0.6)) return true; return false; };
const proj = (lon, lat) => [(lon - GEO.proj.lon0) * GEO.proj.kx, (GEO.proj.lat0 - lat) * GEO.proj.k];
const near = (p, q, tol) => Math.hypot(p[0] - q[0], p[1] - q[1]) <= tol;

test('the land tint is one closed polygon inside Washington, and the outline is made of real borders', () => {
  assert.match(T.basemap.land, /^M[\d. -]+Z$/);
  assert.equal((T.basemap.land.match(/M/g) || []).length, 1, 'one polygon');
  assert.ok(land.length > 60, `${land.length} vertices`);
  const [x0, y0] = GEO.bounds.state[0], [x1, y1] = GEO.bounds.state[1];
  // The tint never leaves the state's own box on the north, east or south. The west is ocean, which the water polygons cover.
  for (const [x, y] of land) assert.ok(x <= x1 + 1 && y >= y0 - 1 && y <= y1, `vertex ${x},${y} is outside the state box`);
  assert.ok(Math.max(...land.map(p => p[1])) <= y1, 'nothing south of the state box (45.5 N): no Oregon');
  assert.ok(T.basemap.outline.startsWith('M') && !/Z/.test(T.basemap.outline), 'the outline is open lines, not a shape');
  assert.equal((T.basemap.outline.match(/M/g) || []).length, 2, 'two lines: the 49th parallel and east border, the 46th parallel and the Columbia');
});

test('the north and east edges are the straight borders, and the south edge is the Columbia from geo.js', () => {
  const find = p => land.findIndex(q => near(q, proj(...p), 0.15));
  const nw = find([-122.77, 49.0]), ne = find([-117.03, 49.0]), lew = find([-117.04, 46.42]), tail = find([-116.92, 46.0]), mcn = find([-119.0, 46.0]);
  for (const [n, i] of Object.entries({ nw, ne, lew, tail, mcn })) assert.ok(i >= 0, `${n} corner is missing`);
  assert.ok(nw < ne && ne < lew && lew < tail && tail < mcn, 'corners in order');
  // 46th parallel and 49th parallel are exact; the 117.04 meridian is exact.
  assert.equal(land[nw][1], land[ne][1]);
  assert.ok(Math.abs(land[lew][0] - land[ne][0]) < 1.1);
  assert.equal(land[tail][1], land[mcn][1]);
  // Every vertex between McNary and the river mouth lies on geo.js river geometry (the Columbia highlight or a base river), not typed in.
  const chain = land.slice(mcn + 1);
  const riverPart = chain.slice(0, chain.findIndex(p => near(p, proj(-123.76, 46.21), 1)) + 1);
  assert.ok(riverPart.length > 30, `${riverPart.length} Columbia vertices`);
  riverPart.forEach(p => assert.ok(onRiver(p), `Columbia vertex ${p} is not on any river in geo.js`));
  // Known-bad: a point well off the river is rejected by the same test, so the check can fail.
  assert.equal(onRiver([415, 330]), false);
});

test('the closure through the water never touches Canadian ground', () => {
  // Legs that cross land or an estuary on purpose, each named so a new one has to be added here.
  const FREE = [
    [proj(-117.04, 46.42), proj(-116.92, 46.0)],   // the Idaho line below Lewiston: geo.js has no Snake there
    [proj(-123.76, 46.21), proj(-124.12, 46.26)],  // Tongue Point to the river mouth
    [proj(-124.95, 48.40), proj(-124.40, 48.35)]   // across Cape Flattery
  ];
  const isFree = (a, b) => FREE.some(([p, q]) => (near(a, p, 1.5) && near(b, q, 1.5)) || (near(a, q, 1.5) && near(b, p, 1.5)));
  let long = 0, free = 0, border = 0;
  for (let i = 0; i < land.length; i++) {
    const a = land[i], b = land[(i + 1) % land.length];
    const len = Math.hypot(a[0] - b[0], a[1] - b[1]);
    if (len < 3) continue;
    if (isFree(a, b)) { long++; free++; continue; }
    if (onRiver(a) && onRiver(b)) continue; // a stretch of river, checked above
    long++;
    if (a[1] === b[1] && (a[1] === land[0][1] || Math.abs(a[1] - 310) < 0.05)) { border++; continue; } // the 49th and 46th parallels
    if (Math.abs(a[0] - 551.3) < 0.7 && Math.abs(b[0] - 551.3) < 0.7) { border++; continue; } // the east border, the 117.04 W meridian
    const n = Math.ceil(len / 0.5);
    for (let k = 0; k <= n; k++) {
      const x = a[0] + (b[0] - a[0]) * k / n, y = a[1] + (b[1] - a[1]) * k / n;
      assert.ok(inWater(x, y), `edge ${a} to ${b} leaves marine water at ${x.toFixed(1)},${y.toFixed(1)}`);
    }
  }
  assert.equal(border, 3, 'the 49th parallel, the east border and the 46th parallel');
  assert.ok(long - border - free >= 8, `${long - border - free} water legs checked`);
  assert.equal(free, 3, 'every named free leg is in the polygon');
  // Known-bad: a straight line from Semiahmoo to Cape Flattery runs over Vancouver Island, and the check says so.
  const a = proj(-122.77, 49.0), b = proj(-124.7, 48.4);
  let leaves = false;
  for (let k = 0; k <= 200; k++) { const x = a[0] + (b[0] - a[0]) * k / 200, y = a[1] + (b[1] - a[1]) * k / 200; if (!inWater(x, y)) leaves = true; }
  assert.ok(leaves, 'control: a chord over Canada must fail the water check');
});

test('both modes draw the same basemap, and it is drawn from tokens', () => {
  assert.doesNotMatch(html, /#tbase \{ display: none; \}|#app\.typ #tbase/, 'the basemap is not hidden in Recent reports');
  assert.match(html, /el\('path', \{ 'class': 'l', d: TypicalData\.basemap\.land \}, tbase\);/);
  assert.match(html, /el\('path', \{ 'class': 'o', d: TypicalData\.basemap\.outline \}, tbase\);/);
  const from = html.indexOf('#tbase .l');
  const css = html.slice(from, html.indexOf('\n.bottom {', from));
  assert.ok(css.includes('#tbase .o {'), 'control: the slice holds the basemap rules');
  assert.match(css, /#tbase \.l \{ fill: var\(--land\); stroke: none; \}/);
  assert.match(css, /#tbase \.w0 \{ fill: var\(--ground\);/);
  assert.match(css, /#tbase \.o \{[^}]*stroke: var\(--state-line\);/);
  assert.doesNotMatch(css, /#tbase[^{]*\{[^}]*(#[0-9a-f]{3,6}|rgb)/i, 'basemap colours are tokens, not literals');
});
