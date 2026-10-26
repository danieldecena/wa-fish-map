// Artifacts/salmon-rivers/test/year-anchor.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const Anchor = require('../year/anchor.js');
const Week = require('../week.js');

const dir = path.join(__dirname, '..', 'year');
const FY = (() => { const w = {}; vm.runInNewContext(fs.readFileSync(path.join(dir, 'data.js'), 'utf8'), { window: w }); return w.FY; })();

function fakeDoc(ids) {
  const rows = {};
  ids.forEach(id => {
    rows['row-' + id] = { pressed: false, clicks: 0, scrolls: [],
      getAttribute(k) { return k === 'aria-pressed' ? String(this.pressed) : null; },
      click() { this.clicks++; this.pressed = true; },
      scrollIntoView(o) { this.scrolls.push(o); } };
  });
  return { rows, getElementById: id => rows[id] || null, querySelector: sel => (sel === '[id^="row-"]' && ids.length ? rows['row-' + ids[0]] : null) };
}

test('open: presses the named row once and scrolls it into view', () => {
  const doc = fakeDoc(['chum', 'skagit-coho']);
  assert.equal(Anchor.open(doc, '#skagit-coho'), 'opened');
  assert.equal(doc.rows['row-skagit-coho'].clicks, 1);
  assert.equal(doc.rows['row-chum'].clicks, 0);
  assert.deepEqual(doc.rows['row-skagit-coho'].scrolls, [{ block: 'center' }]);
});

test('open: a row that is already selected is not pressed again, but is still scrolled to', () => {
  const doc = fakeDoc(['chum']);
  doc.rows['row-chum'].pressed = true;
  assert.equal(Anchor.open(doc, '#chum'), 'opened');
  assert.equal(doc.rows['row-chum'].clicks, 0);
  assert.equal(doc.rows['row-chum'].scrolls.length, 1);
});

test('open: no hash or an empty one does nothing; a malformed escape does not throw', () => {
  const doc = fakeDoc(['chum']);
  for (const h of ['', '#', undefined, null]) assert.equal(Anchor.open(doc, h), 'none');
  assert.equal(Anchor.open(doc, '#%E0%A4%A'), 'none');
  assert.equal(doc.rows['row-chum'].clicks, 0);
});

test('open: waits while no rows are drawn, and gives up once rows exist without the target', () => {
  assert.equal(Anchor.open(fakeDoc([]), '#chum'), 'wait');
  assert.equal(Anchor.open(fakeDoc(['skagit-coho']), '#not-a-season'), 'missing');
});

test('every published season has a distinct, URL-safe id, and Week links to it unchanged', () => {
  const ids = FY.seasons.map(s => s.id);
  assert.ok(ids.length > 0);
  assert.equal(new Set(ids).size, ids.length, 'duplicate season id');
  ids.forEach(id => {
    assert.match(id, /^[a-z0-9-]+$/, `season id "${id}" needs escaping`);
    assert.equal(Week.yearHref(id), '../year/index.html#' + id);
    assert.equal(decodeURIComponent(Week.yearHref(id).split('#')[1]), id);
  });
});

test('the Year page loads anchor.js after data.js, and the page code still names rows row-<id>', () => {
  const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
  const data = html.indexOf('<script src="data.js"></script>');
  const anchor = html.indexOf('<script src="anchor.js"></script>');
  assert.ok(data > -1 && anchor > data, 'anchor.js must follow data.js');
  // anchor.js presses the button the page builds with this id; if a rebuild renames it the links silently stop working.
  assert.ok(html.includes('id:`row-${e.id}`'), 'Year bundle no longer builds row-<id> buttons');
});

test('anchor.js is listed in artifact.json so a publish carries it', () => {
  const art = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'artifact.json'), 'utf8'));
  assert.ok(art.files.includes('year/anchor.js'));
});
