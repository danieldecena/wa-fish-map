const test = require('node:test');
const assert = require('node:assert/strict');
const Layers = require('../layers.js');
const Links = require('../links.js');

test('parse: known names only, canonical order, no duplicates', () => {
  assert.deepEqual(Layers.parse('counts,seasons,counts,bogus'), ['seasons', 'counts']);
  assert.deepEqual(Layers.parse(''), []);
  assert.deepEqual(Layers.parse(null), []);
});

test('toggle: adds and removes, keeps canonical order', () => {
  assert.deepEqual(Layers.toggle(['counts'], 'seasons'), ['seasons', 'counts']);
  assert.deepEqual(Layers.toggle(['seasons', 'counts'], 'seasons'), ['counts']);
  assert.deepEqual(Layers.toggle([], 'bogus'), []);
});

test('links.js carries the same layer names, so the URL and the menu cannot drift', () => {
  assert.deepEqual(Links.LAYERS, Layers.NAMES);
});

test('keptText: combined rows when present, else every row; null counts are not zeros', () => {
  const row = (section, kept) => ({ section, species: 'Coho Salmon', anglers: 1, kept, released: null });
  assert.equal(Layers.keptText({ rows: [row('All sections combined', 124), row('All sections combined', 9), row('Below Br', 50)], noCatch: null }), '133 kept');
  assert.equal(Layers.keptText({ rows: [row('Above Br', null), row('Below Br', 7), row('Below Br', 3)], noCatch: null }), '10 kept');
  assert.equal(Layers.keptText({ rows: [], noCatch: { anglers: 8 } }), '0 kept');
  assert.equal(Layers.keptText({ rows: [row(null, null)], noCatch: null }), 'Kept not reported');
  assert.equal(Layers.keptText(null), null);
});

test('keptText: every water in counts.js gets a badge text', () => {
  const C = require('../counts.js');
  Object.keys(C.WATERS).forEach(id => assert.match(Layers.keptText(C.forWater(id)), /^(\d+ kept|Kept not reported)$/, id));
  assert.equal(Layers.keptText(C.forWater('columbia')), '133 kept');
});

test('openIn: any overlap with the calendar month, across year ends', () => {
  const s = (start, end) => ({ start, end });
  assert.equal(Layers.openIn(s('2026-10-01', '2026-10-31'), 2026, 10), true);
  assert.equal(Layers.openIn(s('2026-10-16', '2026-11-30'), 2026, 11), true);
  assert.equal(Layers.openIn(s('2026-12-01', '2027-03-31'), 2027, 1), true);
  assert.equal(Layers.openIn(s('2026-12-01', '2027-03-31'), 2026, 11), false);
  assert.equal(Layers.openIn(s('2026-10-01', '2026-10-31'), 2027, 10), false);
  assert.equal(Layers.openIn(s('2027-02-28', '2027-02-28'), 2027, 2), true);
});

test('tagFor: ends within 7 days, opens within 14, else none', () => {
  const s = (start, end) => ({ start, end });
  assert.deepEqual(Layers.tagFor(s('2026-10-01', '2026-10-31'), '2026-10-26'), { kind: 'ends', days: 5, text: 'ends Oct 31' });
  assert.deepEqual(Layers.tagFor(s('2026-11-05', '2026-11-30'), '2026-10-26'), { kind: 'opens', days: 10, text: 'opens Nov 5' });
  assert.equal(Layers.tagFor(s('2026-10-01', '2026-11-30'), '2026-10-26'), null);
  assert.equal(Layers.tagFor(s('2026-12-01', '2027-03-31'), '2026-10-26'), null);
  assert.deepEqual(Layers.tagFor(s('2026-10-01', '2026-10-26'), '2026-10-26'), { kind: 'ends', days: 0, text: 'ends today' });
});

test('monthLabel', () => assert.equal(Layers.monthLabel(2026, 10), 'October 2026'));
