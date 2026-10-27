# One Map With Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Week | Map | Year | Spots | Counts tab bar and draw what the other four pages showed on the Map as switchable layers (Seasons, Spot guides, Creel counts).

**Architecture:** Pure logic goes in small UMD modules next to `index.html` (same pattern as `links.js`): `layers.js` (layer names, season month/tag rules, count badge text), `season-places.js` (hand-maintained season to map place table), `spots.js` (spot guide data). `index.html` gains a Layers button and menu, draws layer marks inside the existing `render()` pass, and opens two new sheet kinds (season, spot) through the existing sheet code. The four old page folders are deleted and replaced by one-line redirect pages.

**Tech Stack:** Plain browser JavaScript (ES5 style, no build), inline SVG, Node's built-in test runner (`node --test`), Python generators under `scripts/`.

**Spec:** `docs/superpowers/specs/2026-10-26-one-map-layers-design.md`

**Mockup:** https://www.figma.com/design/K2rwx7sMdPn2m1oRbEtNcm (desktop with Layers open, phone, Season sheet, Spot guide sheet). It is a reference, not a pixel spec. Two deliberate differences from the spec, both approved by looking: the month slider sits at the top right on wide windows (bottom on phones), and labels that collide drop as they already do on the live map.

## Global Constraints

- The map stays the main view: the page opens on it exactly as today, every layer off.
- Layers never change pin colours, the legend's rating rows or the ranking. Layer marks never use a rating token (`--prime`, `--good`, `--fair`, `--slow`, `--unrated`).
- Catch-report colours and seasonal colours are never drawn as the same fill. Season marks are outlines and tags only.
- "Guidance, not regulation" and a WDFW link on every new sheet.
- Counts are never ratings.
- No network requests from page code (`test/tides.test.js` enforces this; it must keep passing with the new files added to its list).
- Generated files (`typical.js`, `creel.js`, `counts.js`, `geo.js`, `tides-data.js`, `seasons-data.js`) are never hand-edited.
- Match the existing file style: ES5 (`var`, `function`), two-space indent, comments only for non-obvious reasoning.
- Node tests: `node --test "Artifacts/salmon-rivers/test/*.test.js"` from the repo root. All must pass at the end of every task.
- Playwright is not installed on the Mac mini; `check-week.mjs` cannot run there. Visual checks use the `offscreen-safari` skill against `node Artifacts/salmon-rivers/serve.js` (http://127.0.0.1:4173/). Say which checks were visual and which were automated.
- Commits: one per task, explicit pathspec, imperative subject, body says why, ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch `one-map-layers`.

---

### Task 1: Remove the page tabs and add an empty Layers menu

**Files:**
- Create: `Artifacts/salmon-rivers/layers.js`
- Create: `Artifacts/salmon-rivers/test/layers.test.js`
- Modify: `Artifacts/salmon-rivers/index.html` (CSS lines 38, 443-493; markup line 495 and the `#bar` block; script lines 814-815, 847, 898, 1216-1242, 1784)
- Modify: `Artifacts/salmon-rivers/links.js`, `Artifacts/salmon-rivers/test/links.test.js`
- Delete: `Artifacts/salmon-rivers/test/tabs.test.js`, `Artifacts/salmon-rivers/test/onebar.test.js`

**Interfaces:**
- Produces: `Layers.NAMES` (`['seasons', 'spots', 'counts']`), `Layers.parse(str) -> string[]` (known names, canonical order, no duplicates), `Layers.toggle(list, name) -> string[]`.
- Produces: `Links.read(search).layers` (array), `Links.toQuery({ layers })` writes `layers=seasons,spots` in canonical order, in every mode.
- Produces in `index.html`: `var layers = []` (current list), `function setLayers(list)` (stores, closes nothing, calls `applyStyles(); render(); syncLink();`), button `#laybtn`, popover `#laypop` with three `role="switch"` buttons `[data-layer]`.

- [ ] **Step 1: Write the failing tests**

`Artifacts/salmon-rivers/test/layers.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const Layers = require('../layers.js');

test('parse: known names only, canonical order, no duplicates', () => {
  assert.deepEqual(Layers.parse('counts,seasons,counts,bogus'), ['seasons', 'counts']);
  assert.deepEqual(Layers.parse(''), []);
  assert.deepEqual(Layers.parse(null), []);
});

test('toggle: adds and removes, keeps canonical order', () => {
  assert.deepEqual(Layers.toggle(['counts'], 'seasons'), ['seasons', 'counts']);
  assert.deepEqual(Layers.toggle(['seasons', 'counts'], 'seasons'), ['counts']);
  assert.deepEqual(Layers.toggle([], 'bogus'), []);
});
```

Add to `test/links.test.js`:

```js
test('layers: read and written in every mode, canonical order', () => {
  assert.deepEqual(Links.read('?layers=counts,seasons').layers, ['seasons', 'counts']);
  assert.deepEqual(Links.read('').layers, []);
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['counts', 'spots'] }), '?layers=spots%2Ccounts');
  assert.equal(Links.toQuery({ mode: 'typical', layers: [] }), '?mode=typical');
});
```

Add to `test/controls.test.js` (reads `index.html` as text, like the existing tests there):

```js
test('no page tab bar; a Layers button in the map bar', () => {
  assert.doesNotMatch(html, /class="apptabs"/);
  assert.doesNotMatch(html, /--tabs-h/);
  assert.doesNotMatch(html, /ONE_BAR|placeTabs|tabsBottom/);
  assert.match(html, /<button type="button" class="listbtn" id="laybtn" aria-expanded="false" aria-controls="laypop">/);
  assert.match(html, /id="laypop"[^>]*hidden/);
  ['seasons', 'spots', 'counts'].forEach(n => assert.match(html, new RegExp('role="switch"[^>]*data-layer="' + n + '"')));
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: FAIL in `layers.test.js` (cannot find `../layers.js`), `links.test.js` (`layers` undefined), `controls.test.js` (apptabs still present).

- [ ] **Step 3: Write `layers.js`**

```js
// Artifacts/salmon-rivers/layers.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Layers = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Map layers drawn on top of any mode. Nothing here rates anything: seasons are dates, spots are text, counts are counts. */
  var NAMES = ['seasons', 'spots', 'counts'];

  function canon(list) { return NAMES.filter(function (n) { return list.indexOf(n) >= 0; }); }
  function parse(str) { return canon(String(str || '').split(',')); }
  function toggle(list, name) {
    if (NAMES.indexOf(name) < 0) return canon(list);
    return list.indexOf(name) >= 0 ? canon(list.filter(function (n) { return n !== name; })) : canon(list.concat([name]));
  }

  return { NAMES: NAMES, parse: parse, toggle: toggle };
});
```

- [ ] **Step 4: Add `layers` to `links.js`**

In `read()`, add `layers: (typeof Layers !== 'undefined' ? Layers : require('./layers.js')).parse(p.get('layers'))` is wrong for the browser; instead keep `links.js` self-contained with its own copy of the name list, since it already owns URL parsing:

```js
  var LAYERS = ['seasons', 'spots', 'counts'];
  function layerList(s) { var a = String(s || '').split(','); return LAYERS.filter(function (n) { return a.indexOf(n) >= 0; }); }
