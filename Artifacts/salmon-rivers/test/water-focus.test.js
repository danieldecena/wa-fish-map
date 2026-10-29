const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const dir = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
const between = (a, b) => { const i = html.indexOf(a), j = html.indexOf(b, i); assert.ok(i >= 0 && j > i, `${a} .. ${b}`); return html.slice(i, j); };
const focusCss = between('<style id="focus-css">', '</style>');

test('water focus: the sharp layer sits between the blurred base and the markers', () => {
  const map = between('<div id="map"', '<div id="chrome">');
  const order = ['id="base"', 'id="heat"', 'id="wfscrim"', 'id="focus"', 'id="over"', 'id="guides"'].map(k => map.indexOf(k));
  assert.ok(order.every(i => i >= 0), 'all six layers exist');
  assert.deepEqual(order.slice().sort((a, b) => a - b), order, 'base, heat, scrim, focus, over, guides in paint order');
  // The selected river is drawn in the focus layer, not inside #base (a filter on #base would blur it too).
  assert.match(html, /var fvp = \$\('#fvp'\);[\s\S]*?var rsel = el\('g', \{ id: 'rsel' \}, fvp\);/);
  assert.match(html, /var asel = el\('g', \{ id: 'asel' \}, fvp\);/, 'a marine area outline is drawn in the same sharp layer');
  assert.match(html, /fvp\.setAttribute\('transform', vp\.getAttribute\('transform'\)\);/, 'the focus layer follows the camera');
});

