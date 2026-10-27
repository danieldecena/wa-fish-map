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