```

`read()` returns `layers: layerList(p.get('layers'))`. In `toQuery()`, after the mode keys: `var ls = layerList((state.layers || []).join(',')); if (ls.length) p.set('layers', ls.join(','));`. Export `LAYERS`. Add a test asserting `Links.LAYERS` deep-equals `Layers.NAMES` so the two lists cannot drift.

- [ ] **Step 5: Remove the tab bar from `index.html`**

- Delete CSS line 38 (`--tabs-h`), lines 443-447 (`nav.apptabs` positioning and the `--tabs-h` paddings), the one-bar `@media` block (449-464 in the current file), and the App Kit tab bar block (471-493). Replace the deleted paddings with the values they had with no tabs: `#chrome { padding-top: calc(env(safe-area-inset-top, 0px) + 8px); }` and in the wide query `#chrome { padding-top: 12px; } #sheet { top: 12px; }`.
- Delete the `<nav class="apptabs">` line.
- Script: delete `tabsEl` and `tabsBottom`; replace each `tabsBottom()` call with `0` (lines 847, 898, 1784). Delete the one-bar block (`ONE_BAR`, `oneMq`, `tabsHome`, `placeTabs`, `retab` and their listeners) and restore `phoneMq = window.matchMedia('(max-width: 520px)')`; delete the `mpop.style.left` line.
- Delete `test/tabs.test.js` and `test/onebar.test.js`.

- [ ] **Step 6: Add the Layers button and menu**

Markup, as the last child of `#bar` (after `#listbtn`):

```html
      <button type="button" class="listbtn" id="laybtn" aria-expanded="false" aria-controls="laypop"><span id="laylbl">Layers</span><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true"><path d="M2.5 4.5L6 8l3.5-3.5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg></button>
```

After `#npop`:

```html
    <div class="glass pop laypop" id="laypop" role="group" aria-label="Map layers" hidden>
      <p class="lh">Show on the map</p>
      <button type="button" class="layrow" role="switch" aria-checked="false" data-layer="seasons"><span class="lt"><b>Seasons</b><span>Waters open in the chosen month. Outlines, not ratings.</span></span><span class="sw" aria-hidden="true"></span></button>
      <button type="button" class="layrow" role="switch" aria-checked="false" data-layer="spots"><span class="lt"><b>Spot guides</b><span>Hand-written guides to one bank spot.</span></span><span class="sw" aria-hidden="true"></span></button>
      <button type="button" class="layrow" role="switch" aria-checked="false" data-layer="counts"><span class="lt"><b>Creel counts</b><span>Fish kept last week, from WDFW surveys.</span></span><span class="sw" aria-hidden="true"></span></button>
      <p class="fine">Layers add to the mode you are in. They never change a pin colour.</p>
    </div>
```

CSS (next to the `.mpop` rules; tokens only):

```css
.laypop { right: 0; left: auto; width: 300px; padding: 8px; }
.laypop .lh { margin: 2px 8px 4px; font-size: 12px; font-weight: 600; color: var(--ink2); }
.layrow { display: flex; align-items: center; gap: 10px; width: 100%; min-height: 44px; padding: 8px; border: 0; border-radius: 8px; background: transparent; color: var(--ink); text-align: left; cursor: pointer; font: inherit; }
.layrow .lt { flex: 1; display: flex; flex-direction: column; gap: 2px; }
.layrow .lt span { font-size: 12px; color: var(--ink2); }
.layrow .sw { flex: none; width: 42px; height: 26px; border-radius: 13px; background: var(--fill-toggle); position: relative; }
.layrow .sw::after { content: ""; position: absolute; top: 2px; left: 2px; width: 22px; height: 22px; border-radius: 50%; background: #fff; transition: transform 150ms ease-out; }
.layrow[aria-checked="true"] .sw { background: var(--on); }
.layrow[aria-checked="true"] .sw::after { transform: translateX(16px); }
.laypop .fine { margin: 6px 8px 2px; font-size: 11px; color: var(--ink2); }
@media (prefers-reduced-motion: reduce) { .layrow .sw::after { transition: none; } }
```

Script, after the mode menu code:

```js
  /* ---- layers: drawn on top of whichever mode is showing; never change a pin's colour ---- */
  var layers = [], laybtn = $('#laybtn'), laypop = $('#laypop');
  function syncLayUi() {
    laypop.querySelectorAll('[data-layer]').forEach(function (b) { b.setAttribute('aria-checked', layers.indexOf(b.getAttribute('data-layer')) >= 0 ? 'true' : 'false'); });
    $('#laylbl').textContent = layers.length ? 'Layers · ' + layers.length : 'Layers';
  }
  function setLayers(list) { layers = list; syncLayUi(); applyStyles(); render(); syncLink(); }
  function toggleLayers(open) {
    if (!open && laypop.contains(document.activeElement)) laybtn.focus({ preventScroll: true });
    if (open) { toggleSpecies(false); toggleNotice(false); toggleModes(false); if (!$('#mepanel').hidden) toggleMe(false); }
    laypop.hidden = !open;
    laybtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  }
  laybtn.addEventListener('click', function () { toggleLayers(laypop.hidden); });
  laypop.addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('[data-layer]') : null;
    if (b) setLayers(Layers.toggle(layers, b.getAttribute('data-layer')));
  });
```

Add `toggleLayers(false)` to the `open` branch of `toggleSpecies`, `toggleNotice`, `toggleModes` and `toggleMe`, and an Escape branch in the first Escape handler: `if (!laypop.hidden) { toggleLayers(false); laybtn.focus({ preventScroll: true }); e.stopImmediatePropagation(); return; }`.

Add `<script src="layers.js"></script>` after `links.js`. In `syncLink()` pass `layers: layers`. In boot, after the mode deep link: `if (LINK0.layers && LINK0.layers.length) setLayers(LINK0.layers);`. Update the `LINK0` fallback object to include `layers: []`.

- [ ] **Step 7: Run all Node tests**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: PASS. If `controls.test.js` asserts the 44 px rule on `.listbtn`, `#laybtn` inherits it.

- [ ] **Step 8: Visual check**

Start `node Artifacts/salmon-rivers/serve.js` in the background, open http://127.0.0.1:4173/ with the `offscreen-safari` skill, screenshot at the default window. Confirm: no tab bar, toolbar ends with "Layers", the map opens on the same view as before. Then navigate to `?layers=seasons,counts` and confirm the button reads "Layers · 2" (switches show on when the menu is opened via a click in a later check; reading the label is enough here).

- [ ] **Step 9: Commit**

