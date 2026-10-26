// Artifacts/salmon-rivers/test/tides.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Tides = require('../tides.js');
const Week = require('../week.js');
const fixture = require('./fixtures/noaa-seattle.json');
const range = Week.range('2026-10-26'); // Mon Oct 26 – Sun Nov 1, matches the fixture's dates

test('stations: eleven Washington stations with the default present', () => {
  assert.equal(Tides.STATIONS.length, 11);
  assert.ok(Tides.byId(Tides.DEFAULT));
  assert.equal(Tides.byId('nope'), null);
  Tides.STATIONS.forEach(s => { assert.match(s.id, /^\d{7}$/); assert.ok(s.lat > 45 && s.lat < 49.1 && s.lon < -122 && s.lon > -125.5, s.name); });
});

test('nearest: Ballard -> Seattle, Grays Harbor -> Westport', () => {
  assert.equal(Tides.nearest(47.668, -122.386).id, '9447130');
  assert.equal(Tides.nearest(46.93, -124.05).id, '9441102');
});

test('url: documented CO-OPS query for the week', () => {
  const u = Tides.url(Tides.byId('9447130'), range);
  assert.ok(u.startsWith('https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?'));
  for (const kv of ['product=predictions', 'datum=MLLW', 'interval=hilo', 'units=english', 'time_zone=lst_ldt', 'format=json', 'station=9447130', 'begin_date=20261026', 'end_date=20261101']) assert.ok(u.includes(kv), kv);
});

test('parse: one entry per day of the range, extremes in NOAA order, heights as numbers, outside days dropped', () => {
  const days = Tides.parse(fixture, range);
  assert.deepEqual(days.map(d => d.date), range.days);
  assert.ok(days[0].extremes.length >= 2);
  assert.equal(typeof days[0].extremes[0].v, 'number');
  assert.match(days[0].extremes[0].t, /^\d{2}:\d{2}$/);
  assert.ok(['H', 'L'].includes(days[0].extremes[0].type));
  const total = days.reduce((n, d) => n + d.extremes.length, 0);
  const inRange = fixture.predictions.filter(p => p.t.slice(0, 10) >= range.start && p.t.slice(0, 10) <= range.end).length;
  assert.equal(total, inRange);
  const shifted = Tides.parse(fixture, Week.range('2026-11-02'));
  assert.equal(shifted.reduce((n, d) => n + d.extremes.length, 0), fixture.predictions.filter(p => p.t.slice(0, 10) >= '2026-11-02').length);
});

test('load: resolves parsed days; rejects on HTTP error, bad JSON and a NOAA error object', async () => {
  const ok = () => Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) });
  assert.equal((await Tides.load(Tides.byId('9447130'), range, ok)).length, 7);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: false, status: 503, json: () => Promise.resolve({}) })), /503/);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: true, json: () => Promise.reject(new Error('bad json')) })), /bad json/);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: true, json: () => Promise.resolve({ error: { message: 'No data was found' } }) })), /No data was found/);
});

