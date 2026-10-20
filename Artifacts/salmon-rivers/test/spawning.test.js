// node --test Artifacts/salmon-rivers/test/spawning.test.js   (from the repo root)
// Spawning mode on the Map page: the sites.js data, its species names, and the page wiring that carries it.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dir = path.join(__dirname, '..');
const repo = path.join(dir, '..', '..');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');

function loadWin(file, key) {
  const sandbox = { window: {} };
  vm.runInNewContext(fs.readFileSync(path.join(dir, file), 'utf8'), sandbox, { filename: file });
  return JSON.parse(JSON.stringify(sandbox.window[key]));
}
const SITES = loadWin('sites.js', 'SITES');

// The app's vocabulary, read the way the repo's species-vocab.test.js reads it.
const fisheries = JSON.parse(fs.readFileSync(path.join(repo, 'WAFishMap/Resources/fisheries.json'), 'utf8'));
function appSpeciesNames(f) {
  const names = new Set();
  f.areas.forEach(a => a.species.forEach(s => names.add(s.species)));
  f.freshwater.species.forEach(s => names.add(s.species));
  Object.values(f.freshwater.byCounty).forEach(rows => rows.forEach(s => names.add(s.species)));
  Object.values(f.freshwater.byWaterbody).forEach(rows => rows.forEach(s => names.add(s.species)));
  return names;
}
const APP = appSpeciesNames(fisheries);
// The app has no sockeye guidance, so "Sockeye Salmon" cannot be an app name. It is the only name allowed in without one.
const ALLOW = new Set(['Sockeye Salmon']);
const nameOk = n => APP.has(n) || ALLOW.has(n);

const FAMS = ['Chinook Salmon', 'Coho Salmon', 'Chum Salmon', 'Pink Salmon', 'Sockeye Salmon'];
const RUNS = ['summer run', 'spring run', 'tule', 'upriver bright', 'odd years'];
const KINDS = ['creek', 'river', 'hatchery', 'ladder', 'falls'];
const inWA = s => s.lat > 45.5 && s.lat < 49.05 && s.lon > -124.8 && s.lon < -116.9;
const monthsOk = a => Array.isArray(a) && a.every(m => Number.isInteger(m) && m >= 1 && m <= 12) && new Set(a).size === a.length;