```bash
git add Artifacts/salmon-rivers/layers.js Artifacts/salmon-rivers/test/layers.test.js Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/links.js Artifacts/salmon-rivers/test/links.test.js Artifacts/salmon-rivers/test/controls.test.js Artifacts/salmon-rivers/test/tabs.test.js Artifacts/salmon-rivers/test/onebar.test.js
git commit -m "Replace the page tab bar with a Layers menu on the map" -m "The map becomes the only page. The tab bar and the one-bar layout that existed to fit it are gone; a Layers menu with three switches takes its place and is remembered in the URL. Nothing is drawn yet." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Spot guides layer

**Files:**
- Create: `Artifacts/salmon-rivers/spots.js`, `Artifacts/salmon-rivers/test/spots.test.js`, `docs/research/2026-10-26-three-friends-location.md`
- Modify: `Artifacts/salmon-rivers/index.html`, `Artifacts/salmon-rivers/links.js`, `Artifacts/salmon-rivers/test/links.test.js`

**Interfaces:**
- Consumes: `layers`, `setLayers` (Task 1).
- Produces: `window.SPOTS = [{ id, name, sub, lat, lon, updated, closure: { title, text } | null, timing: { cols: string[], rows: [{ species, cells: string[] }] , note }, tips: [[label, text]], rules: [[label, text]], wdfw }]`.
- Produces in `index.html`: `fillSpot(id)`, sheet mode `'spot'`, `spotSel` (open spot id or null).
- Produces: `Links.read(search).spot`, written when `layers` includes `spots`.

- [ ] **Step 1: Find and record the location**

The Spots page has no coordinates. Find the bank access near the S 212th St line on the lower Green River in Kent from a public source (King County parks or trail map, WDFW access site list, or a street map), and write `docs/research/2026-10-26-three-friends-location.md` with: the coordinates (4 decimals), the source URL, the date checked, and one line on how the point was chosen. Expected to land near 47.41 N, -122.25 W; anything outside lat 47.36 to 47.45, lon -122.30 to -122.20 is wrong.

- [ ] **Step 2: Write the failing test**

`test/spots.test.js` (copy the current page into a fixture first: `cp Artifacts/salmon-rivers/spots/index.html Artifacts/salmon-rivers/test/fixtures/spots-page.html`):

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
global.window = {};
require('../spots.js');
const SPOTS = window.SPOTS;
const page = fs.readFileSync(path.join(__dirname, 'fixtures', 'spots-page.html'), 'utf8').replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ');

test('spots: shape and ids', () => {
  assert.ok(Array.isArray(SPOTS) && SPOTS.length >= 1);
  const ids = SPOTS.map(s => s.id);
  assert.equal(new Set(ids).size, ids.length);
  SPOTS.forEach(s => {
    assert.match(s.id, /^[a-z0-9-]+$/);
    assert.match(s.updated, /^\d{4}-\d{2}-\d{2}$/);
    assert.match(s.wdfw, /^https:\/\/wdfw\.wa\.gov\//);
  });
});

test('three friends: inside the Kent box and the research note', () => {
  const s = SPOTS.find(x => x.id === 'three-friends');
  assert.ok(s.lat > 47.36 && s.lat < 47.45 && s.lon > -122.30 && s.lon < -122.20);
  const note = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'docs', 'research', '2026-10-26-three-friends-location.md'), 'utf8');
  assert.ok(note.includes(s.lat.toFixed(4)) && note.includes(s.lon.toFixed(4)), 'coordinates are recorded with their source');
});

test('three friends: every line of guidance the Spots page showed is carried over verbatim', () => {
  const s = SPOTS.find(x => x.id === 'three-friends');
  const texts = [s.name, s.closure.title, s.closure.text, s.timing.note].concat(s.tips.map(t => t[1]), s.rules.map(r => r[1]));
  texts.forEach(t => assert.ok(page.includes(t), 'not on the old page: ' + t));
});
```

Run: `node --test Artifacts/salmon-rivers/test/spots.test.js` - Expected: FAIL (`spots.js` missing).

- [ ] **Step 3: Write `spots.js`**

Copy every string verbatim from `spots/index.html` (the test enforces it). Structure:

```js
// Artifacts/salmon-rivers/spots.js
/* Spot guides for the map's Spot guides layer. Hand-written, dated; the rules in them go stale, so each carries `updated`.
   Coordinates come from docs/research/2026-10-26-three-friends-location.md. */
window.SPOTS = [
  {
    id: 'three-friends',
    name: 'Three Friends Fishing Hole',
    sub: 'Green River · Kent, WA · Bank access',
    lat: 47.0000, lon: -122.0000, /* replace with the two values from the research note */
    updated: '2026-10-19',
    intro: 'Lower river bank access close to the S 212th St line where the rules change. Check the reach before you cast.',
    closure: { title: 'Chinook are closed this year', text: 'An August emergency rule closed Chinook retention on the Green. The upper Green is also closed to all fishing Sept 16 to Oct 31.' },
    timing: {
      cols: ['Now–Oct 31', 'Nov 1–14', 'Nov 15–30', 'Dec'],
      rows: [{ species: 'Coho', cells: ['Prime', 'Good', 'Fair', 'Slow'] }, { species: 'Chum', cells: ['Fair', 'Good', 'Prime', 'Slow'] }],
      note: 'Typical run timing from angler reports, not a WDFW forecast. A good rain brings a fresh push of fish, so the ratings can jump a step.'
    },
    tips: [/* each [label, text] row of "Best times to go", verbatim */],
    rules: [/* each [label, text] row of "Rules for the lower Green", verbatim */],
    wdfw: 'https://wdfw.wa.gov/fishing/regulations'
  }
];
```

The two comment placeholders in `tips` and `rules` are filled in this step from the page source (`grep -n 'Time of day\|Day of week\|Water\|tactics\|Salmon limit\|Minimum size\|Chinook\|S 212th' Artifacts/salmon-rivers/spots/index.html`), and the lat/lon from Step 1. The test fails until they are.

- [ ] **Step 4: Draw the pin and open its sheet**

`<script src="spots.js"></script>` after `sites.js`. In the overlay setup, after the report pins:

```js
  // Spot guides: a white pin with a bookmark glyph, never a rating colour. One node per guide, shown only while the layer is on.
  var SPOTLIST = (window.SPOTS || []).map(function (s) {
    var g = el('g', { 'class': 'spotpin', 'data-spot': s.id, tabindex: '0', role: 'button', 'aria-label': s.name + ', spot guide' }, over);
    el('path', { 'class': 'balloon', d: 'M0 0L-6.5 -10.5A13 13 0 1 1 6.5 -10.5Z' }, g);
    el('path', { 'class': 'mark', d: 'M-4 -26h8v9l-4 -2.6 -4 2.6z' }, g);
    var lab = el('text', { 'class': 'lab' }, over); lab.textContent = s.name;
    g.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openSpot(s.id); } });
    return { s: s, xy: xy(s.lon, s.lat), g: g, lab: lab };
  });
```

CSS: `.spotpin .balloon { fill: #fff; stroke: var(--pin-edge); stroke-width: 1.2; } .spotpin .mark { fill: var(--brand-a); } .spotpin { cursor: pointer; }`.

At the end of `render()`, before landmarks (so landmarks avoid them): for each entry, if `layers.indexOf('spots') < 0` hide `g` and `lab`; else position `g` at the projected point with `translate(x y) scale(0.9)`, push its box `[x - 15, y - 36, 30, 38]`, and show `lab` at `x + 15, y - 19` only if its box does not overlap `boxes` (same rule as pin labels).

In `tap()`, before the `[data-id]` lookup: `var sp = tgt && tgt.closest ? tgt.closest('[data-spot]') : null; if (sp) { openSpot(sp.getAttribute('data-spot')); return; }`.

