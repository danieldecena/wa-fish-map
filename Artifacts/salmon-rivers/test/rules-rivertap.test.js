// node --test Artifacts/salmon-rivers/test/rules-rivertap.test.js   (from the repo root)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dir = path.join(__dirname, '..');
const Rules = require(path.join(dir, 'rules.js'));
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
// Load a browser data file in its own context; JSON round-trip so its objects compare with this realm's.
function loadWin(file, key) {
  const sandbox = { window: {} };
  vm.runInNewContext(fs.readFileSync(path.join(dir, file), 'utf8'), sandbox, { filename: file });
  return JSON.parse(JSON.stringify(sandbox.window[key]));
}
const TAP = loadWin('rivers-tap.js', 'RIVERTAP');
const GEO_PROJ = loadWin('geo.js', 'GEO').proj;
const ISO = /^\d{4}-\d{2}-\d{2}$/;
const realDate = s => ISO.test(s) && new Date(s + 'T00:00:00Z').toISOString().slice(0, 10) === s;

// The flow-array rule, as a function so the test can show it rejects bad input.
function validFlowRow(a) { return Array.isArray(a) && a.length === 5 && a.every(n => typeof n === 'number' && Number.isFinite(n) && n >= 0) && a.every((n, i) => i === 0 || n >= a[i - 1]); }

test('rules.js: every rule has rivers[], a real ISO published date, a sentence and an https wdfw.wa.gov url', () => {
  assert.ok(Array.isArray(Rules.RULES) && Rules.RULES.length >= 1);
  assert.ok(realDate(Rules.CHECKED), 'CHECKED');
  for (const r of Rules.RULES) {
    assert.ok(Array.isArray(r.rivers) && r.rivers.length >= 1 && r.rivers.every(n => typeof n === 'string' && n.length > 0), JSON.stringify(r.rivers));
    assert.ok(realDate(r.published), `published ${r.published}`);
    assert.ok(r.published <= Rules.CHECKED, 'published after the date the rules were checked');
    assert.equal(typeof r.d, 'string'); assert.ok(r.d.length > 20 && r.d.length < 400);
    assert.doesNotMatch(r.d, /\b20\d\d-\d\d-\d\d\b/, 'keep ISO dates out of the sentence; the sheet shows the posted date');
    const u = new URL(r.url);
    assert.equal(u.protocol, 'https:'); assert.equal(u.hostname, 'wdfw.wa.gov');
  }
  assert.ok(!realDate('2026-02-30'), 'control: an impossible date is rejected');
});

test('rules.js: forRiver matches exact names only', () => {
  assert.ok(Rules.forRiver('Stillaguamish River').length >= 1);
  assert.ok(Rules.forRiver('Hoh River').length >= 1);
  assert.deepEqual(Rules.forRiver('Stillaguamish'), [], 'near-miss names do not match');
  assert.deepEqual(Rules.forRiver('stillaguamish river'), []);
  assert.deepEqual(Rules.forRiver('Chehalis River'), []);
  for (const r of Rules.RULES) for (const n of r.rivers) assert.ok(Rules.forRiver(n).includes(r), n);
});

test('rules.js: every river a rule names is a river the map can tap, and only one river carries that name', () => {
  const byName = new Map();
  for (const r of TAP.rivers) byName.set(r.name, (byName.get(r.name) || 0) + 1);
  for (const r of Rules.RULES) for (const n of r.rivers) {
    assert.ok(byName.has(n), `${n} is not in rivers-tap.js, so its notice could never be shown`);
    // A notice keyed by name would otherwise appear on a same-named river elsewhere in the state.
    assert.equal(byName.get(n), 1, `${n} names ${byName.get(n)} rivers`);
  }
});

test('rivers-tap.js: parses, same projection as geo.js, unique ids, paths the page can read', () => {
  assert.ok(TAP && Array.isArray(TAP.rivers) && TAP.rivers.length > 50, 'rivers');
  assert.deepEqual(TAP.proj, GEO_PROJ, 'same projection as geo.js');
  assert.deepEqual(TAP.proj, { kx: 69.21431738704068, k: 100, lat0: 49.1, lon0: -125 });
  const ids = TAP.rivers.map(r => r.id);
  assert.equal(new Set(ids).size, ids.length, 'duplicate ids');
  for (const r of TAP.rivers) {
    assert.match(r.id, /^[a-z0-9-]+$/, r.id);
    assert.ok(typeof r.name === 'string' && r.name.length > 0, r.id);
    assert.ok(Number.isInteger(r.order) && r.order >= 1 && r.order <= 10, `${r.id} order`);
    assert.ok(r.lengthKm > 0, `${r.id} length`);
    assert.ok(Array.isArray(r.center) && r.center.length === 2 && r.center.every(Number.isFinite), `${r.id} center`);
    // The page parses vertices as number pairs after M: absolute moveto/implicit lineto only.
    assert.match(r.d, /^M[-\d. M]+$/, `${r.id} path uses only M and numbers`);
    assert.equal((r.d.match(/-?\d+(?:\.\d+)?/g) || []).length % 2, 0, `${r.id} odd number count`);
  }
});

test('rivers-tap.js: each flow has a gauge, years, and 12 months of 5 ascending numbers', () => {
  const flows = TAP.rivers.filter(r => r.flow !== null);
  assert.ok(flows.length >= 10, `${flows.length} rivers with flow`);
  for (const r of TAP.rivers) {
    if (r.flow === null) continue;
    const f = r.flow;
    assert.match(f.gauge, /^\d{8,15}$/, `${r.id} gauge`);
    assert.ok(typeof f.gaugeName === 'string' && f.gaugeName.length > 5, `${r.id} gaugeName`);
    assert.ok(Number.isInteger(f.beginYear) && Number.isInteger(f.endYear) && f.beginYear >= 1850 && f.beginYear <= f.endYear && f.endYear <= 2026, `${r.id} years`);
    assert.deepEqual(Object.keys(f.months).sort((a, b) => a - b), ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'], `${r.id} months`);
    for (const m of Object.keys(f.months)) assert.ok(validFlowRow(f.months[m]), `${r.id} month ${m}: ${JSON.stringify(f.months[m])}`);
  }
  // Control: the row rule rejects what it should.
  assert.ok(!validFlowRow([5, 4, 3, 2, 1]), 'descending');
  assert.ok(!validFlowRow([1, 2, 3, 4]), 'four values');
  assert.ok(!validFlowRow([1, 2, NaN, 4, 5]), 'NaN');
  assert.ok(validFlowRow([1, 2, 2, 4, 5]), 'ties are allowed');
});

test('index.html: no seasonal timing fields, and the two new files are optional', () => {
  assert.doesNotMatch(html, /bestMonths|goodMonths|fisheries\.json/);
  assert.match('x.bestMonths', /bestMonths|goodMonths/, 'control: the pattern does match a timing field');
  assert.match(html, /<script src="geo\.js"><\/script>\s*<script src="rivers-tap\.js"><\/script>\s*<script src="rules\.js"><\/script>/);
  assert.match(html, /typeof RIVERTAP !== 'undefined'/);
  assert.match(html, /typeof Rules !== 'undefined'/);
  // No network requests: the USGS and WDFW addresses are links only.
  assert.doesNotMatch(html, /fetch\(|XMLHttpRequest|navigator\.geolocation/);
});
