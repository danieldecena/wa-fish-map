const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const dir = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
const between = (a, b) => { const i = html.indexOf(a), j = html.indexOf(b, i); assert.ok(i >= 0 && j > i, `${a} .. ${b}`); return html.slice(i, j); };
const focusCss = between('<style id="focus-css">', '</style>');

test('marine focus: the focus state gains a kind and both kinds share one set of rules', () => {
  assert.match(html, /var wf = null;[^\n]*\{ kind: 'river' \| 'area', id, rep, ids, list, prev \}/);
  const enter = between('function enterWater(id, rep, defer, kind) {', 'var fhl = null;');
  assert.match(enter, /kind = kind \|\| 'river';/);
  assert.match(enter, /if \(first\) wf = \{ prev: \{ s: v\.s, tx: v\.tx, ty: v\.ty \}, need: false \};/, 'the camera is stored once, whichever kind comes first');
  assert.match(enter, /area \? areaSites\(id\) : waterSites\(id\)/);
  assert.match(enter, /'Focused on ' \+ areaName\(id\) \+ ', ' \+ areaTitle\(id\) \+ ', ' \+ \(n === 0 \? 'no piers or launches' : n === 1 \? '1 pier or launch' : n \+ ' piers and launches'\) \+ '\. Press Escape to leave\.'/);
  // Leaving, the sharp layer and the marks are the same code for both kinds.
  assert.match(between('function leaveWater(restore) {', 'var focusMarked'), /rsel\.style\.display = 'none'; asel\.style\.display = 'none';/);
  assert.match(html, /function wfName\(w\) \{ return w\.kind === 'area' \? areaName\(w\.id\) : TAPBY\[w\.id\]\.name; \}/);
  assert.match(html, /function backToWater\(\) \{[\s\S]*?if \(wf\.kind === 'area'\) openArea\(id\);[\s\S]*?fitWater\(\);/);
});

test('marine focus: a tap on open water opens the area, under every marker and river', () => {
  // The hit polygons are in #vp (inside #base, under #over) after the faded rivers and before the rivers' own hit paths.
  const code = between("var ABY = {};", "var TAPBY = {};");
  assert.match(code, /el\('g', \{ id: 'atap' \}, vp\)/);
  assert.match(code, /el\('path', \{ d: ABY\[id\]\.d, 'data-area': id \}, atap\)/);
  assert.match(code, /abox\(MARINE_AREAS\[b\]\) - abox\(MARINE_AREAS\[a\]\)/, 'larger outlines first, so the smaller one is on top where two overlap');
  assert.ok(html.indexOf("var ABY = {};") > html.indexOf("Object.keys(D.base).forEach") && html.indexOf("var ABY = {};") < html.indexOf("var rtap = el('g', { id: 'rtap' }, vp);"), 'rivers drawn first, river hit paths after');
  assert.match(focusCss, /#atap path \{ fill: transparent; fill-rule: evenodd; pointer-events: fill; \}/);
  assert.match(focusCss, /#map:not\(\.drag\) #atap path \{ cursor: pointer; \}/);
  // tap(): markers and pins first, then the rivers, then the water, then the empty-map close.
  const tap = between('function tap(tgt, cx, cy) {', 'function zoomToCluster');
  const at = k => tap.indexOf(k);
  assert.ok(at("closest('[data-id],[data-cluster]')") < at("closest('[data-river]')") && at("closest('[data-river]')") < at("closest('[data-area]')") && at("closest('[data-area]')") < at("closeSheet()"));
  assert.match(tap, /if \(ar\) \{ openArea\(ar\.getAttribute\('data-area'\)\); return; \}/);
  // A site whose area has no outline is not an error: it is simply not in any area.
  assert.match(html, /return a && Object\.prototype\.hasOwnProperty\.call\(ABY, a\) \? a : null;/);
  assert.match(html, /if \(t\.site\.area && ABY\[t\.site\.area\]\)/);
});

test('marine focus: a pier, launch or shore site of an area enters the focus and keeps its own sheet', () => {
  const os = between('function openSheet(id) {', '/* ---- spot guide sheet');
  assert.match(os, /aid = !wid && view === 'typical' \? areaOfSite\(id\) : null/, 'freshwater sites (no area) and river launches never enter area focus');
  assert.match(os, /else if \(aid\) enterWater\(aid, null, true, 'area'\);/);
  assert.match(os, /if \(aid\) \{ render\(\); enterWater\(aid, null, false, 'area'\); syncLink\(\); return; \}/);
  const oa = between('function openAccess(id) {', '/* ---- Seasons layer');
  assert.match(oa, /aid = !wid \? areaOfSite\(id\) : null/);
  assert.match(oa, /if \(!wid && !aid\) leaveWater\(false\);/, 'moving between sites of one area never leaves and re-enters, so the stored camera is kept');
  assert.match(oa, /else if \(aid\) enterWater\(aid, null, false, 'area'\);/);
  // The site's sheets carry the way back and the other sites of the area.
  assert.match(between('function fillTypical(id) {', 'function riverRulesHtml'), /wfBackHtml\(id\) \+ head[\s\S]*creelSiteHtml\(id\) \+ areaSitesHtml\(id\)/);
  assert.match(between('function fillAccess(id) {', 'function openAccess'), /wfBackHtml\(id\)[\s\S]*creelSiteHtml\(t\.id\) \+ areaSitesHtml\(t\.id\)/);
  const as = between('function areaSitesHtml(id) {', 'function wfBackHtml');
  assert.match(as, /<h3>In ' \+ esc\(areaName\(wf\.id\)\) \+ '<\/h3>/);
  assert.match(as, /siteRowsHtml\(wf\.list, id\)/, 'the open site is left out of the list');
});

test('marine focus: the area card', () => {
  const card = between('function fillArea(id) {', 'function openArea(id) {');
  assert.match(card, /\$\('#stitle'\)\.textContent = areaName\(id\);/);
  assert.match(card, /'<div class="head"><p>' \+ esc\(areaTitle\(id\)\) \+ '<\/p><p>' \+ esc\(areaCountText\(list\)\) \+ '<\/p><\/div>'/);
  assert.match(card, /<h3>In season now<\/h3><p class="miss">' \+ TYPICAL_LINE/, 'the honesty line stays with the rows');
  // The rows are the page's own: Season.siteRows on the area's guide, the compact species rows; no new rating logic.
  assert.match(card, /g\.scope === 'area:' \+ id/);
  assert.match(card, /Season\.siteRows\(prep, \{ guide: gi \}, MONTH\)/);
  assert.match(card, /timingBodyHtml\(now, neutral\)/);
  assert.doesNotMatch(card, /speciesRating|areaRating|breadthRating|bestMonths/);
  assert.match(card, /tidesHtml\(\{ area: id \}, \{ ll: unxy\(a\.centroid\[0\], a\.centroid\[1\]\) \}\)/, 'the nearest NOAA station to the centroid, through the existing helper');
  assert.match(card, /<h3>Piers and launches in this area \(' \+ list\.length \+ '\)<\/h3>/);
  assert.match(card, /<h3>Before you go<\/h3>/);
  assert.match(card, /typicalFootHtml\(\)/, 'the WDFW link and the honesty text');
  assert.match(card, /wdfw\.wa\.gov\/fishing\/regulations/);
  // No source label or link: only the WDFW rules link that every sheet has.
  assert.doesNotMatch(card, /220-311|\.wac|boundar/i);
  // Outside Typical season the rating is a word in a plain chip, so colours of the two modes never share a view.
  assert.match(card, /neutral = view !== 'typical'/);
  assert.match(between('function spRowHtml(r, neutral) {', 'function timingBodyHtml'), /neutral \? '<span class="chip">' \+ Season\.LABEL\[r\.r\] \+ '<\/span>' : '<span class="badge"/);
  // It re-reads when the species changes.
  assert.match(html, /else if \(mode === 'area'\) fillArea\(areaSel\);/);
});

test('marine focus: the species rows are shared with the site sheet, not copied', () => {
  assert.match(between('function fillTypical(id) {', 'function riverRulesHtml'), /var body = timingBodyHtml\(rows\);/);
  assert.equal((html.match(/function spRowHtml\(/g) || []).length, 1);
});

test('marine focus: the sentences', () => {
  const src = between('function plural(n, one, many)', 'function fillArea(id) {');
  const areaCountText = new Function(src + '; return areaCountText;')();
  assert.equal(areaCountText([{ kind: 'pier' }, { kind: 'pier' }, { kind: 'launch' }, { kind: 'access' }]), '2 piers, 1 boat launch, 1 shore access site');
  assert.equal(areaCountText([{ kind: 'pier' }]), '1 pier');
  assert.equal(areaCountText([]), 'No piers, launches or shore access sites on this map');
});

test('marine focus: the outline is accent on a halo over a very faint fill, in the sharp layer, never a rating colour', () => {
  assert.match(html, /var asel = el\('g', \{ id: 'asel' \}, fvp\);/);
  assert.match(focusCss, /#asel \.fill \{ fill: var\(--wf-area-fill\);/);
  assert.match(focusCss, /#asel \.casing \{[^}]*stroke: var\(--halo\)/);
  assert.match(focusCss, /#asel \.line \{[^}]*stroke: var\(--wf-area-line\)/);
  const fill = +/--wf-area-fill: rgba\(\d+,\d+,\d+,([\d.]+)\)/.exec(focusCss)[1];
  assert.ok(fill > 0 && fill <= 0.12, `a very faint fill (${fill})`);
  const area = focusCss.slice(focusCss.indexOf('#atap path'), focusCss.indexOf('.wfback'));
  assert.doesNotMatch(area, /var\(--(prime|good|fair|slow|unrated)\)/, 'no rating colour');
  // It shares the dim, blur, reduced-motion and reduced-transparency rules of river focus: nothing area-specific changes a filter or a transition.
  assert.doesNotMatch(focusCss, /#asel[^{]*\{[^}]*(filter|transition)/);
});

test('marine focus: in focus a site may keep its name before its word, and focused labels are placed first', () => {
  assert.match(html, /if \(typ\) \{\s*pn\.cands = \[tLabel\(p\.s\), tShort\(p\.s\)\];[^}]*if \(wf && wf\.kind === 'area' && wf\.ids\[p\.s\.id\]\) pn\.cands = \[tLabel\(p\.s\), p\.s\.name, tShort\(p\.s\)\];\s*\}\s*else pn\.cands = \[spLabel/, 'the Spawning label branch is still an else of the Typical one');
  assert.match(html, /\(!!wf && !!wf\.ids\[b\[0\]\.s\.id\]\) - \(!!wf && !!wf\.ids\[a\[0\]\.s\.id\]\)/);
});

test('marine focus: the camera fits the whole area, uncapped (a river keeps its cap), phones above a 42 percent card', () => {
  assert.match(between('function waterBox(id, kind) {', 'function fitWater'), /if \(kind === 'area'\) return ABY\[id\]\.bbox;/);
  assert.match(focusCss, /@media \(max-width: 759px\) \{ #app\.focus-water #sheet \{ max-height: min\(42vh, 360px\); \} \}/);
});

test('marine focus adds no URL key and no request, and writes no river id', () => {
  const Links = require('../links.js');
  assert.deepEqual(Links.KEYS.reports, ['species', 'river']);
  assert.deepEqual(Links.KEYS.typical, ['species', 'site']);
  assert.match(html, /river: rep \? \(wf && wf\.kind === 'river' \?/);
  const code = between('/* ---- water focus', 'function openRiver(id) {');
  assert.doesNotMatch(code, /\bfetch\s*\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|\bimport\s*\(/);
  assert.doesNotMatch(code, /pushState|location\.search\s*=/);
});
