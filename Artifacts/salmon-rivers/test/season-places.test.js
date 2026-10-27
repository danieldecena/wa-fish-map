const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const here = p => path.join(__dirname, '..', p);
const ctx = { window: {} };
vm.createContext(ctx);
['seasons-data.js', 'rivers-tap.js', 'season-places.js'].forEach(f => vm.runInContext(fs.readFileSync(here(f), 'utf8'), ctx));
const FY = ctx.window.FY, TAP = ctx.window.RIVERTAP, PLACES = ctx.window.SEASON_PLACES;
const Reports = require('../reports.js');

test('seasons-data.js is a byte copy of the Fishing Year data it is generated as', () => {
  assert.equal(fs.readFileSync(here('seasons-data.js'), 'utf8'), fs.readFileSync(path.join(__dirname, '..', '..', 'fishing-year', 'data.js'), 'utf8'));
});

test('every season has an entry, and no entry names an unknown season', () => {
  assert.deepEqual(Object.keys(PLACES).sort(), Array.from(FY.seasons, s => s.id).sort());
});

test('every place resolves, sits in Washington, and its evidence is a phrase of the season where text', () => {
  const rivers = new Set(TAP.rivers.map(r => r.id));
  const sites = new Set(Reports.SITES.map(s => s.id));
  FY.seasons.forEach(s => PLACES[s.id].forEach(p => {
    assert.ok(p.evidence && s.where.toLowerCase().includes(p.evidence.toLowerCase()), s.id + ': evidence is not in where: ' + p.evidence);
    if (p.river) assert.ok(rivers.has(p.river) || sites.has(p.river), s.id + ': unknown river ' + p.river);
    else {
      assert.ok(Array.isArray(p.point) && p.label, s.id + ': a point needs [lon, lat] and a label');
      const [lon, lat] = p.point;
      assert.ok(lon > -124.9 && lon < -116.9 && lat > 45.5 && lat < 49.0, s.id + ': point outside Washington');
    }
  }));
});
