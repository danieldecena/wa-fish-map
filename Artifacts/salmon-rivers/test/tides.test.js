// Artifacts/salmon-rivers/test/tides.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const Tides = require('../tides.js');
// Mon Oct 26 to Sun Nov 1.
const range = { start: '2026-10-26', end: '2026-11-01', days: ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', '2026-11-01'] };

/* A small synthetic bundle: four extremes a day, Oct 26 – Nov 30, three stations. */
function mkBundle(start, end) {
  const preds = {};
  const stations = [
    { id: '9447130', name: 'Seattle', lat: 47.6026, lon: -122.3393 },
    { id: '9446484', name: 'Tacoma', lat: 47.2667, lon: -122.4133 },
    { id: '9441102', name: 'Westport', lat: 46.9043, lon: -124.1051 }
  ];
  stations.forEach((s, k) => {
    preds[s.id] = [];
    for (let d = Date.parse(start + 'T00:00:00Z'); d <= Date.parse(end + 'T00:00:00Z'); d += 86400000) {
      const day = new Date(d).toISOString().slice(0, 10);
      preds[s.id].push([day + ' 06:00', 'H', 11.5 + k], [day + ' 12:00', 'L', 5.04], [day + ' 18:00', 'H', 11.04], [day + ' 23:30', 'L', -2.04]);
    }
  });
  return { generated: start, start, end, stations, predictions: preds };
}
const bundle = mkBundle('2026-10-26', '2026-11-30');

test('stations: the fallback list is the eleven verified stations; a bundle replaces it', () => {
  assert.equal(Tides.STATIONS.length, 11);
  assert.ok(Tides.byId(Tides.DEFAULT));
  assert.equal(Tides.byId('nope'), null);
  Tides.STATIONS.forEach(s => { assert.match(s.id, /^\d{7}$/); assert.ok(s.lat > 45 && s.lat < 49.1 && s.lon < -122 && s.lon > -125.5, s.name); });
  assert.equal(Tides.stationsOf(bundle).length, 3);
  assert.equal(Tides.stationsOf(undefined), Tides.STATIONS);
  assert.equal(Tides.stationsOf({ stations: [] }), Tides.STATIONS);
});

test('nearest: Ballard -> Seattle, Grays Harbor -> Westport; a list can be passed; miles is haversine', () => {
  assert.equal(Tides.nearest(47.668, -122.386).id, '9447130');
  assert.equal(Tides.nearest(46.93, -124.05).id, '9441102');
  assert.equal(Tides.nearest(47.3, -122.4, Tides.stationsOf(bundle)).id, '9446484');
  const sea = Tides.byId('9447130'), tac = Tides.byId('9446484');
  const mi = Tides.miles(sea.lat, sea.lon, tac);
  assert.ok(mi > 22 && mi < 25, String(mi));
  assert.equal(Tides.miles(sea.lat, sea.lon, sea), 0);
});

test('days: bundled extremes for the week, in order, heights as numbers', () => {
  const ds = Tides.days(Tides.byId('9447130'), range, bundle);
  assert.deepEqual(ds.map(d => d.date), range.days);
  assert.equal(ds[0].extremes.length, 4);
  assert.deepEqual(ds[0].extremes[0], { t: '06:00', type: 'H', v: 11.5 });
  assert.ok(ds.every(d => !d.note));
});

test('days: after the bundle end the day has no extremes and a note naming the last date', () => {
  const short = mkBundle('2026-10-26', '2026-10-28');
  const ds = Tides.days(Tides.byId('9447130'), range, short);
  assert.equal(ds[2].extremes.length, 4);
  assert.equal(ds[3].extremes.length, 0);
  assert.equal(ds[3].note, 'Beyond the bundled predictions (through Oct 28)');
  assert.equal(ds[6].note, ds[3].note);
  const early = Tides.days(Tides.byId('9447130'), range, mkBundle('2026-10-28', '2026-11-30'));
  assert.equal(early[0].note, 'Before the bundled predictions (from Oct 28)');
});

test('days: null without a bundle or without predictions for the station', () => {
  assert.equal(Tides.days(Tides.byId('9447130'), range, undefined), null);
  assert.equal(Tides.days(Tides.byId('9447130'), range, { start: 'a', end: 'b' }), null);
  assert.equal(Tides.days(Tides.byId('9444900'), range, bundle), null);
});

test('fmtTime, fmtExtreme and footnote', () => {
  assert.equal(Tides.fmtTime('03:12'), '3:12 am'); assert.equal(Tides.fmtTime('13:40'), '1:40 pm');
  assert.equal(Tides.fmtTime('00:05'), '12:05 am'); assert.equal(Tides.fmtTime('12:00'), '12:00 pm');
  assert.equal(Tides.fmtExtreme({ t: '13:40', type: 'L', v: -1.04 }), 'L 1:40 pm · -1.0 ft');
  assert.equal(Tides.footnote(bundle), 'NOAA predictions through Nov 30, MLLW, local time. Not observations.');
});

function fakeDoc() {
  function El(tag) { this.tagName = tag; this.children = []; this.attrs = {}; this.text = ''; this.listeners = {}; this.value = ''; this.parentNode = null; }
  El.prototype.appendChild = function (c) { this.children.push(c); c.parentNode = this; return c; };
  El.prototype.insertBefore = function (c, ref) { var i = this.children.indexOf(ref); if (i < 0) i = this.children.length; this.children.splice(i, 0, c); c.parentNode = this; return c; };
  El.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };
  El.prototype.addEventListener = function (k, f) { (this.listeners[k] = this.listeners[k] || []).push(f); };
  El.prototype.fire = function (k) { (this.listeners[k] || []).forEach(f => f({ target: this })); };
  Object.defineProperty(El.prototype, 'textContent', { get() { return this.text + this.children.map(c => c.textContent).join(''); }, set(v) { this.text = String(v); this.children = []; } });
  Object.defineProperty(El.prototype, 'className', { get() { return this.attrs['class'] || ''; }, set(v) { this.attrs['class'] = v; } });
  Object.defineProperty(El.prototype, 'id', { get() { return this.attrs.id || ''; }, set(v) { this.attrs.id = v; } });
  Object.defineProperty(El.prototype, 'nextSibling', { get() { if (!this.parentNode) return null; const i = this.parentNode.children.indexOf(this); return this.parentNode.children[i + 1] || null; } });
  Object.defineProperty(El.prototype, 'options', { get() { return this.children; } });
  El.prototype.querySelectorAll = function (sel) {
    const out = [], m = /^([a-z]+)?(?:\.([\w-]+))?(?:#([\w-]+))?$/.exec(sel);
    (function walk(n) { n.children.forEach(c => { if ((!m[1] || c.tagName === m[1]) && (!m[2] || (c.className || '').split(' ').includes(m[2])) && (!m[3] || c.id === m[3])) out.push(c); walk(c); }); })(this);
    return out;
  };
  El.prototype.querySelector = function (sel) { return this.querySelectorAll(sel)[0] || null; };
  return { createElement: t => new El(t), createTextNode: t => ({ tagName: '#text', children: [], textContent: String(t), parentNode: null }) };
}

const days0 = Tides.days(Tides.byId('9447130'), range, bundle);

test('no network: no page code file contains fetch(, XMLHttpRequest, sendBeacon, WebSocket, EventSource or import(', () => {
  const files = ['index.html', 'links.js', 'layers.js', 'spots.js', 'season-places.js', 'tide-predictor.js', 'tide-harmonics.js', 'tides.js', 'reports.js', 'rules.js', 'season.js', 'cluster.js',
    'week/index.html', 'spots/index.html', 'counts/index.html', 'year/index.html'];
  const allow = {}; // file -> [pattern names allowed there, with a reason]
  const bad = { 'fetch(': /\bfetch\s*\(/, XMLHttpRequest: /XMLHttpRequest/, sendBeacon: /sendBeacon/, WebSocket: /WebSocket/, EventSource: /EventSource/, 'import(': /\bimport\s*\(/ };
  for (const f of files) {
    const src = fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
    for (const [name, re] of Object.entries(bad)) {
      if ((allow[f] || []).includes(name)) continue;
      assert.ok(!re.test(src), f + ' contains ' + name);
    }
  }
});

/* The bundle itself (written by scripts/build_tides.py). */
test('tides-data.js: parses, covers at least 30 days, every station has every day, ids are 7-digit WA stations', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'tides-data.js'), 'utf8');
  assert.ok(/^\/\* Generated by scripts\/build_tides\.py/.test(src));
  const win = {}; vm.runInNewContext(src, { window: win });
  const T = win.TIDES;
  assert.match(T.generated, /^\d{4}-\d{2}-\d{2}$/);
  const n = (Date.parse(T.end + 'T00:00:00Z') - Date.parse(T.start + 'T00:00:00Z')) / 86400000 + 1;
  assert.ok(n >= 30, 'covers ' + n + ' days');
  assert.ok(T.stations.length >= 20);
  const seen = new Set();
  T.stations.forEach(s => {
    assert.match(s.id, /^\d{7}$/); assert.ok(!seen.has(s.id)); seen.add(s.id);
    assert.ok(s.name && s.name.length < 24, s.id);
    assert.ok(s.lat > 45.5 && s.lat < 49.1 && s.lon < -122 && s.lon > -125, s.name + ' is inside Washington');
    const rows = T.predictions[s.id];
    assert.ok(Array.isArray(rows) && rows.length >= n * 3, s.id + ' has predictions');
    const days = new Set(rows.map(r => r[0].slice(0, 10)));
    for (let i = 0; i < n; i++) assert.ok(days.has(new Date(Date.parse(T.start + 'T00:00:00Z') + i * 86400000).toISOString().slice(0, 10)), s.name + ' has every day');
    rows.forEach((r, i) => {
      assert.match(r[0], /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/); assert.ok(r[1] === 'H' || r[1] === 'L'); assert.equal(typeof r[2], 'number');
      if (i) assert.ok(r[0] > rows[i - 1][0], s.id + ' increasing at ' + r[0]);
    });
    assert.ok(rows[0][0].slice(0, 10) >= T.start && rows[rows.length - 1][0].slice(0, 10) <= T.end);
  });
  assert.deepEqual(Object.keys(T.predictions).sort(), [...seen].sort());
  Tides.STATIONS.forEach(s => assert.ok(seen.has(s.id), 'bundle keeps ' + s.name));
});

/* The map's TODAY is Washington's date, not the viewer's. A device in Tokyo at 20:30 Pacific on Oct 26 already reads Oct 27,
   which would move the map-sheet tides and the Seasons layer's tags a day ahead. */
test('index.html: todayISO reads the date in Washington, whatever timezone the device is in', () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  const fn = /function todayISO\(\) \{[\s\S]*?\n  \}/.exec(html);
  assert.ok(fn, 'index.html defines todayISO');
  const at = Date.parse('2026-10-27T03:30:00Z'), shift = 9 * 3600000;
  class TokyoDate extends Date {
    constructor(...a) { super(...(a.length ? a : [at])); }
    getFullYear() { return new Date(this.getTime() + shift).getUTCFullYear(); }
    getMonth() { return new Date(this.getTime() + shift).getUTCMonth(); }
    getDate() { return new Date(this.getTime() + shift).getUTCDate(); }
  }
  assert.equal(new TokyoDate().getDate(), 27, 'control: the fake device reads Oct 27');
  const ctx = { Date: TokyoDate, Tides, Intl };
  vm.runInNewContext(fn[0] + '; this.out = todayISO();', ctx);
  assert.equal(ctx.out, '2026-10-26');
});
