const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const between = (a, b) => { const i = html.indexOf(a), j = html.indexOf(b, i); assert.ok(i >= 0 && j > i, `${a} .. ${b}`); return html.slice(i, j); };

const NO_PREF = /@media\s*\(\s*prefers-reduced-motion\s*:\s*no-preference\s*\)/;
const REDUCE = /@media\s*\(\s*prefers-reduced-motion\s*:\s*reduce\s*\)/;

// Every declaration or at-rule that moves something, with the at-rules it sits inside. Comments are dropped first; strings never hold braces here.
function motionRules(css) {
  const src = css.replace(/\/\*[\s\S]*?\*\//g, '');
  const out = [], stack = [];
  let buf = '';
  for (const ch of src) {
    if (ch === '{') {
      const head = buf.trim(); buf = '';
      stack.push(head);
      if (/^@keyframes\b/.test(head)) out.push({ kind: 'keyframes', text: head, stack: stack.slice(0, -1) });
    } else if (ch === '}' || ch === ';') {
      const decl = buf.trim(); buf = '';
      if (ch === ';' || (ch === '}' && decl)) {
        const m = decl.match(/^(transition(?:-[a-z-]+)?|animation(?:-[a-z-]+)?)\s*:\s*([^]*)$/);
        if (m) out.push({ kind: 'decl', text: decl, prop: m[1], value: m[2].trim(), stack: stack.slice() });
      }
      if (ch === '}') stack.pop();
    } else buf += ch;
  }
  return out;
}
const cssOf = h => [...h.matchAll(/<style[^>]*>([^]*?)<\/style>/g)].map(m => m[1]).join('\n');
// Allowed: inside the no-preference block, or a plain `none` inside the reduce block.
const guarded = r => r.stack.some(s => NO_PREF.test(s)) || (r.stack.some(s => REDUCE.test(s)) && r.kind === 'decl' && /^none$/.test(r.value));

test('the motion tokens match the Figma Motion collection', () => {
  const root = between(':root {', '\n}');
  const want = { '--dur-fast': '120ms', '--dur-base': '200ms', '--dur-slow': '280ms', '--dur-camera': '400ms', '--dur-pop': '160ms', '--dur-layer': '240ms', '--dur-pulse': '450ms',
    '--ease-out': 'cubic-bezier(.2,.8,.2,1)', '--ease-in': 'cubic-bezier(.4,0,1,1)', '--ease-inout': 'cubic-bezier(.65,0,.35,1)' };
  Object.keys(want).forEach(k => {
    const m = root.match(new RegExp(k.replace(/-/g, '\\-') + '\\s*:\\s*([^;]+);'));
    assert.ok(m, k + ' is declared on :root');
    assert.equal(m[1].replace(/\s+/g, ''), want[k].replace(/\s+/g, ''), k);
  });
  // The doc carries the same names, so the page and the Figma file cannot drift apart without one of them failing.
  const spec = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'docs', 'design', 'motion-spec.md'), 'utf8');
  Object.keys(want).forEach(k => assert.ok(spec.includes(k), k + ' is in docs/design/motion-spec.md'));
});

test('the detector finds motion and flags an unguarded rule (a check that cannot fail is not a check)', () => {
  const bad = motionRules('.a { transition: opacity .2s; } @keyframes x { from { opacity: 0 } }');
  assert.equal(bad.length, 2);
  assert.equal(bad.filter(r => !guarded(r)).length, 2, 'both unguarded rules are flagged');
  const good = motionRules('@media (prefers-reduced-motion: no-preference) { .a { transition: opacity .2s; } @keyframes x { from { opacity: 0 } } } @media (prefers-reduced-motion: reduce) { .a { transition: none; } }');
  assert.equal(good.length, 3);
  assert.equal(good.filter(r => !guarded(r)).length, 0, 'guarded rules and a reduce-block "none" pass');
  const loud = motionRules('@media (prefers-reduced-motion: reduce) { .a { transition: opacity .2s; } }');
  assert.equal(loud.filter(r => !guarded(r)).length, 1, 'a real transition inside the reduce block is still flagged');
});

