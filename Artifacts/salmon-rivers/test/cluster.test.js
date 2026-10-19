const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../cluster.js');

// The rule the page used before the grid: every pair is compared.
function reference(pts, radius, selectedId) {
  const used = {}, groups = [];
  pts.forEach(p => {
    if (used[p.id]) return;
    const g = [p]; used[p.id] = 1;
    if (p.id !== selectedId) {
      pts.forEach(q => {
        if (used[q.id] || q.id === selectedId) return;
        if (Math.hypot(p.x - q.x, p.y - q.y) < radius) { g.push(q); used[q.id] = 1; }
      });
    }
    groups.push(g);
  });
  return groups;
}
let seed = 12345;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const make = (n, w, h) => Array.from({ length: n }, (_, i) => ({ id: 's' + i, x: rnd() * w, y: rnd() * h }));
const ids = gs => gs.map(g => g.map(p => p.id));

test('grid clustering returns exactly the groups the all-pairs rule returns', () => {
  for (let t = 0; t < 40; t++) {
    const pts = make(50 + t * 10, 400 + t * 20, 600);
    const sel = t % 3 === 0 ? pts[7].id : null;
    assert.deepEqual(ids(C.group(pts, 30, sel)), ids(reference(pts, 30, sel)), `trial ${t}`);
  }
});

test('control: the comparison can fail (a wrong radius gives different groups)', () => {
  const pts = make(200, 300, 300);
  assert.notDeepEqual(ids(C.group(pts, 45, null)), ids(reference(pts, 30, null)));
});

test('every point lands in exactly one group, and the selected point stays alone', () => {
  const pts = make(1000, 500, 500);
  const gs = C.group(pts, 30, 's5');
  const seen = gs.flat().map(p => p.id);
  assert.equal(seen.length, pts.length);
  assert.equal(new Set(seen).size, pts.length);
  assert.deepEqual(gs.find(g => g.some(p => p.id === 's5')).map(p => p.id), ['s5']);
});

test('points exactly 30 px apart stay apart; 29.9 px apart join', () => {
  assert.equal(C.group([{ id: 'a', x: 0, y: 0 }, { id: 'b', x: 30, y: 0 }], 30, null).length, 2);
  assert.equal(C.group([{ id: 'a', x: 0, y: 0 }, { id: 'b', x: 29.9, y: 0 }], 30, null).length, 1);
});

test('thousands of points stay responsive: 5,000 in a few ms, and growth is not quadratic', () => {
  const time = n => {
    const pts = make(n, 1200, 800);
    C.group(pts, 30, null); // warm
    const t0 = process.hrtime.bigint();
    for (let r = 0; r < 5; r++) C.group(pts, 30, null);
    return Number(process.hrtime.bigint() - t0) / 5e6;
  };
  const t5k = time(5000), t20k = time(20000);
  console.log(`# grid cluster: 5,000 points ${t5k.toFixed(2)} ms, 20,000 points ${t20k.toFixed(2)} ms`);
  assert.ok(t5k < 50, `5,000 points took ${t5k} ms`);
  // Four times the points should cost about four times, not sixteen.
  assert.ok(t20k < t5k * 10, `20,000 took ${t20k} ms vs ${t5k} ms for 5,000`);
  // Known-bad input for the timing check itself: the all-pairs rule is far over the budget at 20,000.
  const pts = make(5000, 1200, 800);
  const r0 = process.hrtime.bigint(); reference(pts, 30, null);
  const tref = Number(process.hrtime.bigint() - r0) / 1e6;
  console.log(`# all-pairs reference: 5,000 points ${tref.toFixed(1)} ms`);
  assert.ok(tref > t5k, 'control: the reference is slower than the grid');
});

// ---- how a group is drawn ----

const fs = require('node:fs');
const path = require('node:path');
const mk = (...rs) => rs.map((r, i) => ({ id: 'm' + i, vw: typeof r === 'string' ? { r, release: false } : r }));

test('Typical season: a cluster is always neutral, even when every member agrees', () => {
  assert.deepEqual(C.look(mk('prime', 'good', 'slow'), 'typical'), { neutral: true });
  assert.deepEqual(C.look(mk('prime', 'prime', 'prime'), 'typical'), { neutral: true }, 'unanimous Prime still says nothing about a statewide group');
  assert.deepEqual(C.look(mk('good', 'good'), 'typical'), { neutral: true });
});

test('Recent reports: a cluster keeps its colour only when every member has it', () => {
  // known-good input: members agree, so the colour is true of all of them
  assert.deepEqual(C.look(mk('good', 'good'), 'reports'), { neutral: false, r: 'good' });
  // known-bad inputs: one member differs in rating, or in release-only state, so a colour would mislead
  assert.deepEqual(C.look(mk('prime', 'good'), 'reports'), { neutral: true });
  assert.deepEqual(C.look(mk('good', 'prime'), 'reports'), { neutral: true }, 'order does not decide it');
  assert.deepEqual(C.look(mk('fair', { r: 'fair', release: true }), 'reports'), { neutral: true });
  assert.deepEqual(C.look(mk('unrated', 'good'), 'reports'), { neutral: true });
});

test('the page draws clusters through Cluster.look and never from the best member', () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  const render = html.slice(html.indexOf('function render()'), html.indexOf('/* ---- gestures ---- */'));
  assert.match(render, /var look = Cluster\.look\(g, view\);/);
  assert.match(render, /c\.g\.classList\.toggle\('neutral', look\.neutral\);/);
  assert.doesNotMatch(render, /colorVar\(g\[0\]\.vw\.r\)/, 'a cluster must not take its first (best) member colour');
  assert.match(html, /\.cluster\.neutral circle \{ fill: var\(--cluster\); \}/);
});
