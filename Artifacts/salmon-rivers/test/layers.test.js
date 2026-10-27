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
