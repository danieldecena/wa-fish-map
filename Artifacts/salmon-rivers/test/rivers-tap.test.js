const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dir = path.join(__dirname, '..');
const ctx = { window: {} };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(dir, 'rivers-tap.js'), 'utf8'), ctx);
const TAP = ctx.window.RIVERTAP;
const SITES = new Map(require('../typical.js').sites.map(s => [s.id, s]));
const BY = new Map(TAP.rivers.map(r => [r.id, r]));

test('siteRiver: every key is a typical site, every value a gauged river', () => {
  const pairs = Object.entries(TAP.siteRiver);
  assert.ok(pairs.length >= 50, 'only ' + pairs.length + ' sites linked');
  pairs.forEach(([site, river]) => {
    assert.ok(SITES.has(site), site + ' is not in typical.js');
    assert.ok(BY.get(river) && BY.get(river).flow, river + ' has no gauge');
  });
});

test('siteRiver: known launches get their river, saltwater sites never do', () => {
  assert.equal(TAP.siteRiver['sedro-woolley'], 'skagit-river');
  // The gauged Green is the Kent-Auburn one, not the unrelated eastern Green River.
  assert.equal(TAP.siteRiver['soos-creek-drift'], 'green-river-2');
  assert.equal(BY.get('green-river-2').name, 'Green River');
  Object.keys(TAP.siteRiver).forEach(id => assert.equal(SITES.get(id).area, null, id + ' is in a marine area'));
});

test('page: a site sheet shows the gauge link only through siteRiver', () => {
  const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
  assert.match(html, /tidesHtml\(site, t\) \+ siteFlowHtml\(id\)/);
  assert.match(html, /TAP\.siteRiver \? TAPBY\[TAP\.siteRiver\[id\]\]/);
});
