const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const QUERY = '(min-width: 1024px) and (hover: hover) and (pointer: fine)';
const block = (() => {
  const i = html.indexOf('@media ' + QUERY + ' {');
  assert.ok(i > 0, 'control: the one-bar media block exists');
  return html.slice(i, html.indexOf('\n}\n', i));
})();

test('one bar: the CSS query and the script constant are the same string', () => {
  assert.equal(html.split(QUERY).length - 1, 2, 'the CSS block and the ONE_BAR constant each carry it once');
  assert.match(html, new RegExp("var ONE_BAR = '" + QUERY.replace(/[()]/g, '\\$&') + "';"));
  assert.match(html, /phoneMq = window\.matchMedia\('\(max-width: 520px\), ' \+ ONE_BAR\)/);
});

test('one bar: a mouse on a wide window gets a single 44px row with 36px controls', () => {
  assert.match(block, /:root \{ --tabs-h: 0px; \}/);
  assert.match(block, /\.bar \{ height: 44px; padding: 4px 8px; \}/);
  assert.match(block, /\.bar \.listbtn, \.bar \.nbtn, \.bar \.seg button \{ min-height: 36px; \}/);
  assert.match(block, /#bar \.apptabs-track \{[^}]*height: 36px;/);
  assert.match(block, /#bar nav\.apptabs \{ position: static;/);
  assert.match(block, /#sheet \{ top: 68px; \}/);
  assert.match(block, /\.modebtn \{ display: inline-flex; \}/);
});

test('one bar: the 44px touch targets outside it are untouched', () => {
  const outside = html.replace(block, '');
  assert.match(outside, /\.listbtn \{[^}]*min-height: 44px;/);
  assert.match(outside, /\.nbtn \{[^}]*min-height: 44px;/);
  assert.match(outside, /\.bar \{[^}]*height: 56px; padding: 6px 8px;/);
  assert.match(outside, /\.apptabs a\{[^}]*height:44px;/);
});

test('one bar: the script moves the same nav into the bar before the mode button, and back', () => {
  assert.match(html, /\$\('#bar'\)\.insertBefore\(tabsEl, \$\('#modebtn'\)\)/);
  assert.match(html, /tabsHome\.parent\.insertBefore\(tabsEl, tabsHome\.next\)/);
  assert.equal((html.match(/<nav class="apptabs"/g) || []).length, 1, 'still exactly one tab bar in the source');
});
