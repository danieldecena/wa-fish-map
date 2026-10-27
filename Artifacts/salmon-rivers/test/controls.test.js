const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const between = (a, b) => { const i = html.indexOf(a), j = html.indexOf(b, i); assert.ok(i >= 0 && j > i, `${a} .. ${b}`); return html.slice(i, j); };

test('one species dropdown serves both modes, and the old chip row is gone', () => {
  assert.equal((html.match(/id="spbtn"/g) || []).length, 1);
  assert.match(html, /<button type="button" class="listbtn" id="spbtn" aria-expanded="false" aria-controls="sppanel"><\/button>/);
  assert.match(html, /id="sppanel" role="radiogroup" aria-label="Species" hidden/);
  assert.doesNotMatch(html, /id="spseg"|spseg/, 'the Recent reports chip row must not come back');
  const build = between('function buildSpecies', "document.querySelectorAll('#modes button')");
  assert.match(build, /setSpLabel\(\);/, 'one button label for both modes');
  // The thin bar shows a funnel icon plus the species name (hidden on phones); the accessible name always says which species.
  const label = between('function setSpLabel', 'function mkChip');
  assert.match(label, /var t = species \|\| 'All species';/);
  assert.match(label, /spbtn\.setAttribute\('aria-label', 'Species: ' \+ t\);/);
  // Recent reports fills the same panel with exact names from Reports.SPECIES; nothing else decides its species.
  assert.match(build, /Reports\.SPECIES\.forEach\(function \(name\) \{ mkChip\(name, top\); \}\);/);
  assert.match(build, /mkChip\(null, top\);/);
});

test('Rivers sits in the one-row bar, and the (visually hidden) title names the mode', () => {
  const bar = between('<div class="glass bar" id="bar"', '<div class="glass pop mpop"');
  assert.match(bar, /id="listbtn"[^>]*>Rivers<\/button>/);
  assert.match(bar, /<div class="sr"><div class="title" id="ttl">Salmon this month</, 'Recent reports is the default mode; the title stays for screen readers');
  assert.match(html, /\$\('#ttl'\)\.textContent = typ \? 'Typical season' : 'Salmon this month';/);
  assert.match(html, /\$\('#listbtn'\)\.hidden = view !== 'reports';/, 'Rivers belongs to Recent reports only');
});

test('controls keep 44 px targets, and the dropdown handles keyboard and focus', () => {
  assert.match(html, /\.seg button \{[^}]*min-height: 44px;/);
  assert.match(html, /\.listbtn \{[^}]*min-height: 44px;/);
  assert.match(html, /\.modes button \{ flex: 1 1 auto; \}/);
  // Selecting closes the panel in both modes; closing hands focus back to the button; Escape closes the panel before it closes a sheet.
  assert.match(html, /species = name;[\s\S]{0,400}toggleSpecies\(false\);/);
  assert.match(html, /if \(!open && sppanel\.contains\(document\.activeElement\)\) spbtn\.focus/);
  assert.match(html, /if \(!sppanel\.hidden\) \{ toggleSpecies\(false\); spbtn\.focus\(\{ preventScroll: true \}\); return; \}\s*if \(mode\) closeSheet\(\);/);
  const toggle = between('function toggleSpecies', "spbtn.addEventListener('click'");
  assert.match(toggle, /aria-expanded/);
  assert.match(html, /b\.setAttribute\('role', 'radio'\);/);
  assert.match(html, /b\.setAttribute\('aria-checked', name === species \? 'true' : 'false'\);/);
});

test('no page tab bar; a Layers button and menu in the map bar', () => {
  assert.doesNotMatch(html, /class="apptabs"|--tabs-h|ONE_BAR|placeTabs|tabsBottom/);
  assert.match(html, /<button type="button" class="listbtn" id="laybtn" aria-expanded="false" aria-controls="laypop">/);
  assert.match(html, /id="laypop" role="group" aria-label="Map layers" hidden/);
  ['seasons', 'spots', 'access', 'counts'].forEach(n => assert.match(html, new RegExp('role="switch" aria-checked="false" data-layer="' + n + '"')));
  // Every other popover closes the Layers menu when it opens, and Escape closes it.
  ['function toggleModes', 'function toggleSpecies', 'function toggleNotice', 'function toggleMe'].forEach(f => {
    const body = between(f, '\n  }');
    assert.match(body, /toggleLayers\(false\)/, f);
  });
  assert.match(html, /if \(!laypop\.hidden\) \{ toggleLayers\(false\); laybtn\.focus/);
});

test('compact bar only for a mouse on a wide window; touch keeps 44 px', () => {
  const q = '@media (min-width: 1024px) and (hover: hover) and (pointer: fine) {';
  const i = html.indexOf(q); assert.ok(i > 0);
  const block = html.slice(i, html.indexOf('\n}\n', i));
  assert.match(block, /\.bar \{ height: 44px; padding: 4px 8px; \}/);
  assert.match(block, /\.bar \.listbtn, \.bar \.nbtn, \.bar \.seg button \{ min-height: 36px; \}/);
  assert.doesNotMatch(html.replace(block, ''), /min-height: 36px/, 'no 36 px control outside the mouse-only block');
});

test('piers and shore layer: plain markers, never a rating colour, and never drawn over Typical season', () => {
  const css = html.slice(html.indexOf('.amark {'), html.indexOf('\n', html.indexOf('.amark:focus-visible')));
  assert.doesNotMatch(css, /--(prime|good|fair|slow|unrated|rc)\b/);
  assert.match(html, /var accessOn = layers\.indexOf\('access'\) >= 0 && view !== 'typical';/);
  const fill = between('function fillAccess', 'function openAccess');
  assert.doesNotMatch(fill, /badge|Season\.siteView|colorVar/, 'the sheet carries no rating');
  assert.match(fill, /Not a catch report and not a rating/);
});
