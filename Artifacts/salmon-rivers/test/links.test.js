'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Links = require('../links.js');

test('read: empty search gives all nulls', () => {
  assert.deepEqual(Links.read(''), { mode: null, month: null, species: null, site: null, river: null, today: null, layers: [], spot: null, season: null, access: null });
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

test('read: month must be one or two digits; trailing junk and signs are rejected', () => {
  assert.equal(Links.read('?month=11abc').month, null);
  assert.equal(Links.read('?month=1.5').month, null);
  assert.equal(Links.read('?month=%2B3').month, null);
  assert.equal(Links.read('?month=011').month, null);
  assert.equal(Links.read('?month=11').month, 11);
  assert.equal(Links.read('?month=03').month, 3);
  assert.equal(Links.read('?month=1').month, 1);
  assert.equal(Links.read('?month=12').month, 12);
  assert.equal(Links.read('?month=13').month, null);
});

test('read: today must be a real calendar date', () => {
  for (const bad of ['2026-13-99', '2026-02-30', '2026-00-10', '2026-04-31', '2027-02-29', '2026-10-00']) assert.equal(Links.read('?today=' + bad).today, null, bad);
  for (const ok of ['2026-10-26', '2028-02-29', '2026-12-31']) assert.equal(Links.read('?today=' + ok).today, ok, ok);
});

test('toQuery: null or a non-object state is an empty query; an impossible today is not written', () => {
  assert.equal(Links.toQuery(null), '');
  assert.equal(Links.toQuery(undefined), '');
  assert.equal(Links.toQuery({ mode: 'reports', today: '2026-13-99' }), '');
  assert.equal(Links.toQuery({ mode: 'reports', today: '2026-10-26' }), '?today=2026-10-26');
});

test('layers: read and written in every mode, canonical order', () => {
  assert.deepEqual(Links.read('?layers=counts,seasons').layers, ['seasons', 'counts']);
  assert.deepEqual(Links.read('?layers=bogus').layers, []);
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['counts', 'spots'] }), '?layers=spots%2Ccounts');
  assert.equal(Links.toQuery({ mode: 'typical', layers: [] }), '?mode=typical');
});

test('spot: written only with the spots layer on', () => {
  assert.equal(Links.read('?layers=spots&spot=three-friends').spot, 'three-friends');
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['spots'], spot: 'three-friends' }), '?layers=spots&spot=three-friends');
  assert.equal(Links.toQuery({ mode: 'reports', layers: [], spot: 'three-friends' }), '');
});

test('seasons layer: month and season travel with the layer, in any mode', () => {
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['seasons'], month: 12, season: 'steelhead' }), '?layers=seasons&month=12&season=steelhead');
  assert.equal(Links.toQuery({ mode: 'typical', layers: ['seasons'], month: 3 }), '?mode=typical&layers=seasons&month=3');
  assert.equal(Links.toQuery({ mode: 'reports', layers: [], month: 12, season: 'steelhead' }), '');
  assert.equal(Links.toQuery({ mode: 'spawning', layers: ['seasons'], month: 11 }), '?mode=spawning&month=11&layers=seasons');
  assert.equal(Links.read('?layers=seasons&season=chum').season, 'chum');
});

test('access: a pier or shore sheet travels with its layer', () => {
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['access'], access: 'port-angeles-city-pier' }), '?layers=access&access=port-angeles-city-pier');
  assert.equal(Links.toQuery({ mode: 'reports', layers: [], access: 'port-angeles-city-pier' }), '');
  assert.equal(Links.read('?layers=access&access=x').access, 'x');
});