test('water focus: blur and dim animate together over --dur-base, with reduced motion and reduced transparency guarded', () => {
  const dim = +/--wf-dim: ([\d.]+)/.exec(focusCss)[1], blur = parseFloat(/--wf-blur: ([\d.]+)px/.exec(focusCss)[1]);
  assert.ok(dim <= 0.35, 'non-focus markers dim to at most .35');
  assert.ok(blur >= 3 && blur <= 4, `base blur is 3 to 4 px (${blur})`);
  const i0 = focusCss.indexOf('@media (prefers-reduced-motion: no-preference) {'), motion = focusCss.slice(i0, focusCss.indexOf('/* Touch screens'));
  assert.ok(i0 >= 0 && motion.length > 50, 'the focus block has its own no-preference rules');
  assert.match(motion, /#wfscrim, #over > \*, #guides > \* \{ transition: opacity var\(--dur-base\) var\(--ease-out\), filter var\(--dur-base\) var\(--ease-out\); \}/);
  assert.match(motion, /#app\.focus-water #base \{ filter: blur\(var\(--wf-blur\)\); \}/);
  // No blur rule exists outside the no-preference block, so reduced motion gets the dim at once and no blur.
  const outside = focusCss.replace(motion, '');
  assert.doesNotMatch(outside.replace(/filter: none;/g, '').replace(/filter: blur\(2\.5px\);/g, ''), /filter: blur/, 'blur only inside the no-preference block');
  assert.match(focusCss, /@media \(prefers-reduced-transparency: reduce\) \{[^}]*#app\.focus-water #base[^}]*filter: none;/);
  // Touch screens blur two layers and dim the markers.
  assert.match(focusCss, /@media \(pointer: coarse\) \{[^}]*#over > :not\(\.infocus\)[^}]*filter: none;/);
  // The sharp things are exactly the ones marked .infocus; the dim never touches them.
  assert.match(focusCss, /#app\.focus-water #over > :not\(\.infocus\), #app\.focus-water #guides > :not\(\.infocus\) \{ opacity: var\(--wf-dim\); \}/);
  assert.doesNotMatch(focusCss, /--(prime|good|fair|slow|unrated)\s*:/, 'no rating colour is touched');
});

test('water focus: how it starts, ends and where the camera goes', () => {
  const mod = between('/* ---- water focus', 'function openWaterSite');
  // The camera is stored once, on the first entry, and restored on leaving.
  assert.match(mod, /if \(first\) wf = \{ prev: \{ s: v\.s, tx: v\.tx, ty: v\.ty \}, need: false \};/);
  assert.match(mod, /var changed = first \|\| wf\.id !== id \|\| wf\.kind !== kind;/, 'moving between a river and an area keeps the stored camera');
  assert.match(mod, /if \(restore\) animateTo\(\{ s: w\.prev\.s, tx: w\.prev\.tx, ty: w\.prev\.ty \}\);/);
  // 12 percent padding each side, never closer than 8 times the opening scale, never past the state floor.
  assert.match(mod, /var cap = wf\.kind === 'area' \? maxS : 8 \* s0;\s*var s = Math\.max\(minS, Math\.min\(Math\.min\(aw \/ \(w \* 1\.24\), ah \/ \(h \* 1\.24\)\), cap\)\);/);
  assert.match(mod, /if \(window\.innerWidth < 760\) p\.b = Math\.max\(p\.b, Math\.min\(sheet\.getBoundingClientRect\(\)\.height \|\| 0, H \* 0\.66\) \+ 8\);/, 'phones fit above the sheet');
  // Announced through a polite live region.
  assert.match(html, /<div class="sr" id="wfsay" role="status" aria-live="polite"><\/div>/);
  assert.match(mod, /'Focused on ' \+ r\.name \+ ', ' \+ n \+ \(n === 1 \? ' access site' : ' access sites'\) \+ '\. Press Escape to leave\.'/);
  assert.match(mod, /say\('Left focus on ' \+ name \+ '\.'\);/);
  // Done, Escape and a tap on empty map all end in closeSheet, which leaves the focus and restores the camera.
  assert.match(between('function closeSheet() {', 'function currentRef'), /clearRiver\(\); leaveWater\(true\);/);
  assert.match(html, /if \(mode\) closeSheet\(\);\s*\}\);/, 'Escape still closes the sheet');
  assert.match(html, /if \(\$\('#sheet'\)\.classList\.contains\('open'\)\) closeSheet\(\);/, 'a tap on empty map closes it');
  // Entering: a river tap, a report pin or list row (openSheet), a launch or shore site (openSheet in Typical season, openAccess).
  assert.match(between('function openRiver(id) {', 'var returnFocus'), /enterWater\(id, null\);/);
  assert.match(between('function openSheet(id) {', '/* ---- spot guide sheet'), /enterWater\(wid, view === 'reports' \? id : null/);
  assert.match(between('function openSheet(id) {', '/* ---- spot guide sheet'), /enterWater\(aid, null, false, 'area'\)/);
  assert.match(between('function openAccess(id) {', '/* ---- Seasons layer'), /enterWater\(wid, /);
  // Opening anything that is not on the river ends the focus.
  assert.match(html, /if \(wid\) enterWater\(wid, view === 'reports' \? id : null, true\);\s*else if \(aid\) enterWater\(aid, null, true, 'area'\);\s*else leaveWater\(false\);/);
  assert.match(html, /function openList\(\) \{\s*clearRiver\(\); leaveWater\(true\);/);
});

test('water focus: the card lists the access sites and a launch sheet offers the way back', () => {
  const acc = between('function accessHtml(id) {', 'function wfBackHtml');
  assert.match(acc, /'<section class="wfacc"><h3>Access on this river \(' \+ list\.length \+ '\)<\/h3>/);
  assert.match(acc, /data-wfsite="/);
  assert.match(acc, /Season\.KIND_LABEL\[t\.kind\] \+ word/, 'the kind label, as the app words it');
  assert.match(acc, /var typ = view === 'typical';[\s\S]*word = typ \?/, 'a rating word only where the page already shows one');
  assert.match(between('function wfBackHtml(id) {', 'function say'), /Back to ' \+ esc\(wfName\(wf\)\)/);
  // Both river cards carry the section; the launch sheets carry the button.
  assert.match(between('function fillRiver(id) {', 'Spawning: month ribbon'), /accessHtml\(id\)/);
  assert.match(between('function fillSheet(id) {', 'river sheet (Recent reports)'), /accessHtml\(wid\)/);
  assert.match(between('function fillTypical(id) {', 'function riverRulesHtml'), /wfBackHtml\(id\) \+ head/);
  assert.match(between('function fillAccess(id) {', 'function openAccess'), /wfBackHtml\(id\)/);
  assert.match(html, /if \(wfb\.hasAttribute\('data-wfback'\)\) backToWater\(\); else openWaterSite\(wfb\.getAttribute\('data-wfsite'\)\);/);
  assert.match(html, /'<p>Length ' \+ esc\(wlen\) \+ '<\/p>'/, 'the river length is in the header line');
});

test('water focus: lengthText words the length in km and miles, and says nothing without one', () => {
  const src = between('function lengthText(r) {', 'function accessHtml');
  const lengthText = new Function(src + '; return lengthText;')();
  assert.equal(lengthText({ lengthKm: 203.3 }), '203 km (126 mi)');
  assert.equal(lengthText({ lengthKm: 4.2 }), '4.2 km (2.6 mi)');
  assert.equal(lengthText({}), '');
  assert.equal(lengthText(null), '');
});

test('water focus: the launches on a river come from siteRiver, and the Cowlitz has five', () => {
  global.window = global;
  delete require.cache[require.resolve('../rivers-tap.js')];
  require('../rivers-tap.js');
  const T = global.RIVERTAP, ids = new Set(T.rivers.map(r => r.id));
  const per = {};
  Object.values(T.siteRiver).forEach(r => { per[r] = (per[r] || 0) + 1; });
  assert.equal(per['cowlitz-river'], 5);
  assert.ok(Object.keys(per).every(r => ids.has(r)), 'every mapped river is a tappable river');
  assert.equal(T.rivers.length, 434);
  assert.ok(T.rivers.every(r => typeof r.d === 'string' && /\d/.test(r.d)), 'every river has a path to fit');
});

test('water focus adds no URL key and no request', () => {
  const Links = require('../links.js');
  assert.deepEqual(Links.KEYS.reports, ['species', 'river']);
  assert.deepEqual(Links.KEYS.typical, ['species', 'site']);
  assert.equal(Links.read('?river=cowlitz').river, 'cowlitz');
  assert.match(html, /river: rep \? \(wf && wf\.kind === 'river' \? \(wf\.rep \|\| wf\.id\) : mode === 'detail' \? selected : riverSel\) : null,/, 'a river focus writes the river it is on, an area focus writes none');
  const code = focusCss + between('/* ---- water focus', 'function openWaterSite');
  assert.doesNotMatch(code, /fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|import\(/);
});