```js
  var spotSel = null;
  function fillSpot(id) {
    var s = SPOTLIST.filter(function (o) { return o.s.id === id; })[0].s;
    $('#stitle').textContent = s.name;
    var cell = function (w) { return '<td>' + esc(w) + '</td>'; };
    var timing = '<table class="ctab"><thead><tr><th scope="col">Species</th>' + s.timing.cols.map(function (c) { return '<th scope="col">' + esc(c) + '</th>'; }).join('') + '</tr></thead><tbody>' +
      s.timing.rows.map(function (r) { return '<tr><th scope="row">' + esc(r.species) + '</th>' + r.cells.map(cell).join('') + '</tr>'; }).join('') + '</tbody></table>';
    var kv = function (rows) { return '<div class="rows">' + rows.map(function (r) { return '<div class="row"><div class="rt"><div class="nm">' + esc(r[0]) + '</div><div class="dt">' + esc(r[1]) + '</div></div></div>'; }).join('') + '</div>'; };
    $('#sbody').innerHTML = '<div class="head"><p>' + esc(s.sub) + '</p><p>' + esc(s.intro) + '</p>' + distHtml([s.lat, s.lon]) + '<p>Updated ' + esc(Reports.formatDay(s.updated)) + '</p></div>' +
      (s.closure ? '<section class="advisory"><div><h3>' + esc(s.closure.title) + '</h3><p>' + esc(s.closure.text) + '</p></div></section>' : '') +
      '<section><h3>When the fish are in</h3>' + timing + '<p class="miss">' + esc(s.timing.note) + '</p></section>' +
      '<section><h3>Best times to go</h3>' + kv(s.tips) + '</section>' +
      '<section><h3>Rules</h3>' + kv(s.rules) + '</section>' +
      '<section class="advisory"><div><h3>Before you go</h3><p>Guidance, not regulation. Rules here were checked on the date above and can change with little notice. Confirm them on WDFW before you fish.</p></div></section>' +
      '<div class="foot"><a href="' + esc(s.wdfw) + '" target="_blank" rel="noopener">WDFW fishing rules and emergency changes</a></div>';
    $('#sbody').scrollTop = 0;
  }
  function openSpot(id) {
    clearRiver(); selected = null; mode = 'spot'; spotSel = id;
    fillSpot(id); showSheet(); syncLink();
  }
```

In `closeSheet()` add `spotSel = null;`. In `setMe()` add `else if (mode === 'spot') fillSpot(spotSel);`.

- [ ] **Step 5: Deep link**

`links.js`: `read()` returns `spot: p.get('spot') || null`; `toQuery()` writes `spot` only when `state.layers` includes `spots`. Test:

```js
test('spot: written only with the spots layer on', () => {
  assert.equal(Links.read('?layers=spots&spot=three-friends').spot, 'three-friends');
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['spots'], spot: 'three-friends' }), '?layers=spots&spot=three-friends');
  assert.equal(Links.toQuery({ mode: 'reports', layers: [], spot: 'three-friends' }), '');
});
```

`syncLink()` passes `spot: mode === 'spot' ? spotSel : null`. Boot: after `setLayers`, `if (LINK0.spot && layers.indexOf('spots') >= 0 && SPOTLIST.some(function (o) { return o.s.id === LINK0.spot; })) openSpot(LINK0.spot);`.

Add `spots.js` and `layers.js` to the page-code list in `test/tides.test.js` that is scanned for network calls.

- [ ] **Step 6: Run tests, then visual check**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` - Expected: PASS.
Visual (off-screen Safari): `?layers=spots` shows the white pin in Kent; `?layers=spots&spot=three-friends` opens the sheet with the closure banner, the timing table, the tips and the rules; Done closes it and the URL drops `spot=`.

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/spots.js Artifacts/salmon-rivers/test/spots.test.js Artifacts/salmon-rivers/test/fixtures/spots-page.html docs/research/2026-10-26-three-friends-location.md Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/links.js Artifacts/salmon-rivers/test/links.test.js Artifacts/salmon-rivers/test/tides.test.js
git commit -m "Draw spot guides on the map as a layer" -m "Three Friends Fishing Hole moves from its own page into spots.js and opens as a map sheet, so a second guide is one more entry. Its location is sourced in docs/research." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Creel counts layer

**Files:**
- Modify: `Artifacts/salmon-rivers/layers.js`, `Artifacts/salmon-rivers/test/layers.test.js`, `Artifacts/salmon-rivers/index.html`

**Interfaces:**
- Consumes: `Counts.forWater(id)` (from `counts.js`: `{ week, weekEnd, rows: [{ section, species, anglers, kept, released }], noCatch: { anglers } | null, source }` or `null`).
- Produces: `Layers.keptText(water) -> string | null`.

- [ ] **Step 1: Write the failing test**

```js
test('keptText: All sections combined rows when present, else every row; nulls skipped', () => {
  const row = (section, kept) => ({ section, species: 'Coho Salmon', anglers: 1, kept, released: null });
  assert.equal(Layers.keptText({ rows: [row('All sections combined', 124), row('All sections combined', 9), row('Below Br', 50)], noCatch: null }), '133 kept');
  assert.equal(Layers.keptText({ rows: [row('Above Br', null), row('Below Br', 7), row('Below Br', 3)], noCatch: null }), '10 kept');
  assert.equal(Layers.keptText({ rows: [], noCatch: { anglers: 8 } }), '0 kept');
  assert.equal(Layers.keptText({ rows: [row(null, null)], noCatch: null }), 'Kept not reported');
  assert.equal(Layers.keptText(null), null);
});

test('keptText: matches the live counts.js for every water', () => {
  global.window = global.window || {};
  const C = require('../counts.js');
  Object.keys(C.WATERS).forEach(id => assert.match(Layers.keptText(C.forWater(id)), /^(\d+ kept|Kept not reported)$/));
});
```

Run: `node --test Artifacts/salmon-rivers/test/layers.test.js` - Expected: FAIL (`keptText` is not a function).

- [ ] **Step 2: Implement**

In `layers.js`:

```js
  /* The badge on a surveyed river. A river reported as sections plus a combined total is summed from the total only,
     or the sections would be counted twice. A null count is "not reported", never zero. */
  function keptText(w) {
    if (!w) return null;
    if (!w.rows.length) return w.noCatch ? '0 kept' : null;
    var all = w.rows.filter(function (r) { return r.section === 'All sections combined'; });
    var rows = all.length ? all : w.rows;
    var known = rows.filter(function (r) { return r.kept !== null; });
    if (!known.length) return 'Kept not reported';
    return known.reduce(function (a, r) { return a + r.kept; }, 0) + ' kept';
  }
```

Export it.

- [ ] **Step 3: Draw badges**

In the overlay setup, one badge per `Reports.SITES` entry that has `Counts.forWater(s.id)`:

```js
  // Creel counts: a text badge under each surveyed river's pin. Neutral glass, never coloured by the number.
  var COUNTBADGES = typeof Counts === 'undefined' ? [] : SITES.filter(function (s) { return Counts.forWater(s.id); }).map(function (s) {
    var g = el('g', { 'class': 'cbadge', 'data-count': s.id, tabindex: '0', role: 'button' }, over);
    var r = el('rect', { rx: 8, height: 20, y: -10 }, g);
    var t = el('text', { x: 8, y: 4 }, g); t.textContent = Layers.keptText(Counts.forWater(s.id));
    g.setAttribute('aria-label', s.name + ', WDFW creel survey, ' + t.textContent + ', week of ' + Counts.forWater(s.id).week);
    g.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openCounts(s.id); } });
    return { s: s, g: g, r: r, t: t, w: 0 };
  });
```

CSS: `.cbadge rect { fill: var(--glass); stroke: var(--glass-line); } .cbadge text { font: 600 11px var(--sans); fill: var(--ink); } .cbadge { cursor: pointer; }`.

In `render()`, after the pin labels and before landmarks: when `layers` has `counts` and `view === 'reports'`, measure each text once (`b.w = b.t.getBBox().width` when `b.w === 0`, set `r` width to `b.w + 16`), place it at the pin's screen point `+ (15, 6)`, flip left of the pin when it would run past `W - 8`, skip it when its box overlaps `boxes` (except for the selected pin's river), and push its box. Hide all badges in Typical season and Spawning: the counts belong to the eight report rivers, and those modes draw other sites.

`tap()`: `var cnt = tgt && tgt.closest ? tgt.closest('[data-count]') : null; if (cnt) { openCounts(cnt.getAttribute('data-count')); return; }` with

```js
  function openCounts(id) {
    openSheet(id);
    var sec = $('#sbody .creel'); if (sec) sec.closest('section').scrollIntoView({ block: 'start' });
  }
