// Artifacts/salmon-rivers/test/tides.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const Tides = require('../tides.js');
const Week = require('../week.js');
const range = Week.range('2026-10-26'); // Mon Oct 26 – Sun Nov 1

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

test('nextIndex: the first extreme after now, only one, none when the week is over', () => {
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 00:00'), { day: 0, i: 0 });
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 06:00'), { day: 0, i: 1 });
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 23:45'), { day: 1, i: 0 });
  assert.equal(Tides.nextIndex(days0, '2026-11-02 00:00'), null);
});

test('render: seven rows, today marked, exactly one next extreme, am/pm times and feet', () => {
  const t = Tides.render(days0, '2026-10-27 00:00', fakeDoc());
  const rows = t.querySelectorAll('tr');
  assert.equal(rows.length, 7);
  assert.equal(rows.filter(r => r.className.includes('today')).length, 1);
  assert.equal(rows[1].className, 'today');
  assert.equal(t.querySelectorAll('.next').length, 1);
  assert.match(t.querySelectorAll('.ex')[0].textContent, /^[HL] \d{1,2}:\d{2} [ap]m · -?\d+\.\d ft$/);
});

test('render: a day without extremes shows a dash; a beyond-bundle day shows its note and no extremes', () => {
  const t = Tides.render([{ date: '2026-10-26', extremes: [] }], '2026-10-26 00:00', fakeDoc());
  assert.equal(t.querySelectorAll('td')[0].textContent, '—');
  const ds = Tides.days(Tides.byId('9447130'), range, mkBundle('2026-10-26', '2026-10-28'));
  const t2 = Tides.render(ds, '2026-10-26 00:00', fakeDoc());
  const tds = t2.querySelectorAll('td');
  assert.equal(tds[3].textContent, 'Beyond the bundled predictions (through Oct 28)');
  assert.equal(tds[3].querySelectorAll('.ex').length, 0);
  assert.equal(t2.querySelectorAll('.next').length, 1);
});

function mkRoot(doc) { const root = doc.createElement('div'), a = doc.createElement('section'); root.appendChild(a); return { root, a }; }
const NOW = '2026-10-26 00:00';
const noStore = { getItem: () => null, setItem: () => {} };

test('mount: synchronous; section after the given one, default station, footnote, seven filled rows', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  const sec = Tides.mount(root, a, range, '2026-10-26', doc, { bundle, storage: noStore, now: NOW });
  assert.equal(root.children[1], sec);
  assert.equal(sec.id, 'tides');
  assert.equal(sec.querySelector('select').value, '9447130');
  assert.equal(sec.querySelector('.cap').textContent, 'Tides');
  assert.equal(sec.querySelectorAll('select')[0].children.length, 3);
  assert.equal(sec.querySelectorAll('tr').length, 7);
  assert.ok(sec.querySelectorAll('tr').every(r => r.querySelector('.ex')));
  assert.equal(sec.querySelectorAll('.fine')[0].textContent, 'NOAA predictions through Nov 30, MLLW, local time. Not observations.');
});

test('mount: stored choice wins; an unknown stored id falls back to the nearest saved point; picker stores and re-renders', () => {
  const doc = fakeDoc(), store = {};
  const storage = { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); } };
  store[Tides.STORE_KEY] = '9446484';
  let m = mkRoot(doc);
  let sec = Tides.mount(m.root, m.a, range, '2026-10-26', doc, { bundle, storage, now: NOW });
  assert.equal(sec.querySelector('select').value, '9446484');
  assert.equal(sec.querySelector('.cap').textContent, 'Tides');
  store[Tides.STORE_KEY] = 'bogus'; store[Tides.ME_KEY] = JSON.stringify({ lat: 46.93, lon: -124.05, label: 'x' });
  m = mkRoot(doc);
  sec = Tides.mount(m.root, m.a, range, '2026-10-26', doc, { bundle, storage, now: NOW });
  assert.equal(sec.querySelector('select').value, '9441102');
  // a station the bundle does not have is not picked even if stored
  store[Tides.STORE_KEY] = '9444900'; delete store[Tides.ME_KEY];
  m = mkRoot(doc);
  sec = Tides.mount(m.root, m.a, range, '2026-10-26', doc, { bundle, storage, now: NOW });
  assert.equal(sec.querySelector('select').value, '9447130');
  // changing the picker redraws synchronously and stores the choice
  const sel = sec.querySelector('select'); sel.value = '9441102'; sel.fire('change');
  assert.equal(sec.querySelector('.cap').textContent, 'Tides');
  assert.equal(store[Tides.STORE_KEY], '9441102');
  assert.equal(sec.querySelectorAll('tr').length, 7);
  assert.equal(sec.querySelectorAll('.ex')[0].textContent, 'H 6:00 am · 13.5 ft');
});

test('mount: no bundle shows the unavailable row with a NOAA link and the fallback stations', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  const sec = Tides.mount(root, a, range, '2026-10-26', doc, { bundle: undefined, storage: noStore, now: NOW });
  assert.ok(sec.textContent.includes('Tide predictions unavailable right now'));
  assert.ok(sec.querySelectorAll('a').some(x => x.attrs.href.includes('tidesandcurrents.noaa.gov') && x.textContent === 'See NOAA for Seattle'));
  assert.equal(sec.querySelectorAll('tr').length, 0);
  assert.equal(sec.querySelector('select').children.length, 11);
});