test('every transition, animation and @keyframes rule sits in a no-preference block (or is "none" under reduce)', () => {
  const rules = motionRules(cssOf(html));
  assert.ok(rules.length >= 20, 'control: the detector sees the page\'s motion (' + rules.length + ' rules)');
  const unguarded = rules.filter(r => !guarded(r));
  assert.deepEqual(unguarded.map(r => r.text.slice(0, 80)), []);
  // The old guarantee stays: the sheet, the zoom controls and the switch knob are switched off under reduce.
  assert.match(html, /@media \(prefers-reduced-motion: reduce\) \{\s*#sheet, #sheet\.open, \.zoom \{ transition: none; \}\s*\.layrow \.sw::after \{ transition: none; \}/);
});

test('motion animates transform and opacity; only the disclosure height and the switch colour are the exceptions', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  const props = new Set();
  motionRules(block).filter(r => r.kind === 'decl' && r.prop === 'transition').forEach(r => r.value.split(',').forEach(part => { const p = part.trim().split(/\s+/)[0]; if (p) props.add(p); }));
  const extra = [...props].filter(p => !['none', 'transform', 'opacity', 'translate', 'height', 'content-visibility', 'background-color', 'visibility'].includes(p));
  assert.deepEqual(extra, [], 'no transition on top, left, width, margin or other layout properties');
  ['top', 'left', 'right', 'bottom', 'width', 'margin', 'padding'].forEach(p => assert.ok(!props.has(p), p));
  // Keyframes move only transform, scale, translate and opacity.
  const kf = [...block.matchAll(/@keyframes [\w-]+ \{([^]*?\})\s*\}/g)].map(m => m[1]).join('\n');
  assert.ok(kf.length > 40, 'control: keyframes were found');
  const keys = new Set([...kf.matchAll(/([a-z-]+)\s*:/g)].map(m => m[1]));
  assert.deepEqual([...keys].filter(k => !['opacity', 'transform', 'scale', 'translate'].includes(k)), []);
});

test('sheet: 280 ms ease/out in, 200 ms ease/in out, content rises 8 px on a 40 ms stagger', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /#sheet \{[^}]*transition: transform var\(--dur-base\) var\(--ease-in\), visibility 0s var\(--dur-base\);/);
  assert.match(block, /#sheet\.open \{[^}]*transition: transform var\(--dur-slow\) var\(--ease-out\);/);
  assert.match(block, /\.zoom \{ transition: transform var\(--dur-slow\) var\(--ease-out\); \}/);
  assert.match(block, /#sbody\.rise > \* \{ animation: rise var\(--dur-base\) var\(--ease-out\) backwards; animation-delay: calc\(80ms \+ var\(--i, 0\) \* 40ms\); \}/);
  assert.match(block, /@keyframes rise \{ from \{ opacity: 0; transform: translateY\(8px\); \} \}/);
  // The base rules no longer carry a transition of their own, so a reduced-motion user gets none.
  const base = between('#sheet {', '.sbar {');
  assert.doesNotMatch(base, /transition/);
  // Opening or swapping a sheet replays the rise once; the class comes off again so later re-renders stay still.
  const show = between('function showSheet', 'function openSheet');
  assert.match(show, /riseIn\(\);/);
  assert.match(between('function riseIn', 'function showSheet'), /classList\.remove\('rise'\)[^]*offsetWidth[^]*classList\.add\('rise'\)[^]*setTimeout\(function \(\) \{ b\.classList\.remove\('rise'\); \}, 600\)/);
});

test('popovers: one helper opens with a transition and closes on a copy, and all six panels use it', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /\.pop \{[^}]*transition: opacity var\(--dur-pop\) var\(--ease-out\), transform var\(--dur-pop\) var\(--ease-out\);[^}]*transform-origin: var\(--pop-ox, 0\) 0;/);
  assert.match(block, /@starting-style \{\s*\.pop \{ opacity: 0; transform: scale\(\.96\); \}\s*\}/);
  assert.match(block, /\.pop\.ghost \{[^}]*transition: none;[^}]*animation: pop-out var\(--dur-fast\) var\(--ease-in\) forwards;[^}]*pointer-events: none;/);
  assert.match(block, /@keyframes pop-out \{ to \{ opacity: 0; transform: scale\(\.96\); \} \}/);
  const fn = between('function setPop', 'function toggleNotice');
  assert.match(fn, /reduceMq\.matches/, 'the copy is skipped for a reduced-motion user, read when the panel closes');
  assert.match(fn, /removeAttribute\('id'\)/, 'the copy carries no ids');
  assert.match(fn, /inert/);
  [['npop', 'nbtn'], ['mpop', 'modebtn'], ['laypop', 'laybtn'], ['keypop', 'keybtn'], ['sppanel', 'spbtn'], ['mepanel', 'mebtn']].forEach(([p, b]) =>
    assert.match(html, new RegExp('setPop\\(' + p + ', ' + b + ', open\\);'), p + ' goes through setPop'));
  ['npop', 'mpop', 'laypop', 'keypop', 'sppanel', 'mepanel'].forEach(p => assert.doesNotMatch(html, new RegExp('\\b' + p + '\\.hidden = !open;'), p + ' no longer flips hidden itself'));
});

test('pin select: one ring pulse and a 2 px lift, on the selected pin only', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /\.pin\.sel \.ring \{ animation: pin-ring var\(--dur-pulse\) var\(--ease-out\); \}/);
  assert.match(block, /@keyframes pin-ring \{ from \{ opacity: 0\.6; scale: 0\.6; \} to \{ opacity: 0; scale: 1\.8; \} \}/);
  assert.match(block, /\.pin\.sel \.pin-s \{ translate: 0 -2px; transition: translate var\(--dur-pop\) var\(--ease-out\); \}/);
  assert.match(block, /\.pin \.pin-s \{ transition: translate var\(--dur-fast\) var\(--ease-in\); \}/);
  assert.match(html, /el\('circle', \{ 'class': 'ring', cx: 0, cy: -16, r: 13 \}, sc\);/);
  assert.match(html, /pn\.g\.classList\.toggle\('sel', p\.s\.id === selected\);/);
  assert.match(html, /\.pin \.ring \{ fill: none; stroke: var\(--on\); stroke-width: 2px; vector-effect: non-scaling-stroke; opacity: 0; pointer-events: none; transform-box: fill-box; transform-origin: center; \}/);
});

