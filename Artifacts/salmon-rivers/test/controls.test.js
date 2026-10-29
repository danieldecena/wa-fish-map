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
  // Phones show the list icon and keep the word for assistive technology.
  assert.match(bar, /id="listbtn"[^>]*><svg class="ri"[^]*?<\/svg><span class="rl">Rivers<\/span><\/button>/);
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

test('phone bar: the Key and Rivers icons are not hidden by a later desktop rule, and no control shrinks', () => {
  const phone = html.indexOf('@media (max-width: 520px) {\n  .bar {');
  assert.ok(phone > 0);
  const hide = html.indexOf('#keybtn .ki, #listbtn .ri { display: none; }');
  assert.ok(hide > 0 && hide < phone, 'the desktop hide rule sits above the phone block, which must win');
  assert.equal(html.split('#keybtn .ki { display: none; }').length, 1, 'no second hide rule for the Key icon');
  const block = html.slice(phone, html.indexOf('\n}\n', phone));
  assert.match(block, /\.bar > \* \{ flex-shrink: 0; \}/);
  assert.match(block, /#keybtn \.ki \{ display: block; \}/);
  assert.match(block, /#listbtn \.ri \{ display: block; \}/);
});

test('compact bar only for a mouse on a wide window; every control still reaches 44 px to click or tap', () => {
  const q = '@media (min-width: 1024px) and (hover: hover) and (pointer: fine) {';
  const i = html.indexOf(q); assert.ok(i > 0);
  const block = html.slice(i, html.indexOf('\n}\n', i));
  assert.match(block, /\.bar \{ height: 38px; padding: 3px 6px; gap: 4px; \}/);
  const h = /\.bar \.listbtn, \.bar \.nbtn, \.bar \.seg button \{ min-height: (\d+)px;/.exec(block);
  assert.ok(h, 'the mouse-only block sets the control height');
  // The drawn control is small; an invisible ::after adds its inset above and below, so the tappable height is the sum.
  const x = /\.bar \.seg button::after \{ content: ""; position: absolute; inset: -(\d+)px -\d+px; \}/.exec(block);
  assert.ok(x, 'the mouse-only block gives each bar control a hit-area extender');
  assert.ok(+h[1] + 2 * +x[1] >= 44, `drawn ${h[1]}px plus 2 x ${x[1]}px extender is under 44px`);
  // Control: the sum would fail for a control with no extender, so the assertion above can fail.
  assert.ok(+h[1] < 44);
});

test('piers and shore layer: plain markers, never a rating colour, and never drawn over Typical season', () => {
  const css = html.slice(html.indexOf('.amark {'), html.indexOf('\n', html.indexOf('.amark:focus-visible')));
  assert.doesNotMatch(css, /--(prime|good|fair|slow|unrated|rc)\b/);
  assert.match(html, /var accessOn = layers\.indexOf\('access'\) >= 0 && view !== 'typical' && !tOn;/);
  const fill = between('function fillAccess', 'function openAccess');
  assert.doesNotMatch(fill, /badge|Season\.siteView|colorVar/, 'the sheet carries no rating');
  assert.match(fill, /Not a catch report and not a rating/);
});

test('the page script parses (a stray quote in a string blanks the whole page)', () => {
  const m = html.match(/<script>\n([\s\S]*?)<\/script>/);
  assert.ok(m, 'control: the inline page script is found');
  assert.doesNotThrow(() => new Function(m[1]));
});

test('rivers with no fishing data fade; rivers with data are redrawn in river blue, never a rating colour', () => {
  assert.match(html, /#vp > \.r \{ opacity: 0\.35; \}/);
  const css = html.slice(html.indexOf('#rdata path {'), html.indexOf('\n', html.indexOf('#rdata path {')));
  assert.match(css, /stroke: var\(--river\)/);
  assert.doesNotMatch(css, /--(prime|good|fair|slow|unrated|rc)\b/);
  const build = between('var DATA_RIVERS = {};', 'var hlNodes = {};');
  assert.match(build, /RULES\.forRiver\(r\.name\)\.length/, 'a WDFW notice');
  assert.match(build, /SPLACES\.forEach/, 'a season place');
});

test('Typical season and Spawning layers: neutral shapes and words, never a rating colour, each stepping aside in its own mode', () => {
  const css = html.slice(html.indexOf('.omark {'), html.indexOf('\n', html.indexOf('.omark:focus-visible')));
  assert.doesNotMatch(css, /--(prime|good|fair|slow|unrated|rc)\b/);
  const draw = between('var tOn = HAS_TYPICAL', 'var accessOn');
  assert.match(draw, /view !== 'typical'/);
  assert.match(draw, /view !== 'spawning'/);
  assert.doesNotMatch(draw, /colorVar|--rc|glyphColor/);
  const state = between('function overlayStates', '// Creel counts');
  assert.match(state, /word:/, 'every marker carries its state in words');
});

test('month card: no report tally and no rating colour; the chips, the heat strip and the guidance counts are neutral', () => {
  const dash = between('function dashHtml', 'function setLMonth');
  assert.doesNotMatch(dash, /RWORD|tally|at a glance|data-dash="reports"/, 'the report tally and its heading were removed');
  assert.doesNotMatch(dash, /--(prime|good|fair|slow)/, 'the month card draws no rating colour');
  assert.match(dash, /data-dash="seasons"/, 'the neutral chips stay');
  const heat = dash.slice(dash.indexOf('#heat'));
  assert.doesNotMatch(heat, /--(prime|good|fair|slow)/);
  assert.match(html, /\.heat \.hc i \{[^}]*background: var\(--on-text\)/);
});
