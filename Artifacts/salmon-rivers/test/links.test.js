'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Links = require('../links.js');

test('read: empty search gives all nulls', () => {
  assert.deepEqual(Links.read(''), { mode: null, month: null, species: null, site: null, river: null, today: null });
});

test('read: every key round-trips', () => {
  const r = Links.read('?mode=spawning&month=11&species=Coho%20Salmon&site=enchantment&today=2026-10-26');
  assert.equal(r.mode, 'spawning');
  assert.equal(r.month, 11);
  assert.equal(r.species, 'Coho Salmon');
  assert.equal(r.site, 'enchantment');
  assert.equal(r.today, '2026-10-26');
});

test('read: unknown mode, bad month and bad today read as null', () => {
  const r = Links.read('?mode=heat&month=13&today=yesterday');
  assert.equal(r.mode, null);
  assert.equal(r.month, null);
  assert.equal(r.today, null);
  assert.equal(Links.read('?month=0').month, null);
  assert.equal(Links.read('?month=abc').month, null);
});

test('toQuery: defaults are omitted', () => {
  assert.equal(Links.toQuery({ mode: 'reports' }), '');
  assert.equal(Links.toQuery({ mode: null, species: null }), '');
});

test('toQuery: only keys that apply to the mode are written', () => {
  assert.equal(Links.toQuery({ mode: 'reports', river: 'cowlitz', site: 'x', month: 5 }), '?river=cowlitz');
  assert.equal(Links.toQuery({ mode: 'spawning', month: 11, site: 'enchantment', river: 'cowlitz' }), '?mode=spawning&month=11&site=enchantment');
  assert.equal(Links.toQuery({ mode: 'typical', month: 11, site: 'abc', species: 'Coho Salmon' }), '?mode=typical&species=Coho+Salmon&site=abc');
});

test('toQuery: today is carried when present and never invented', () => {
  assert.equal(Links.toQuery({ mode: 'reports', today: '2026-10-26' }), '?today=2026-10-26');
  assert.equal(Links.toQuery({ mode: 'reports' }).indexOf('today'), -1);
});

test('write: replaceState with pathname + query + hash, and no call when unchanged', () => {
  const calls = [];
  const history = { replaceState: (a, b, url) => calls.push(url) };
  const location = { pathname: '/artifact/x/index.html', search: '', hash: '#top' };
  Links.write({ mode: 'spawning', month: 3 }, history, location);
  assert.deepEqual(calls, ['/artifact/x/index.html?mode=spawning&month=3#top']);
  location.search = '?mode=spawning&month=3';
  Links.write({ mode: 'spawning', month: 3 }, history, location);
  assert.equal(calls.length, 1);
});