test('disclosures: height reveals on details::details-content, 200 ms in and 120 ms out', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /:root \{ interpolate-size: allow-keywords; \}/);
  assert.match(block, /details::details-content \{ height: 0; overflow: clip; transition: height var\(--dur-fast\) var\(--ease-in\), content-visibility var\(--dur-fast\) allow-discrete; \}/);
  assert.match(block, /details\[open\]::details-content \{ height: auto; overflow-clip-margin: 4px; transition: height var\(--dur-base\) var\(--ease-out\), content-visibility var\(--dur-base\) allow-discrete; \}/);
  assert.match(block, /details\.how > summary::after \{ transition: transform var\(--dur-base\) var\(--ease-out\); \}/);
});

test('heat circles and depth lines fade in, circles scale from .8 and stagger by distance to a 150 ms cap', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /#heat circle\.hin \{ transform-box: fill-box; transform-origin: center; animation: layer-in var\(--dur-layer\) var\(--ease-out\) backwards; \}/);
  assert.match(block, /@keyframes layer-in \{ from \{ opacity: 0; transform: scale\(\.8\); \} \}/);
  assert.match(block, /#depthg \{ animation: layer-fade var\(--dur-layer\) var\(--ease-out\) backwards; \}/);
  // Only a circle created while the layer turns on animates (the SVG was empty), not one that scrolls into view during a pan.
  const tick = between('function heatTick', 'function heatSection');
  assert.match(tick, /var entering = !svg\.firstChild;/);
  assert.match(tick, /if \(entering\) \{[^}]*classList\.add\('hin'\)[^}]*animationDelay = heatDelay\(x, y\)/);
  const fn = between('function heatDelay', 'function heatTick');
  const heatDelay = new vm.Script('(function (W, H) { ' + fn + ' return heatDelay; })').runInNewContext()(1000, 600);
  assert.equal(heatDelay(500, 300), '0ms', 'the centre has no delay');
  assert.equal(heatDelay(500 + 50, 300), '30ms', '30 ms per 50 px');
  assert.equal(heatDelay(0, 0), '150ms', 'capped');
  assert.equal(heatDelay(100000, 100000), '150ms', 'still capped far away');
});

test('the switch moves 160 ms ease/out, track colour and knob together', () => {
  const block = between('@media (prefers-reduced-motion: no-preference) {', '@media (prefers-reduced-motion: reduce) {');
  assert.match(block, /\.layrow \.sw \{ transition: background-color var\(--dur-pop\) var\(--ease-out\); \}/);
  assert.match(block, /\.layrow \.sw::after \{ transition: transform var\(--dur-pop\) var\(--ease-out\); \}/);
});

test('camera: ease-in-out cubic, 280 to 520 ms by distance, and a reduced-motion user still jumps', () => {
  const src = between('function camMs', 'function animateTo');
  const camMs = new vm.Script('(function () { ' + src + ' return camMs; })()').runInNewContext();
  const at = (ds, dx, dy) => camMs({ s: 1, tx: 0, ty: 0 }, { s: ds, tx: dx, ty: dy }, 1000, 600);
  assert.equal(at(1, 0, 0), 280, 'no travel is the floor');
  assert.equal(at(1, 100000, 100000), 520, 'a very long trip is the ceiling');
  const samples = [0, 40, 200, 800, 3000].map(d => at(1, d, 0));
  samples.forEach(ms => assert.ok(ms >= 280 && ms <= 520, ms + ' is inside 280-520'));
  assert.deepEqual(samples, [...samples].sort((a, b) => a - b), 'a longer trip never takes less time');
  assert.ok(new Set(samples).size >= 3, 'control: the duration really depends on the distance');
  assert.ok(at(2, -500, -300) > at(1, 0, 0), 'a pure zoom (same centre, one octave) counts as travel');
  const anim = between('function animateTo', 'function zoomAt');
  assert.match(anim, /if \(reduce\) \{ setView\(t\); return; \}/);
  assert.match(anim, /e = k < 0\.5 \? 4 \* k \* k \* k : 1 - Math\.pow\(-2 \* k \+ 2, 3\) \/ 2;/);
  assert.doesNotMatch(anim, /1 - Math\.pow\(1 - k, 3\)/, 'the ease-out cubic is gone');
  assert.doesNotMatch(html, /animateTo\([^;\n]*\}, \d+\)/, 'no caller still passes a fixed duration');
  assert.doesNotMatch(html, /animateTo\(homeFit\(\), \d+\)|animateTo\(f, \d+\)/);
});
