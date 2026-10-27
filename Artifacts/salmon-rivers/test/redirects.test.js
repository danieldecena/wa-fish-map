const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// The four pages folded into the map keep their paths, so links people saved still land on the matching layer.
const want = { week: '../?layers=seasons', year: '../?layers=seasons', spots: '../?layers=spots&spot=three-friends', counts: '../?layers=counts' };

test('each old page is only a redirect into the map', () => {
  Object.entries(want).forEach(([dir, to]) => {
    assert.deepEqual(fs.readdirSync(path.join(__dirname, '..', dir)).filter(f => !f.startsWith('.')), ['index.html'], dir + ' holds only its redirect');
    const html = fs.readFileSync(path.join(__dirname, '..', dir, 'index.html'), 'utf8');
    assert.match(html, /^<!doctype html>/i);
    assert.ok(html.includes('<a href="' + to.replace(/&/g, '&amp;') + '">'), dir + ' has a visible link');
    assert.ok(html.includes(JSON.stringify(to)), dir + ' redirects in script');
  });
});

test('the year redirect carries a season hash across as season=', () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'year', 'index.html'), 'utf8');
  assert.match(html, /location\.hash/);
  assert.match(html, /"&season=" \+ h/);
});

test('the map no longer links to the old pages or loads from their folders', () => {
  const map = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  assert.doesNotMatch(map, /(week|year|spots|counts)\/(index\.html|[a-z-]+\.js)/);
});