```

Legend: in `syncLayUi()`, rebuild a `<ul id="layl">` under the legend with one `<li>` per active layer: Seasons "Dashed ring: a season open this month", Spot guides "White pin: a spot guide", Creel counts "Badge: fish kept last week (WDFW survey)". Hide the list when no layer is on.

- [ ] **Step 4: Tests and visual check**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` - Expected: PASS.
Visual: `?layers=counts` shows eight badges (Cowlitz "10 kept", Lower Columbia "133 kept", Washougal "0 kept") with no badge over a pin; switching to Typical hides them; tapping one opens the river sheet at its "WDFW weekly creel" section. Compare against the Figma desktop frame.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/layers.js Artifacts/salmon-rivers/test/layers.test.js Artifacts/salmon-rivers/index.html
git commit -m "Show last week's creel counts as map badges" -m "The Counts tab's newest week now sits on the map next to each surveyed river. Rivers reported by section and as a combined total are summed from the total only, so nothing is counted twice." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Seasons layer

**Files:**
- Create: `Artifacts/salmon-rivers/season-places.js`, `Artifacts/salmon-rivers/test/season-places.test.js`
- Create: `Artifacts/salmon-rivers/seasons-data.js` (copy of `Artifacts/fishing-year/data.js`; see Step 1)
- Modify: `Artifacts/salmon-rivers/layers.js`, `Artifacts/salmon-rivers/test/layers.test.js`, `Artifacts/salmon-rivers/index.html`, `Artifacts/salmon-rivers/links.js`, `Artifacts/salmon-rivers/test/links.test.js`

**Interfaces:**
- Consumes: `window.FY.seasons` (`{ id, name, start, end, where, note, source }`), `RIVERTAP.rivers` (`{ id, name, d }`), `Reports.SITES` ids.
- Produces: `window.SEASON_PLACES = { '<season id>': [ { river: id, evidence } | { point: [lon, lat], label, evidence } ] }`.
- Produces: `Layers.openIn(season, year, month) -> boolean`, `Layers.tagFor(season, today) -> { kind: 'ends' | 'opens', days, text } | null`, `Layers.seasonMonthLabel(year, month) -> 'October 2026'`.
- Produces: `Links.read(search).season`; `month` is written when the mode is spawning **or** `layers` includes `seasons`.

- [ ] **Step 1: Bring the season data next to the map**

`cp Artifacts/fishing-year/data.js Artifacts/salmon-rivers/seasons-data.js`. It is a generated file (`scripts/build_fishing_year.py` writes `Artifacts/fishing-year/data.js`); the copy is byte-identical. Add a test in `season-places.test.js`: `assert.equal(read('seasons-data.js'), read('../fishing-year/data.js'))` so the copy cannot drift.

- [ ] **Step 2: Write the failing tests**

`test/season-places.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const here = p => path.join(__dirname, '..', p);
const ctx = { window: {} }; ctx.self = ctx.window; vm.createContext(ctx);
['seasons-data.js', 'rivers-tap.js', 'season-places.js'].forEach(f => vm.runInContext(fs.readFileSync(here(f), 'utf8'), ctx));
const FY = ctx.window.FY, TAP = ctx.window.RIVERTAP, PLACES = ctx.window.SEASON_PLACES;
const Reports = require('../reports.js');

test('seasons-data.js is a byte copy of the Fishing Year data', () => {
  assert.equal(fs.readFileSync(here('seasons-data.js'), 'utf8'), fs.readFileSync(path.join(__dirname, '..', '..', 'fishing-year', 'data.js'), 'utf8'));
});

test('every season has an entry, and no entry names an unknown season', () => {
  const ids = FY.seasons.map(s => s.id);
  assert.deepEqual(Object.keys(PLACES).sort(), ids.slice().sort());
});

test('every place resolves and carries evidence from its season where text', () => {
  const rivers = new Set(TAP.rivers.map(r => r.id));
  const sites = new Set(Reports.SITES.map(s => s.id));
  FY.seasons.forEach(s => (PLACES[s.id]).forEach(p => {
    assert.ok(p.evidence && s.where.toLowerCase().includes(p.evidence.toLowerCase()), s.id + ': evidence must be a phrase of where: ' + p.evidence);
    if (p.river) assert.ok(rivers.has(p.river) || sites.has(p.river), s.id + ': unknown river ' + p.river);
    else {
      assert.ok(Array.isArray(p.point) && p.label, s.id + ': a point needs [lon, lat] and a label');
      const [lon, lat] = p.point;
      assert.ok(lon > -124.9 && lon < -116.9 && lat > 45.5 && lat < 49.0, s.id + ': point outside Washington');
    }
  }));
});
```

Add to `test/layers.test.js`:

```js
test('openIn: overlap with the calendar month, across year ends', () => {
  const s = (start, end) => ({ start, end });
  assert.equal(Layers.openIn(s('2026-10-01', '2026-10-31'), 2026, 10), true);
  assert.equal(Layers.openIn(s('2026-10-16', '2026-11-30'), 2026, 11), true);
  assert.equal(Layers.openIn(s('2026-12-01', '2027-03-31'), 2027, 1), true);
  assert.equal(Layers.openIn(s('2026-12-01', '2027-03-31'), 2026, 11), false);
  assert.equal(Layers.openIn(s('2026-10-01', '2026-10-31'), 2027, 10), false);
});

test('tagFor: ends within 7 days, opens within 14, else none', () => {
  const s = (start, end) => ({ start, end });
  assert.deepEqual(Layers.tagFor(s('2026-10-01', '2026-10-31'), '2026-10-26'), { kind: 'ends', days: 5, text: 'ends Oct 31' });
  assert.deepEqual(Layers.tagFor(s('2026-11-05', '2026-11-30'), '2026-10-26'), { kind: 'opens', days: 10, text: 'opens Nov 5' });
  assert.equal(Layers.tagFor(s('2026-10-01', '2026-11-30'), '2026-10-26'), null);
  assert.equal(Layers.tagFor(s('2026-12-01', '2027-03-31'), '2026-10-26'), null);
  assert.deepEqual(Layers.tagFor(s('2026-10-01', '2026-10-26'), '2026-10-26'), { kind: 'ends', days: 0, text: 'ends today' });
});
```

Run both files. Expected: FAIL (`season-places.js` missing, `openIn` not a function).

- [ ] **Step 3: Implement the rules in `layers.js`**

```js
  var DAY = 86400000, MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function day(iso) { return Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10)) / DAY; }
  function short(iso) { return MON[+iso.slice(5, 7) - 1] + ' ' + (+iso.slice(8, 10)); }
  /* Open at any point in that calendar month. */
  function openIn(s, year, month) {
    var first = Date.UTC(year, month - 1, 1) / DAY, last = Date.UTC(year, month, 0) / DAY;
    return day(s.start) <= last && day(s.end) >= first;
  }
  /* The Week page's two windows: an open season ending within 7 days, or one opening within 14. */
  function tagFor(s, today) {
    var t = day(today), a = day(s.start), b = day(s.end);
    if (a <= t && t <= b && b - t <= 7) return { kind: 'ends', days: b - t, text: b === t ? 'ends today' : 'ends ' + short(s.end) };
    if (a > t && a - t <= 14) return { kind: 'opens', days: a - t, text: 'opens ' + short(s.start) };
    return null;
  }
  function seasonMonthLabel(year, month) { return MONTHS[month - 1] + ' ' + year; }
```