test('sites.js: 75 sites in Washington, unique ids, every field the page reads', () => {
  assert.equal(SITES.length, 75);
  assert.equal(new Set(SITES.map(s => s.id)).size, SITES.length, 'duplicate id');
  for (const s of SITES) {
    assert.ok(typeof s.id === 'string' && /^[a-z0-9-]+$/.test(s.id), s.id);
    assert.ok(s.name && s.county && s.water, s.id);
    assert.ok(KINDS.includes(s.kind), `${s.id} kind ${s.kind}`);
    assert.ok(inWA(s), `${s.id} at ${s.lat},${s.lon} is outside Washington`);
    assert.ok(['site', 'typical', 'none'].includes(s.src), `${s.id} src ${s.src}`);
    assert.ok(/^https:\/\//.test(s.url), `${s.id} url`);
    assert.equal(s.src === 'none', s.sp.length === 0, `${s.id}: "none" exactly when no species are listed`);
  }
});

test('sites.js: months are 1-12, peak and active never share a month, runs and families are known', () => {
  let rows = 0;
  for (const s of SITES) for (const r of s.sp) {
    rows++;
    assert.ok(monthsOk(r.best) && r.best.length >= 1, `${s.id} ${r.label} best ${r.best}`);
    assert.ok(monthsOk(r.good), `${s.id} ${r.label} good ${r.good}`);
    assert.deepEqual(r.best.filter(m => r.good.includes(m)), [], `${s.id} ${r.label}: a month is both peak and active`);
    assert.ok(FAMS.includes(r.fam), `${s.id}: family ${r.fam}`);
    if ('run' in r) assert.ok(RUNS.includes(r.run), `${s.id}: run ${r.run}`);
    assert.equal(!!r.odd, r.fam === 'Pink Salmon', `${s.id}: only pink salmon are odd-year`);
    if (r.pass) assert.equal(s.kind, 'ladder', `${s.id}: passing rows belong to fish ladders`);
  }
  assert.ok(rows > 100, `only ${rows} rows`);
  assert.ok(SITES.filter(s => s.kind === 'ladder').every(s => s.sp.every(r => r.pass)), 'every ladder row is a passing row');
});

test('control: the name check rejects near-misses, and the allow-list is only sockeye', () => {
  assert.ok(APP.size >= 25, `the extractor read only ${APP.size} names`);
  for (const n of ['Coho Salmon', 'Chinook Salmon', 'Fall Chinook', 'Chum Salmon', 'Pink Salmon']) assert.ok(APP.has(n), n);
  assert.ok(!APP.has('Sockeye Salmon'), 'the app now has sockeye: drop the allow-list');
  for (const n of ['Coho', 'Chinook', 'Sockeye', 'sockeye salmon', 'Fall Chinook ', 'Summer Chinook', 'Chinook Salmon (summer run)']) assert.ok(!nameOk(n), `"${n}" passed`);
  assert.ok(!inWA({ lat: 45.4, lon: -122.6 }) && !inWA({ lat: 47.6, lon: -116.5 }), 'control: Oregon and Idaho points fail the box');
  assert.ok(!monthsOk([0]) && !monthsOk([13]) && !monthsOk([3, 3]), 'control: bad months fail');
});

test('every label and family in sites.js is an exact app species name (sockeye allow-listed), never glued to its run', () => {
  const used = new Set();
  for (const s of SITES) for (const r of s.sp) {
    assert.ok(nameOk(r.label), `${s.id}: label "${r.label}" is not an app name`);
    assert.ok(nameOk(r.fam), `${s.id}: family "${r.fam}" is not an app name`);
    for (const run of RUNS) assert.ok(!r.label.toLowerCase().includes(run), `${s.id}: "${r.label}" carries its run in the name`);
    used.add(r.label);
  }
  assert.ok([...used].filter(n => ALLOW.has(n)).length === 1, 'sockeye is the one allow-listed name in use');
});

test('index.html: no seasonal timing field names, and sites.js is read through r.best / r.good', () => {
  assert.doesNotMatch(html, /bestMonths|goodMonths|fisheries\.json/);
  assert.match(html, /<script src="sites\.js"><\/script>/);
  assert.match(html, /r\.best/);
  assert.match(html, /r\.good/);
});

test('index.html: Spawning is a third mode with its own link, ribbon, legend, sheet and list', () => {
  assert.match(html, /<button type="button" role="radio" aria-checked="false" data-mode="spawning">Spawning<\/button>/);
  assert.match(html, /mode=spawning\(&\|\$\)\/\.test\(location\.search\)\) setMode\('spawning'\)/);
  assert.match(html, /id="year" role="radiogroup" aria-label="Month"/);
  assert.match(html, /setPointerCapture/);
  assert.match(html, /<\/b> at peak and <b>/);
  for (const w of ['Peak', 'Active', 'Starting or ending', 'Quiet', 'Species not listed', 'Dashed: fish ladder, passing not spawning']) assert.ok(html.includes('<i></i>' + w + '</li>'), `legend item ${w}`);
  assert.equal((html.match(/Count: several sites/g) || []).length, 3, 'the cluster legend string is reused, not copied');
  assert.match(html, /Typical timing, not a guarantee and not regulation/);
  assert.match(html, /https:\/\/wdfw\.wa\.gov\/places-to-go\/salmon-viewing/);
  assert.match(html, /Stay out of the water and off the gravel/);
  assert.match(html, /Through the year/);
  assert.match(html, /maps\.apple\.com\/\?q=' \+ encodeURIComponent\(/);
  assert.match(html, /'Sites' : 'Rivers'/);
  // Spawning groups go through Cluster.look like the other modes; there are no rings.
  assert.doesNotMatch(html, /paintRing|pathLength|Group: ring/);
});

test('index.html: the app tab bar, with Map current, and the Year link inside the app', () => {
  assert.match(html, /<nav class="apptabs" aria-label="Washington Fishing Map"><div class="apptabs-track"><a href="index.html" aria-current="page">Map<\/a><a href="year\/index.html">Year<\/a><a href="spots\/index.html">Spots<\/a><a href="counts\/index.html">Counts<\/a><\/div><\/nav>/);
  assert.doesNotMatch(html, /UUDwR9AvgqUZCWscdj5JJF/, 'the Year page is a tab now, not another artifact');
  assert.match(html, /<a href="year\/index\.html">Washington Fishing Year/);
  // The tab bar CSS sits after the page's own style block, so the page's design tests still read the page's CSS first.
  assert.ok(html.indexOf('.apptabs{') > html.indexOf('</style>'), 'tab bar CSS after the page style');
});

test('the four pages share one tab bar CSS with the iOS dark selected segment', () => {
  const css = fs.readFileSync(path.join(dir, 'tabbar.css'), 'utf8');
  assert.equal((css.match(/--tab-seg:#636366/g) || []).length, 2, 'both dark blocks');
  assert.doesNotMatch(css, /--tab-seg:#1C1C1E/);
  const pages = ['year', 'spots', 'counts'].map(p => fs.readFileSync(path.join(dir, p, 'index.html'), 'utf8'));
  for (const p of pages.concat([html])) assert.ok(p.includes(css.trim().split('\n').pop()), 'every page carries the current tab bar CSS');
  for (const p of pages.concat([html])) assert.equal((p.match(/--tab-seg:#636366/g) || []).length, 2);
});

test('the Year page links back to the Map inside the app', () => {
  const year = fs.readFileSync(path.join(dir, 'year', 'index.html'), 'utf8');
  assert.doesNotMatch(year, /9oA145toRsmFcDYurdJbey/);
  assert.match(year, /\{href:"\.\.\/index\.html",children:"Washington Fishing Map"\}/);
});
