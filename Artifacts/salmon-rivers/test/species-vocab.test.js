const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const R = require('../reports.js');

const repo = path.join(__dirname, '..', '..', '..');
const fisheries = JSON.parse(fs.readFileSync(path.join(repo, 'WAFishMap/Resources/fisheries.json'), 'utf8'));

// Every species string the app can show: marine areas, statewide freshwater,
// county overrides and per-waterbody rows.
function appSpeciesNames(f) {
  const names = new Set();
  f.areas.forEach(a => a.species.forEach(s => names.add(s.species)));
  f.freshwater.species.forEach(s => names.add(s.species));
  Object.values(f.freshwater.byCounty).forEach(rows => rows.forEach(s => names.add(s.species)));
  Object.values(f.freshwater.byWaterbody).forEach(rows => rows.forEach(s => names.add(s.species)));
  return names;
}
const APP = appSpeciesNames(fisheries);

test('control: the extractor really read the app vocabulary', () => {
  // If a key were misspelled the set would be empty and every membership test below would be meaningless.
  assert.ok(APP.size >= 25, `only ${APP.size} names`);
  for (const n of ['Coho Salmon', 'Chinook Salmon', 'Chinook Salmon (ocean)', 'Walleye', 'Rainbow Trout', 'Yellow Perch']) {
    assert.ok(APP.has(n), `missing ${n}`);
  }
});

test('matching is exact: near-misses are not app species', () => {
  for (const n of ['Coho', 'coho salmon', 'Chinook', 'Chinook Salmon ', 'Salmon']) {
    assert.ok(!APP.has(n), `"${n}" should not match`);
  }
});

test('every species the page can show is an exact app species name', () => {
  assert.ok(Array.isArray(R.SPECIES) && R.SPECIES.length >= 2);
  for (const n of R.SPECIES) assert.ok(APP.has(n), `"${n}" is not an exact species name in fisheries.json`);
  assert.equal(new Set(R.SPECIES).size, R.SPECIES.length, 'duplicate species');
});

test('the page never carries the app seasonal-timing data', () => {
  const dir = path.join(__dirname, '..');
  for (const f of ['reports.js', 'index.html']) {
    const text = fs.readFileSync(path.join(dir, f), 'utf8');
    assert.doesNotMatch(text, /bestMonths|goodMonths|fisheries\.json/, `${f} references seasonal timing`);
  }
});