Export all three.

- [ ] **Step 4: Write `season-places.js`**

Map only places the `where` text names; the evidence is the phrase that names it. Points use well-known coordinates; check each against a map before committing and fix any that land in the water or the wrong town.

```js
// Artifacts/salmon-rivers/season-places.js
/* Where each Washington Fishing Year season goes on the map. Hand-maintained, like rules.js: when seasons-data.js gains or loses
   a season, test/season-places.test.js fails until this table matches. A place is drawn only when the season's own `where` text
   names it (`evidence` is that phrase). Vague text such as "some Puget Sound rivers" names no place and stays in the sheet. */
window.SEASON_PLACES = {
  'skagit-coho': [{ river: 'skagit', evidence: 'Skagit River' }],
  'chum': [{ point: [-123.06, 47.42], label: 'Hood Canal', evidence: 'Hood Canal south of Ayock Point' }],
  'steelhead': [{ point: [-124.38, 47.95], label: 'Olympic Peninsula rivers', evidence: 'Olympic Peninsula rivers' }],
  'perch': [{ point: [-122.26, 47.62], label: 'Lake Washington', evidence: 'Lake Washington' }],
  'spring-chinook': [{ river: 'columbia', evidence: 'Columbia' }, { river: 'cowlitz', evidence: 'Cowlitz' }, { river: 'lewis', evidence: 'Lewis' }],
  'lingcod': [{ point: [-124.10, 46.90], label: 'Westport', evidence: 'Westport' }],
  'rockfish': [{ point: [-124.10, 46.90], label: 'Westport', evidence: 'Westport' }],
  'walleye': [{ river: 'columbia-river', evidence: 'Columbia River' }],
  'trout': [{ point: [-122.33, 47.61], label: 'Lowland lakes near Seattle', evidence: 'Lowland lakes near Seattle' }],
  'kokanee': [
    { point: [-122.33, 48.73], label: 'Lake Whatcom', evidence: 'Lake Whatcom' },
    { point: [-120.02, 47.84], label: 'Lake Chelan', evidence: 'Lake Chelan' },
    { point: [-118.06, 48.61], label: 'Lake Roosevelt', evidence: 'Lake Roosevelt' }
  ],
  'crab': [
    { point: [-122.20, 47.98], label: 'Everett', evidence: 'Everett' },
    { point: [-122.38, 47.81], label: 'Edmonds', evidence: 'Edmonds' },
    { point: [-123.02, 48.53], label: 'San Juan Islands', evidence: 'San Juans' }
  ],
  'sockeye': [{ point: [-121.66, 48.70], label: 'Baker Lake', evidence: 'Baker Lake' }],
  'pink': [
    { point: [-122.38, 47.81], label: 'Edmonds', evidence: 'Edmonds' },
    { point: [-122.30, 47.95], label: 'Mukilteo', evidence: 'Mukilteo' },
    { river: 'green-river-2', evidence: 'Green' },
    { river: 'nisqually-river', evidence: 'Nisqually' }
  ],
  'fall-chinook': [{ river: 'lewis', evidence: 'Lewis River' }],
  'fall-coho': [{ river: 'skagit', evidence: 'Skagit River' }]
};
```

Check `green-river-2` is the Kent Green River: `node -e` print `RIVERTAP.rivers.find(r => r.id === 'green-river-2').center` and confirm it projects near Kent (x about 191, y about 172 in viewport units); if `green-river` is the Kent one instead, use that. `fall-chinook` maps only the Lewis: its `where` sends Cowlitz and Olympic Peninsula to the note.

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` - Expected: PASS.

- [ ] **Step 5: Draw season marks**

Scripts: `<script src="seasons-data.js"></script>` and `<script src="season-places.js"></script>` after `spots.js`.

State: `var LMONTH = MONTH, LYEAR = YEAR;` (the Seasons layer's own month; in Spawning mode the layer follows `SMONTH`). `function seasonMonth() { return view === 'spawning' ? SMONTH : LMONTH; }`. The year for a chosen month is the next occurrence from today: `function seasonYear(m) { return m < MONTH ? YEAR + 1 : YEAR; }`. This matches the Fishing Year page, which runs from this October forward.

Build once:

```js
  // Seasons: a dashed halo along a named river, or a dashed ring at a named point. One neutral token; never a fill, never a rating colour.
  var FYS = window.FY && window.SEASON_PLACES ? window.FY.seasons : [];
  var seasonG = el('g', { id: 'seasons' }, vp); seasonG.style.display = 'none';
  var SPLACES = [];
  FYS.forEach(function (s) {
    (window.SEASON_PLACES[s.id] || []).forEach(function (p) {
      var site = p.river && SITES.filter(function (q) { return q.id === p.river; })[0];
      var d = p.river ? (site ? (D.hl[site.id] || (site.tap && TAPBY[site.tap] ? TAPBY[site.tap].d : null)) : (TAPBY[p.river] ? TAPBY[p.river].d : null)) : null;
      var node = d ? el('path', { 'class': 'shalo', d: d, 'data-season': s.id }, seasonG) : el('circle', { 'class': 'sring', r: 14, 'data-season': s.id }, over);
      var at = d ? (site ? site.xy : TAPBY[p.river].center) : xy(p.point[0], p.point[1]);
      SPLACES.push({ s: s, p: p, node: node, xy: at, label: p.label || (site ? site.name : TAPBY[p.river].name) });
    });
  });
  var stagPool = [];
```

CSS: `#seasons .shalo { fill: none; stroke: var(--ink); stroke-opacity: .85; stroke-width: 6; stroke-dasharray: 6 5; vector-effect: non-scaling-stroke; } .sring { fill: none; stroke: var(--ink); stroke-opacity: .9; stroke-width: 2; stroke-dasharray: 5 4; cursor: pointer; } .stag rect { fill: var(--sheet); stroke: var(--ink); stroke-dasharray: 3 2; } .stag text { font: 600 11px var(--sans); fill: var(--ink); }`.

In `render()`, before the pins are placed (so halos sit under pins and rings and tags join `boxes` first):

- If `layers` lacks `seasons`: `seasonG.style.display = 'none'`, hide every ring and tag, skip.
- Else compute `var m = seasonMonth(), y = seasonYear(m)`; for each place: `on = Layers.openIn(place.s, y, m)`. Halos: `node.style.display = on ? '' : 'none'`. Rings: position at the projected point, show when `on`.
- Tags: only when `m === MONTH` (the current month), one per season at its first place, text `season.name + ' · ' + tag.text`, from `Layers.tagFor(s, TODAY)`. Draw from `stagPool` (a `g.stag` with `rect` and `text`, built lazily like `getCluster`), placed at `+(16, 14)` from the place, flipped left near the right edge, skipped when overlapping `boxes`. Each tag and ring carries `data-season`.

`tap()`: `var se = tgt && tgt.closest ? tgt.closest('[data-season]') : null; if (se) { openSeason(se.getAttribute('data-season')); return; }` placed after spots and counts but before `[data-id]`, so a pin on top of a halo still wins (pins are later in the DOM and `closest` starts at the pin).

