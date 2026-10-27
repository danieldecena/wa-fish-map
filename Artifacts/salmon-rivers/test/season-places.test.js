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

test('seasons-data.js was rebuilt from seasons/seasons.json (scripts/build_fishing_year.py)', () => {
  // The build's own transform: rivers keep every field, and a stop drops site_id for that WDFW site's lat/lon.
  const src = JSON.parse(fs.readFileSync(here('seasons/seasons.json'), 'utf8'));
  const sites = new Map(JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', '..', 'site', 'data', 'sites.json'), 'utf8')).sites.map(s => [s.id, s]));
  const rivers = src.rivers.map(r => ({ ...r, stops: r.stops.map(({ site_id, ...st }) => site_id ? { ...st, lat: sites.get(site_id).lat, lon: sites.get(site_id).lon } : st) }));
  const want = { updated: src.updated, seasons: src.seasons, milestones: src.milestones, migration: src.migration, rivers };
  assert.deepEqual(JSON.parse(JSON.stringify(FY)), want, 'seasons-data.js is stale: rerun scripts/build_fishing_year.py');
});

test('every season has an entry, and no entry names an unknown season', () => {
  assert.deepEqual(Object.keys(PLACES).sort(), Array.from(FY.seasons, s => s.id).sort());
});

test('every place resolves, sits in Washington, and is backed by the season where text or a WDFW rule', () => {
  const rivers = new Set(TAP.rivers.map(r => r.id));
  const sites = new Set(Reports.SITES.map(s => s.id));
  FY.seasons.forEach(s => PLACES[s.id].forEach(p => {
    if (p.source) assert.match(p.source.url, /^https:\/\/(wdfw\.wa\.gov|lawfilesext\.leg\.wa\.gov)\//, s.id + ': a sourced place cites a WDFW rule');
    else assert.ok(p.evidence && s.where.toLowerCase().includes(p.evidence.toLowerCase()), s.id + ': evidence is not in where: ' + p.evidence);
    if (p.river) assert.ok(rivers.has(p.river) || sites.has(p.river), s.id + ': unknown river ' + p.river);
    else {
      assert.ok(Array.isArray(p.point) && p.label, s.id + ': a point needs [lon, lat] and a label');
      const [lon, lat] = p.point;
      assert.ok(lon > -124.9 && lon < -116.9 && lat > 45.5 && lat < 49.0, s.id + ': point outside Washington');
    }
  }));
});