test('mount: a bundle without predictions for the chosen station also shows the unavailable row', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  const b = mkBundle('2026-10-26', '2026-11-30'); delete b.predictions['9447130'];
  const sec = Tides.mount(root, a, range, '2026-10-26', doc, { bundle: b, storage: noStore, now: NOW });
  assert.ok(sec.textContent.includes('Tide predictions unavailable right now'));
});

test('mount: window.TIDES (globalThis) is used when no bundle is passed', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  globalThis.TIDES = bundle;
  try { Tides.mount(root, a, range, '2026-10-26', doc, { storage: noStore, now: NOW }); } finally { delete globalThis.TIDES; }
  assert.equal(root.children[1].querySelectorAll('tr').length, 7);
});

test('mount: a throwing localStorage getter does not stop the section mounting', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  Object.defineProperty(globalThis, 'localStorage', { get() { throw new Error('SecurityError'); }, configurable: true });
  try { Tides.mount(root, a, range, '2026-10-26', doc, { bundle, now: NOW }); } finally { delete globalThis.localStorage; }
  assert.equal(root.children[1].id, 'tides');
  assert.equal(root.children[1].querySelector('select').value, '9447130');
});

test('mount: a pinned today inside the week marks that row and its first extreme is next', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  // No opts.now: stub the clock far from the week so the pinned `today` (not the real date) must drive the result.
  const RealDate = globalThis.Date, FIXED = new RealDate('2030-01-01T12:00:00').getTime();
  globalThis.Date = class extends RealDate { constructor(...args) { if (args.length) super(...args); else super(FIXED); } static now() { return FIXED; } };
  try { Tides.mount(root, a, range, '2026-10-28', doc, { bundle, storage: null }); } finally { globalThis.Date = RealDate; }
  const t = root.children[1];
  const today = t.querySelectorAll('tr').filter(r => r.className === 'today');
  assert.equal(today.length, 1);
  assert.match(today[0].querySelector('th').textContent, /^Wed Oct 28/);
  const nx = t.querySelectorAll('.next');
  assert.equal(nx.length, 1);
  assert.equal(nx[0].textContent, today[0].querySelectorAll('.ex')[0].textContent);
});

test('mount: a week past the bundle end shows beyond rows (no extremes) and the footnote still names the end', () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  const r2 = Week.range('2026-12-09');
  const sec = Tides.mount(root, a, r2, '2026-12-09', doc, { bundle, storage: noStore });
  const tds = sec.querySelectorAll('td');
  assert.equal(tds.length, 7);
  assert.ok(tds.every(td => td.textContent === 'Beyond the bundled predictions (through Nov 30)'));
  assert.equal(sec.querySelectorAll('.ex').length, 0);
  assert.ok(sec.querySelectorAll('.fine')[0].textContent.includes('through Nov 30'));
});

/* The no-network rule: the page makes no requests at all. */
test('no network: tides.js, week.js, index.html and week/index.html contain no fetch( or XMLHttpRequest', () => {
  for (const f of ['tides.js', 'week.js', 'index.html', 'week/index.html']) {
    const src = fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
    assert.ok(!/\bfetch\s*\(/.test(src), f + ' calls fetch(');
    assert.ok(!/XMLHttpRequest/.test(src), f + ' uses XMLHttpRequest');
    assert.ok(!/AbortController|sendBeacon|new WebSocket|new EventSource/.test(src), f + ' uses a network API');
  }
});

/* The bundle itself (written by scripts/build_tides.py). */
test('tides-data.js: parses, covers at least 30 days, every station has every day, ids are 7-digit WA stations', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'week', 'tides-data.js'), 'utf8');
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

test('mount: a stored "You" point with null, string or missing coordinates is ignored (default station), a numeric one is used', () => {
  const doc = fakeDoc();
  const pick = me => {
    const store = { [Tides.ME_KEY]: JSON.stringify(me) };
    const storage = { getItem: k => (k in store ? store[k] : null), setItem: () => {} };
    const m = mkRoot(doc);
    return Tides.mount(m.root, m.a, range, '2026-10-26', doc, { bundle, storage, now: NOW }).querySelector('select').value;
  };
  assert.equal(pick({ lat: null, lon: null }), '9447130', 'null/null would be nearest(0,0)');
  assert.equal(pick({ lat: '46.93', lon: '-124.05' }), '9447130');
  assert.equal(pick({ lat: 46.93 }), '9447130');
  assert.equal(pick({ lat: 46.93, lon: -124.05 }), '9441102');
});

test('mount: the heading is just "Tides"; the station is named by the picker', () => {
  const doc = fakeDoc(), m = mkRoot(doc);
  const sec = Tides.mount(m.root, m.a, range, '2026-10-26', doc, { bundle, storage: noStore, now: NOW });
  assert.equal(sec.querySelector('.cap').textContent, 'Tides');
  assert.ok(!/Seattle/.test(sec.querySelector('.cap').textContent));
});

test('render: notes and dashes are marked .none so the desktop grid does not squeeze them into one column', () => {
  const cells = Tides.render([{ date: '2026-10-26', extremes: [], note: 'Beyond the bundled predictions (through Nov 30)' }, { date: '2026-10-27', extremes: [] }, { date: '2026-10-28', extremes: [{ t: '06:00', type: 'H', v: 1 }] }], '2026-10-26 00:00', fakeDoc()).querySelectorAll('td');
  assert.deepEqual(cells.map(c => c.className), ['none', 'none', '']);
});