- [ ] **Step 6: Month slider and season sheet**

Markup, after `#spawn`:

```html
    <div class="glass smonth" id="smonth" hidden>
      <p class="sl" id="sml" aria-live="polite"></p>
      <div class="months" id="months" role="radiogroup" aria-label="Season month"></div>
    </div>
```

CSS: on wide windows (`min-width: 760px`) `#smonth` is absolutely placed top right under the safe area (`top: 12px; right: 12px; width: 528px`); on phones it sits in `#bottom` above the legend (move the node there in `placeModes`-style code keyed on `phoneMq`), the legend collapses to its Key button while it shows. Month buttons reuse the `.year button` look without the stacked bars: `.months { display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 2px; } .months button { min-height: 44px; border: 0; border-radius: 8px; background: transparent; color: var(--ink2); font: 600 12px var(--sans); } .months button[aria-checked="true"] { background: var(--fill-toggle); color: var(--ink); box-shadow: inset 0 0 0 1.5px var(--on); }`.

Script: build 12 radio buttons like the Spawning ribbon (same arrow-key handling, no scrub). `function setLMonth(m) { LMONTH = m; syncSeasonUi(); render(); if (mode === 'season') fillSeason(seasonSel); syncLink(); }`. `syncSeasonUi()` shows `#smonth` when `layers` has `seasons` and `view !== 'spawning'`, marks the checked month, and writes `#sml`: `n + (n === 1 ? ' season' : ' seasons') + ' open in ' + Layers.seasonMonthLabel(seasonYear(m), m)`. Call it from `setLayers`, `setMode` and `setMonth`.

```js
  var seasonSel = null;
  function fillSeason(id) {
    var s = FYS.filter(function (x) { return x.id === id; })[0], tg = Layers.tagFor(s, TODAY);
    var src = s.source ? [].concat(s.source) : [];
    $('#stitle').textContent = s.name;
    $('#sbody').innerHTML = '<div class="head"><p>' + esc(s.where) + '</p>' + (tg ? '<span class="chip">' + esc(cap(tg.text)) + '</span>' : '') + '</div>' +
      '<section><h3>Dates</h3><div class="rows"><div class="row"><div class="rt"><div class="nm">Open</div><div class="dt">' + esc(Reports.formatDay(s.start)) + ' to ' + esc(Reports.formatDay(s.end)) + '</div></div></div></div></section>' +
      (s.note ? '<section><h3>Note</h3><p>' + esc(s.note) + '</p></section>' : '') +
      (src.length ? '<section><h3>Source</h3>' + src.map(function (x) { return x.url ? '<a href="' + esc(x.url) + '" target="_blank" rel="noopener">' + esc(x.label) + (x.checked ? ' (checked ' + esc(Reports.formatDay(x.checked)) + ')' : '') + '</a>' : '<p>' + esc(x.label) + '</p>'; }).join('') + '</section>' : '') +
      '<section class="advisory"><div><h3>Before you go</h3><p>Guidance, not regulation. Seasons can change or close with little notice. Confirm the rules on WDFW before you fish.</p></div></section>' +
      '<div class="foot"><a href="https://wdfw.wa.gov/fishing/regulations" target="_blank" rel="noopener">WDFW fishing rules and emergency changes</a></div>';
    $('#sbody').scrollTop = 0;
  }
  function openSeason(id) { clearRiver(); selected = null; mode = 'season'; seasonSel = id; spotSel = null; fillSeason(id); showSheet(); syncLink(); }
```

Several seasons at one place: when a tap lands on a ring shared by more than one open season (same `label`), open the first; the sheet lists the others under "Also open here" as `[data-season]` buttons handled by the `#sbody` click listener. `closeSheet()` sets `seasonSel = null`.

- [ ] **Step 7: Deep links**

`links.js`: `read()` returns `season: p.get('season') || null`; `toQuery()` writes `month` when `mode === 'spawning'` or `layers` has `seasons`, and `season` only when `layers` has `seasons`. Tests:

```js
test('seasons layer: month and season written with the layer, in any mode', () => {
  assert.equal(Links.toQuery({ mode: 'reports', layers: ['seasons'], month: 12, season: 'steelhead' }), '?month=12&layers=seasons&season=steelhead');
  assert.equal(Links.toQuery({ mode: 'reports', layers: [], month: 12, season: 'steelhead' }), '');
  assert.equal(Links.read('?layers=seasons&season=chum').season, 'chum');
});
```

Adjust the expected key order to whatever `toQuery` produces once, then keep it: the order is part of the shareable link. `syncLink()` passes `month: view === 'spawning' ? SMONTH : (layers.indexOf('seasons') >= 0 ? LMONTH : null)` and `season: mode === 'season' ? seasonSel : null`. Boot: after `setLayers`, `if (LINK0.month && view !== 'spawning' && layers.indexOf('seasons') >= 0) setLMonth(LINK0.month); if (LINK0.season && layers.indexOf('seasons') >= 0 && FYS.some(function (s) { return s.id === LINK0.season; })) openSeason(LINK0.season);`.

Add `seasons-data.js` and `season-places.js` to the network-call scan list in `test/tides.test.js`.

- [ ] **Step 8: Tests and visual check**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` - Expected: PASS.
Visual, with `?today=2026-10-26&layers=seasons`: dashed halo on the Skagit with tag "Skagit coho · ends Oct 31", dashed ring on Hood Canal, slider reads "2 seasons open in October 2026". Click December: the steelhead ring on the Olympic Peninsula appears, Skagit and Hood Canal go. Switch to Spawning: the slider hides and the layer follows the ribbon month. Phone width (390): slider at the bottom above the Key button, nothing overlapping the toolbar. Light and dark. Compare against the Figma frames.

- [ ] **Step 9: Commit**

```bash
git add Artifacts/salmon-rivers/season-places.js Artifacts/salmon-rivers/seasons-data.js Artifacts/salmon-rivers/test/season-places.test.js Artifacts/salmon-rivers/layers.js Artifacts/salmon-rivers/test/layers.test.js Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/links.js Artifacts/salmon-rivers/test/links.test.js Artifacts/salmon-rivers/test/tides.test.js
git commit -m "Draw Fishing Year seasons on the map with a month slider" -m "Week and Year both listed the same 15 seasons; one layer now outlines the waters open in the chosen month and tags seasons ending within a week or opening within two. Places come from a hand-kept table that maps only what each season's own text names." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Delete the old pages, redirect their links, update docs

**Files:**
- Delete: `Artifacts/salmon-rivers/week/` (except the new redirect), `year/`, `spots/`, `counts/` contents; `week.js`; `year/anchor.js`; `test/week.test.js`; `test/year-anchor.test.js`; `test/fixtures` files only the Week tests used.
- Move: `Artifacts/salmon-rivers/week/tides-data.js` to `Artifacts/salmon-rivers/tides-data.js`
- Create: `Artifacts/salmon-rivers/{week,year,spots,counts}/index.html` (redirects), `Artifacts/salmon-rivers/test/redirects.test.js`
- Modify: `index.html` (script path, `footHtml`, `typicalFootHtml`), `tides.js` and `test/tides.test.js` (drop `render`/`mount`, which only the Week page used), `scripts/build_tides.py` (`OUT`), `README.md` (salmon-rivers), project `CLAUDE.md` (Web pages table), `check-week.mjs` (single page), `TASKS.md`

- [ ] **Step 1: Write the failing redirect test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const want = { week: '../?layers=seasons', year: '../?layers=seasons', spots: '../?layers=spots&spot=three-friends', counts: '../?layers=counts' };

