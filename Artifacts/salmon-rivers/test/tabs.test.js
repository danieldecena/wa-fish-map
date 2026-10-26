// Artifacts/salmon-rivers/test/tabs.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');

const TABS = [['week', 'Week'], ['', 'Map'], ['year', 'Year'], ['spots', 'Spots'], ['counts', 'Counts']];
/* depth 0 = index.html at the artifact root; depth 1 = a subpage folder. current = the folder key of the page ('' for Map). */
function tabsHtml(depth, current) {
  const up = depth ? '../' : '';
  return '<nav class="apptabs" aria-label="Washington Fishing Map"><div class="apptabs-track">' + TABS.map(([key, label]) => {
    const href = key === current ? 'index.html' : up + (key ? key + '/' : '') + 'index.html';
    return '<a href="' + href + '"' + (key === current ? ' aria-current="page"' : '') + '>' + label + '</a>';
  }).join('') + '</div></nav>';
}
module.exports = { tabsHtml, TABS };

const PAGES = [['index.html', 0, ''], ['week/index.html', 1, 'week'], ['year/index.html', 1, 'year'], ['spots/index.html', 1, 'spots'], ['counts/index.html', 1, 'counts']];
for (const [file, depth, current] of PAGES) {
  test('tab bar on ' + file + ' is the shared five-tab bar', () => {
    const html = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    const m = /<nav class="apptabs"[\s\S]*?<\/nav>/.exec(html);
    assert.ok(m, 'has a tab bar');
    assert.equal(m[0], tabsHtml(depth, current));
    assert.equal((html.match(/<nav class="apptabs"/g) || []).length, 1, 'exactly one tab bar');
  });
}