test('fmtTime', () => {
  assert.equal(Tides.fmtTime('03:12'), '3:12 am'); assert.equal(Tides.fmtTime('13:40'), '1:40 pm');
  assert.equal(Tides.fmtTime('00:05'), '12:05 am'); assert.equal(Tides.fmtTime('12:00'), '12:00 pm');
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
const days0 = Tides.parse(fixture, range);

test('nextIndex: the first extreme after now, only one, none when the week is over', () => {
  const first = days0[0].extremes[0], second = days0[0].extremes[1];
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 00:00'), { day: 0, i: 0 });
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 ' + first.t), { day: 0, i: 1 });
  assert.equal(Tides.nextIndex(days0, '2026-11-02 00:00'), null);
  assert.ok(second);
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

test('render: a day without extremes shows a dash', () => {
  const t = Tides.render([{ date: '2026-10-26', extremes: [] }], '2026-10-26 00:00', fakeDoc());
  assert.equal(t.querySelectorAll('td')[0].textContent, '—');
});

test('mount: section inserted after the given one, default station, stored and nearest choice, failure row', async () => {
  const doc = fakeDoc();
  const root = doc.createElement('div'), a = doc.createElement('section'), b = doc.createElement('section');
  a.id = 'reported'; b.id = 'rules'; root.appendChild(a); root.appendChild(b);
  const store = {};
  const storage = { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); } };
  const calls = [];
  const fetchOk = u => { calls.push(u); return Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) }); };
  await Tides.mount(root, a, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.equal(root.children[1].id, 'tides');
  assert.ok(calls[0].includes('station=9447130'));
  assert.equal(root.children[1].querySelector('select').value, '9447130');
  assert.equal(root.children[1].querySelectorAll('tr').length, 7);
  // a stored choice wins over the default
  store[Tides.STORE_KEY] = '9446484';
  const root2 = doc.createElement('div'), a2 = doc.createElement('section'); root2.appendChild(a2);
  await Tides.mount(root2, a2, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.ok(calls[1].includes('station=9446484'));
  // an unknown stored id falls back; a stored "me" point picks the nearest
  store[Tides.STORE_KEY] = 'bogus'; store[Tides.ME_KEY] = JSON.stringify({ lat: 46.93, lon: -124.05, label: 'x' });
  const root3 = doc.createElement('div'), a3 = doc.createElement('section'); root3.appendChild(a3);
  await Tides.mount(root3, a3, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.ok(calls[2].includes('station=9441102'));
  // failure shows the unavailable row with a NOAA link
  const root4 = doc.createElement('div'), a4 = doc.createElement('section'); root4.appendChild(a4);
  await Tides.mount(root4, a4, range, '2026-10-26', doc, { fetch: () => Promise.reject(new Error('blocked')), storage, now: '2026-10-26 00:00' });
  assert.ok(root4.children[1].textContent.includes('Tide predictions unavailable right now'));
  assert.ok(root4.children[1].querySelectorAll('a').some(x => x.attrs.href.includes('tidesandcurrents.noaa.gov')));
  // changing the picker fetches again and stores the choice
  const sel = root.children[1].querySelector('select'); sel.value = '9444900'; sel.fire('change');
  await new Promise(r => setTimeout(r, 0));
  assert.ok(calls[calls.length - 1].includes('station=9444900'));
  assert.equal(store[Tides.STORE_KEY], '9444900');
});

function mkRoot(doc) { const root = doc.createElement('div'), a = doc.createElement('section'); root.appendChild(a); return { root, a }; }
const oneJson = { predictions: [{ t: '2026-10-26 03:33', v: '1.0', type: 'H' }] };

test('mount: a stale response from an earlier picker choice is dropped', async () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc), pend = [];
  const fetchDef = () => new Promise(res => pend.push(res));
  const storage = { getItem: () => null, setItem: () => {} };
  const p0 = Tides.mount(root, a, range, '2026-10-26', doc, { fetch: fetchDef, storage, now: '2026-10-26 00:00' });
  const sel = root.children[1].querySelector('select'); sel.value = '9446484'; sel.fire('change');
  const ok = j => ({ ok: true, json: () => Promise.resolve(j) });
  pend[1](ok(oneJson)); await new Promise(r => setTimeout(r, 0));
  pend[0](ok(fixture)); await p0; await new Promise(r => setTimeout(r, 0));
  const sec = root.children[1];
  assert.equal(sec.querySelector('.cap').textContent, 'Tides · Tacoma');
  assert.equal(sec.querySelectorAll('.ex').length, 1);
});

test('mount: a throwing localStorage getter does not stop the section mounting', async () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc), calls = [];
  Object.defineProperty(globalThis, 'localStorage', { get() { throw new Error('SecurityError'); }, configurable: true });
  try {
    await Tides.mount(root, a, range, '2026-10-26', doc, { fetch: u => { calls.push(u); return Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) }); }, now: '2026-10-26 00:00' });
  } finally { delete globalThis.localStorage; }
  assert.equal(root.children[1].id, 'tides');
  assert.ok(calls[0].includes('station=9447130'));
});

test('mount: a pinned today inside the week marks that row and its first extreme is next', async () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  // No opts.now: stub the clock far from the fixture week so the pinned `today` (not the real date) must drive the result.
  const RealDate = globalThis.Date, FIXED = new RealDate('2030-01-01T12:00:00').getTime();
  globalThis.Date = class extends RealDate { constructor(...args) { if (args.length) super(...args); else super(FIXED); } static now() { return FIXED; } };
  try {
    await Tides.mount(root, a, range, '2026-10-28', doc, { fetch: () => Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) }), storage: null });
  } finally { globalThis.Date = RealDate; }
  const t = root.children[1];
  const today = t.querySelectorAll('tr').filter(r => r.className === 'today');
  assert.equal(today.length, 1);
  assert.match(today[0].querySelector('th').textContent, /^Wed Oct 28/);
  const nx = t.querySelectorAll('.next');
  assert.equal(nx.length, 1);
  assert.equal(nx[0].textContent, today[0].querySelectorAll('.ex')[0].textContent);
});

test('mount: a fetch that never answers falls to the unavailable row after opts.timeoutMs', async () => {
  const doc = fakeDoc(), { root, a } = mkRoot(doc);
  await Tides.mount(root, a, range, '2026-10-26', doc, { fetch: () => new Promise(() => {}), storage: null, now: '2026-10-26 00:00', timeoutMs: 20 });
  assert.ok(root.children[1].textContent.includes('Tide predictions unavailable right now'));
});