test('each old page is only a redirect into the map', () => {
  Object.entries(want).forEach(([dir, to]) => {
    const files = fs.readdirSync(path.join(__dirname, '..', dir));
    assert.deepEqual(files, ['index.html'], dir + ' holds only its redirect');
    const html = fs.readFileSync(path.join(__dirname, '..', dir, 'index.html'), 'utf8');
    assert.match(html, /^<!doctype html>/i);
    assert.ok(html.includes('<a href="' + to.replace(/&/g, '&amp;') + '">'), dir + ' has a visible link');
    assert.ok(html.includes(JSON.stringify(to)), dir + ' redirects in script');
  });
});

test('the year redirect carries a season hash across as season=', () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'year', 'index.html'), 'utf8');
  assert.match(html, /location\.hash/);
  assert.match(html, /season=/);
});

test('the map no longer links to the old pages', () => {
  const map = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  assert.doesNotMatch(map, /(week|year|spots|counts)\/index\.html/);
  assert.doesNotMatch(map, /week\/tides-data\.js/);
});
```

Run: expected FAIL.

- [ ] **Step 2: Redirect pages**

Each `index.html` (supporting HTML files are served without the publisher's skeleton, so each carries its own doctype):

```html
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Washington Fishing Map</title>
<style>body{margin:0;padding:24px 16px;font:15px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}@media (prefers-color-scheme:dark){body{background:#1c1c1e;color:#fff}a{color:#4fc3dc}}</style></head>
<body><p>This page is now part of the map. <a href="../?layers=seasons">Open the map</a></p>
<script>location.replace("../?layers=seasons");</script></body></html>
```

with the target per folder from the test's `want` table. The year page builds its target from the hash:

```html
<script>var to = "../?layers=seasons"; var h = location.hash.slice(1); if (/^[a-z0-9-]+$/.test(h)) to += "&season=" + h; location.replace(to);</script>
```

(keep the exact string `"../?layers=seasons"` so the test finds it).

- [ ] **Step 3: Move tides data and clean up**

- `git mv Artifacts/salmon-rivers/week/tides-data.js Artifacts/salmon-rivers/tides-data.js`; change the script tag in `index.html`; change `OUT` in `scripts/build_tides.py` to drop the `"week"` segment and update its docstring; run `/opt/homebrew/bin/python3 -m unittest discover -s scripts -p "test_build_tides.py"` and fix any path it asserts.
- In `tides.js`, delete `render` and `mount` and their helpers that nothing else calls (check with `grep -n 'Tides\.' Artifacts/salmon-rivers/index.html`); delete their tests in `test/tides.test.js` (those that require `week.js` or call `render`/`mount`). Keep `stationsOf`, `nearest`, `miles`, `days`, `fmtExtreme`, `footnote`.
- `git rm` `week.js`, `year/anchor.js`, `year/data.js`, `year/index.html`, `spots/index.html`, `counts/index.html`, `counts/data.js`, `test/week.test.js`, `test/year-anchor.test.js`, and fixtures used only by those tests.
- `footHtml` and `typicalFootHtml`: delete the "Washington Fishing Year" link line.
- `check-week.mjs`: drop the five-page loop and the Week, Counts and tide-table checks; keep console errors, no horizontal scroll at 320/390/1024 in light and dark, deep links, no outside request; add `?layers=seasons,spots,counts` to the URLs it loads. It cannot run on the Mac mini (no Playwright); say so in the commit body.

- [ ] **Step 4: Docs**

- `Artifacts/salmon-rivers/README.md`: the page is one map; describe the three layers, the new files (`layers.js`, `spots.js`, `season-places.js`, `seasons-data.js`, `tides-data.js`), the redirects, and what was dropped (multi-year creel table, the 26-station tide table). Remove rows for deleted files.
- Project `CLAUDE.md` Web pages table: `salmon-rivers/` row becomes "Washington Fishing Map: one map (Recent reports, Typical season, Spawning) with Seasons, Spot guides and Creel counts layers"; `fishing-year/` row: "its data is copied to `salmon-rivers/seasons-data.js` for the Seasons layer"; `three-friends-fishing-hole/` row: "its content now lives in `salmon-rivers/spots.js`"; `salmon-catch-table/` row unchanged (its own artifact still exists). Add `layers.js`, `spots.js`, `season-places.js` to nothing generated; add `seasons-data.js` and `tides-data.js` to the generated list.
- `TASKS.md`: tick the item if one exists; add "[you] Look over the one-map page on a phone" as an open item.

- [ ] **Step 5: Tests**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` and `/opt/homebrew/bin/python3 -m unittest discover -s scripts -p "test_*.py"`.
Expected: PASS for both.

- [ ] **Step 6: Commit**

```bash
git add -A Artifacts/salmon-rivers scripts/build_tides.py CLAUDE.md TASKS.md
git commit -m "Retire the Week, Year, Spots and Counts pages" -m "Their content is on the map as layers, so each folder keeps only a redirect that opens the map on the matching layer; old shared links keep working. Tide data moves next to the map, and the Week-only table code goes. check-week.mjs is cut to one page and could not be run here (no Playwright on this Mac)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`-A` limited to those paths records the deletions; review `git status` first and confirm nothing outside the plan is staged.)

---

### Task 6: Verify, publish, record

**Files:**
- Modify: `Artifacts/salmon-rivers/artifact.json`, `STATUS.md`

- [ ] **Step 1: Full check**

Run every Node and Python test (commands in Task 5 Step 5). Then with the `offscreen-safari` skill, at 1440x900 and 390x844, light and dark: default URL (unchanged opening view, no layers), `?layers=seasons,spots,counts`, each redirect path (`/week/`, `/year/#chum`, `/spots/`, `/counts/`), and one sheet of each new kind. Record what was seen.

- [ ] **Step 2: Publish**

Read the live artifact first (`Artifact` action `read` with the `url` from `artifact.json`) and diff it against the repo's last published state; if it changed outside the repo, stop and report before overwriting. Publish `index.html` to the same `url` with every supporting file the page loads (the scripts, `seasons-data.js`, `tides-data.js`, `spots.js`, `season-places.js`, `layers.js`, and the four redirect pages), and `null` for every removed path (`week.js`, `year/anchor.js`, `year/data.js`, `counts/data.js`, `week/tides-data.js`).

- [ ] **Step 3: Record and commit**

Add the new version id to `artifact.json`; add a dated STATUS.md log line. Commit with an explicit pathspec.

---

## Self-review notes

- Spec sections 1 to 7 map to Tasks 4, 2, 3, 5 (section 4 drops), 5 (old links), 1 and 3 (layers and modes together, legend), and the test steps in every task. The spec's "Order" is the task order.
- The month slider position differs from the spec text (top right on wide windows); the mockup shows why (bottom placement covered the southwest rivers). Phones keep it at the bottom as the spec says.
- Names used across tasks: `layers`, `setLayers`, `syncLayUi`, `toggleLayers`, `SPOTLIST`, `openSpot`, `fillSpot`, `spotSel`, `COUNTBADGES`, `openCounts`, `FYS`, `SPLACES`, `LMONTH`, `seasonMonth`, `seasonYear`, `setLMonth`, `syncSeasonUi`, `openSeason`, `fillSeason`, `seasonSel`; `Layers.parse/toggle/keptText/openIn/tagFor/seasonMonthLabel`; `Links.read().layers/spot/season`.
