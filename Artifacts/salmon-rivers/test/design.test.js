const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');

// Token blocks as written in index.html: the light :root, the dark block under prefers-color-scheme, and the dark block forced by data-theme.
function block(open) {
  const i = html.indexOf(open);
  assert.ok(i >= 0, `no ${open} block`);
  let depth = 0, j = html.indexOf('{', i);
  const start = j;
  for (; j < html.length; j++) {
    if (html[j] === '{') depth++;
    else if (html[j] === '}' && --depth === 0) break;
  }
  return html.slice(start, j);
}
function tokens(text) {
  const o = {};
  for (const m of text.matchAll(/(--[a-z0-9-]+):\s*([^;]+);/g)) o[m[1]] = m[2].trim();
  return o;
}
const light = tokens(block(':root {\n  --ground'));
const darkMedia = tokens(block('  :root:not([data-theme="light"]) {'));
const darkForced = tokens(block(':root[data-theme="dark"] {'));

// The app draws the system ramp: DS.Rating in WAFishMap/DesignSystem.swift is Color.red, orange, yellow, blue, gray, and
// FishingRating.color reads it (WAFishMap/ColorRamp.swift). Hex values are what those resolve to on iOS 26, as the design system's
// tokens.json lists them under rating-*: they reproduce the six adjacent-stop lightness gaps RampLightnessTests measured on device,
// which the iOS 18 values (#ff3b30 and friends) did not. Gray is Apple's published value, not measured.
const RAMP = {
  '--prime': ['#ff383c', '#ff4245'],
  '--good': ['#ff8d28', '#ff9230'],
  '--fair': ['#ffcc00', '#ffd600'],
  '--slow': ['#0088ff', '#0091ff'],
  '--unrated': ['#8e8e93', '#8e8e93']
};

test('the page draws the app rating ramp in both appearances', () => {
  for (const [name, [l, d]] of Object.entries(RAMP)) {
    assert.equal(light[name], l, `${name} light`);
    assert.equal(darkForced[name] || light[name], d, `${name} dark`);
    assert.equal(darkMedia[name] || light[name], d, `${name} dark (media query)`);
  }
});

test('the app source still draws the ramp from DS.Rating (the claim the table above rests on)', () => {
  const repo = path.join(__dirname, '..', '..', '..');
  const ramp = fs.readFileSync(path.join(repo, 'WAFishMap/ColorRamp.swift'), 'utf8');
  for (const [swift, r] of [['slow', 'poor'], ['fair', 'fair'], ['good', 'good'], ['prime', 'excellent']]) {
    assert.match(ramp, new RegExp(`case \\.${r}: DS\\.Rating\\.${swift}\\b`), `${r} -> DS.Rating.${swift}`);
  }
  const ds = fs.readFileSync(path.join(repo, 'WAFishMap/DesignSystem.swift'), 'utf8');
  for (const [k, c] of [['slow', 'blue'], ['fair', 'yellow'], ['good', 'orange'], ['prime', 'red'], ['unrated', 'gray']]) {
    assert.match(ds, new RegExp(`static let ${k} = Color\\.${c}\\b`), `DS.Rating.${k} = Color.${c}`);
  }
});

test('the two dark blocks agree token for token', () => {
  assert.deepEqual(darkMedia, Object.fromEntries(Object.entries(darkForced).filter(([k]) => k !== 'color-scheme' && k in darkMedia)));
  for (const k of Object.keys(darkForced)) assert.ok(k in darkMedia, `${k} is only in the forced dark block`);
});

