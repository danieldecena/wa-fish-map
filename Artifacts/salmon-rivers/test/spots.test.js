const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ctx = { window: {} };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'spots.js'), 'utf8'), ctx);
const SPOTS = ctx.window.SPOTS;
// The old Spots page as published, kept as the reference the guide text must match word for word.
const old = fs.readFileSync(path.join(__dirname, 'fixtures', 'spots-page.html'), 'utf8');
const page = old.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').replace(/ ([.,])/g, '$1');

test('spots: shape and ids', () => {
  assert.ok(Array.isArray(SPOTS) && SPOTS.length >= 1);
  const ids = SPOTS.map(s => s.id);
  assert.equal(new Set(ids).size, ids.length);
  SPOTS.forEach(s => {
    assert.match(s.id, /^[a-z0-9-]+$/);
    assert.match(s.updated, /^\d{4}-\d{2}-\d{2}$/);
    assert.ok(s.sources.some(x => /^https:\/\/wdfw\.wa\.gov\//.test(x.url)), s.id + ' links WDFW');
    s.timing.rows.forEach(r => assert.equal(r.cells.length, s.timing.cols.length));
  });
});

test('three friends: inside the Kent box, and the point is the one in the research note', () => {
  const s = SPOTS.find(x => x.id === 'three-friends');
  assert.ok(s.lat > 47.36 && s.lat < 47.45 && s.lon > -122.30 && s.lon < -122.20);
  const note = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'docs', 'research', '2026-10-26-three-friends-location.md'), 'utf8');
  assert.ok(note.includes(s.lat.toFixed(4) + ', ' + s.lon.toFixed(4)), 'coordinates are recorded with their source');
});

test('three friends: every line of guidance the Spots page showed is carried over verbatim', () => {
  const s = SPOTS.find(x => x.id === 'three-friends');
  const texts = [s.name, s.sub, s.intro, s.closure.title, s.closure.text, s.timing.note, s.rulesTitle]
    .concat(s.timing.cols, s.tips.map(t => t[0]), s.tips.map(t => t[1]), s.rules.map(r => r[0]), s.rules.map(r => r[1]), s.sources.map(x => x.label));
  texts.forEach(t => assert.ok(page.includes(t), 'not on the old page: ' + t));
  s.sources.forEach(x => assert.ok(old.includes('href="' + x.url + '"'), 'source link not on the old page: ' + x.url));
});
