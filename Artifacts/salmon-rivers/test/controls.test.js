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
  assert.match(build, /spbtn\.innerHTML = 'Species: ' \+ esc\(species \|\| 'All species'\) \+ CHEV;/, 'one button label for both modes');
  // Recent reports fills the same panel with exact names from Reports.SPECIES; nothing else decides its species.
  assert.match(build, /Reports\.SPECIES\.forEach\(function \(name\) \{ mkChip\(name, top\); \}\);/);
  assert.match(build, /mkChip\(null, top\);/);
});

test('Rivers sits on the title row, and the title names the mode', () => {
  const brand = between('<div class="brand">', '<div class="seg modes"');
  assert.match(brand, /id="listbtn"[^>]*>Rivers<\/button>/);
  assert.match(brand, /id="ttl">Salmon this month</, 'Recent reports is the default mode');
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