test('glass card and legend follow the design system spacing', () => {
  // GlassCard: inset 8 px compact, 12 px regular. The controls are one thin row (56 px, capped at 900 px since the Key button joined the bar).
  assert.match(html, /#chrome \{[^}]*padding-block: 8px;[^}]*padding-left: max\(8px/s);
  assert.match(html, /@media \(min-width: 760px\) \{\s*#chrome \{ padding-block: 12px; padding-left: max\(12px/);
  assert.match(html, /\.barstack \{[^}]*max-width: 900px;/);
  assert.match(html, /\.bar \{[^}]*height: 56px; padding: 6px 8px; display: flex; flex-direction: row;/);
  // RatingLegend: 8 px dot, 3 px to the label, entries 10 px apart.
  assert.match(html, /\.legend i \{ width: 8px; height: 8px;/);
  assert.match(html, /\.legend li \{[^}]*gap: 3px;/);
  assert.match(html, /\.legend ul \{[^}]*gap: 4px 10px;/);
  // The rating badge keeps one padding everywhere (5 px 10 px), including inside a species row.
  assert.match(html, /\.badge \{[^}]*padding: 5px 10px;/);
  assert.doesNotMatch(html, /\.row \.badge \{/);
});

// ---- colour-blindness: colour is never the only carrier of a rating ----

// Machado et al. 2009, severity 1.0, applied in linear RGB: the same simulation the browser check used (an SVG feColorMatrix filter).
const MACHADO = {
  deuteranopia: [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
  protanopia: [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
};
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lin = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const gam = c => { c = Math.min(1, Math.max(0, c)); return 255 * (c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055); };
const simulate = (rgb, kind) => { const l = rgb.map(lin); return MACHADO[kind].map(r => gam(r[0] * l[0] + r[1] * l[1] + r[2] * l[2])); };
const Lstar = rgb => { const l = rgb.map(lin); const y = 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]; return y > 0.008856 ? 116 * Math.cbrt(y) - 16 : 903.3 * y; };
const dL = (a, b, kind, theme) => {
  const c = n => (kind ? simulate(hex((theme === 'dark' ? darkForced[n] || light[n] : light[n])), kind) : hex(theme === 'dark' ? darkForced[n] || light[n] : light[n]));
  return Math.abs(Lstar(c(a)) - Lstar(c(b)));
};
const lab = rgb => {
  const [r, g, b] = rgb.map(lin);
  const f = t => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const x = f((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047), y = f(0.2126729 * r + 0.7151522 * g + 0.072175 * b), z = f((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / 1.08883);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
};
const dE = (a, b, kind, theme) => {
  const c = n => lab(simulate(hex(theme === 'dark' ? darkForced[n] || light[n] : light[n]), kind));
  const p = c(a), q = c(b);
  return Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
};
// The app's own gates (RampLightnessTests, CVDSeparationTests): 12 L* between adjacent stops, and a pair simulated for colour blindness
// fails only when it is under 12 L* AND under 30 dE76 AND both pins carry the same glyph ink.
const GATE = 12, DE_GATE = 30;
// The page's glyph rule, read from its source: which ratings draw dark ink on the balloon instead of white.
const inkRule = html.match(/function glyphColor\(r\) \{ return r === '(\w+)' \|\| r === '(\w+)' \? 'rgba\(0,0,0,0\.72\)' : '#fff'; \}/);
const darkInk = new Set(inkRule ? [inkRule[1], inkRule[2]] : []);
const inkDiffers = (a, b) => darkInk.has(a) !== darkInk.has(b);

test('adjacent ratings stay apart under simulated deuteranopia and protanopia, by lightness, colour or glyph ink', () => {
  assert.ok(inkRule, 'glyphColor no longer has the shape this test reads');
  for (const theme of ['light', 'dark']) for (const kind of ['deuteranopia', 'protanopia']) {
    for (const [a, b] of [['prime', 'good'], ['good', 'fair'], ['fair', 'slow']]) {
      const l = dL('--' + a, '--' + b, kind, theme), e = dE('--' + a, '--' + b, kind, theme);
      assert.ok(l >= GATE || e >= DE_GATE || inkDiffers(a, b), `${a} vs ${b}, ${kind}, ${theme}: dL* ${l.toFixed(1)}, dE ${e.toFixed(1)}, same ink`);
    }
  }
});

test('control: the colour check can fail, and the pair it fails is carried by ink (red vs orange under deuteranopia)', () => {
  // Measured the same in the app on device (CVDSeparationTests, 2026-10-06): dL* 11.1 in both appearances, dE76 19.5 light / 21.1 dark.
  // White ink on red and dark ink on orange is what separates them, here as in the app.
  for (const theme of ['light', 'dark']) {
    assert.ok(dL('--prime', '--good', 'deuteranopia', theme) < GATE && dE('--prime', '--good', 'deuteranopia', theme) < DE_GATE, theme);
  }
  assert.ok(inkDiffers('prime', 'good'), 'red and orange pins carry different ink');
  assert.ok(!inkDiffers('good', 'fair'), 'orange and yellow share ink: the ink check is not always true');
  assert.ok(dL('--prime', '--slow', null, 'light') < GATE, 'control: red and blue are the same lightness in the app ramp, hue alone apart');
});

test('every rating has its own word for a pin label, and a single pin falls back to it', () => {
  const S = require('../season.js');
  const words = Object.keys(S.RANK).map(k => S.SHORT[k]);
  assert.equal(words.length, 5);
  assert.ok(words.every(w => typeof w === 'string' && w.length > 0 && w.length <= 8), words.join());
  assert.equal(new Set(words).size, words.length, 'two ratings share a label word');
  for (const t of S.TOKEN) assert.equal(S.SHORT[t], S.LABEL[t], `${t}: the short word is the rating word`);
  assert.match(html, /pn\.cands = \[tLabel\(p\.s\), tShort\(p\.s\)\];/, 'Typical pins offer the full label, then the rating word');
  assert.match(html, /function tShort\(t\) \{ return Season\.SHORT\[t\.vw\.r\]; \}/);
});

// ---- the neutral cluster token ----

const over = (fg, a, bg) => fg.map((c, i) => c * a + bg[i] * (1 - a));
const contrast = (a, b) => { const y = rgb => { const l = rgb.map(lin); return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]; }; const p = y(a), q = y(b); return (Math.max(p, q) + 0.05) / (Math.min(p, q) + 0.05); };
const rgbaOf = v => { const m = /rgba\((\d+),(\d+),(\d+),([\d.]+)\)/.exec(v.replace(/\s/g, '')); return { rgb: [+m[1], +m[2], +m[3]], a: +m[4] }; };

test('--cluster is a neutral token in both themes and cannot be mistaken for a rating', () => {
  const dark = { ...light, ...darkForced };
  for (const [theme, t] of [['light', light], ['dark', dark]]) {
    assert.match(t['--cluster'], /^#[0-9a-f]{6}$/, `${theme} --cluster`);
    const [r, g, b] = hex(t['--cluster']);
    assert.ok(Math.max(r, g, b) - Math.min(r, g, b) <= 4, `${theme} --cluster is a neutral (no hue)`);
    for (const k of Object.keys(RAMP)) assert.notEqual(t['--cluster'], t[k], `${theme} --cluster equals ${k}`);
    const ground = hex(t['--ground']);
    // The number reads on the fill, and the ring (pin-edge) separates the fill from the ground, at the 4.5:1 text and 3:1 graphic floors.
    assert.ok(contrast(hex(t['--ink']), hex(t['--cluster'])) >= 4.5, `${theme} ink on cluster`);
    const ring = rgbaOf(t['--pin-edge']);
    assert.ok(contrast(over(ring.rgb, ring.a, ground), ground) >= 3, `${theme} ring on ground`);
  }
  assert.notEqual(light['--cluster'], darkForced['--cluster'], 'the token has a light and a dark value');
});

test('neutral cluster styling and its legend entry exist, and no rating colour is applied to a neutral cluster', () => {
  assert.match(html, /\.cluster\.neutral text \{ fill: var\(--ink\); \}/);
  assert.equal((html.match(/Count: several sites/g) || []).length, 3, 'one legend entry in the page and one in each mode switch string');
  assert.match(html, /\.legend li\.cl i \{ box-shadow: inset 0 0 0 1px var\(--pin-edge\); \}/);
});

// ---- land tint, state outline and text size ----

test('--land and --state-line are neutral tokens in both themes: a very light tint with a readable outline', () => {
  const dark = { ...light, ...darkForced };
  for (const [theme, t] of [['light', light], ['dark', dark]]) {
    const ground = hex(t['--ground']), landRgb = hex(t['--land']);
    assert.match(t['--land'], /^#[0-9a-f]{6}$/, `${theme} --land`);
    assert.ok(Math.max(...landRgb) - Math.min(...landRgb) <= 4, `${theme} --land is a neutral (no hue)`);
    // Visible, but only just: between 1 and 6 L* from the ground.
    const step = Math.abs(Lstar(landRgb) - Lstar(ground));
    assert.ok(step >= 1 && step <= 6, `${theme} land is ${step.toFixed(1)} L* from the ground`);
    for (const k of Object.keys(RAMP)) assert.notEqual(t['--land'], t[k]);
    const line = rgbaOf(t['--state-line']);
    assert.ok(contrast(over(line.rgb, line.a, landRgb), landRgb) >= 3, `${theme} outline on land is under 3:1`);
    assert.ok(contrast(over(line.rgb, line.a, ground), ground) >= 3, `${theme} outline on ground is under 3:1`);
  }
  assert.notEqual(light['--land'], darkForced['--land'], 'the token has a light and a dark value');
  // Control: the same check rejects a tint that is too strong and one that is invisible.
  assert.ok(Math.abs(Lstar(hex('#d8d8dc')) - Lstar(hex('#f2f2f7'))) > 6);
  assert.ok(Math.abs(Lstar(hex('#f2f2f7')) - Lstar(hex('#f2f2f7'))) < 1);
});

// The legend is Apple's Footnote style (13/18, HIG typography), one step up from 12 px so it reads outdoors.
test('legend, footer and sheet fine print are at least 12 px; only text drawn on the map is smaller', () => {
  const css = html.slice(html.indexOf('<style>'), html.indexOf('</style>'));
  const small = [];
  for (const m of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    const px = /font-size:\s*(\d+(?:\.\d+)?)px/.exec(m[2]) || /font:\s*[\w-]*\s*(\d+(?:\.\d+)?)px/.exec(m[2]);
    if (px && +px[1] < 12) small.push(m[1].trim().replace(/\s+/g, ' ') + ' ' + px[1] + 'px');
  }
  // Map labels, the count inside a cluster mark or a grouped guide pin, a creel-count badge and a season tag follow the design system's mapLabel
  // and clusterCount roles (11 px); the region name is a watermark.
  assert.deepEqual(small.sort(), ['.cbadge text 11px', '.cluster text 11px', '.lab 11px', '.lab.region 10px', '.spotgrp .n text 11px', '.stag text 11px']);
  assert.match(css, /\.legend li \{[^}]*font-size: 13px/);
  assert.match(css, /\.legend \.fine \{[^}]*font-size: 13px/);
  assert.match(css, /\.legend \.lt \{[^}]*font-size: 13px/);
  assert.match(css, /\.foot \{[^}]*font-size: 12px/);
});

test('the map under the empty part of the bottom row takes taps and drags', () => {
  assert.match(html, /#chrome > \.bottom \{ pointer-events: none; \}/);
  assert.match(html, /\.bottom > \* \{ pointer-events: auto; \}/);
});
