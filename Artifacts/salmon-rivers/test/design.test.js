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
// FishingRating.color reads it (WAFishMap/ColorRamp.swift). Hex values are Apple's resolved systemRed, systemOrange, systemYellow,
// systemBlue and systemGray, as the design system's tokens.json lists them under rating-*-system.
const RAMP = {
  '--prime': ['#ff3b30', '#ff453a'],
  '--good': ['#ff9500', '#ff9f0a'],
  '--fair': ['#ffcc00', '#ffd60a'],
  '--slow': ['#007aff', '#0a84ff'],
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
  // GlassCard: inset 8 px compact, 12 px regular; padding 10 px vertical; capped at 460 px.
  assert.match(html, /#chrome \{[^}]*padding-block: 8px;[^}]*padding-left: max\(8px/s);
  assert.match(html, /@media \(min-width: 760px\) \{\s*#chrome \{ padding-block: 12px; padding-left: max\(12px/);
  assert.match(html, /\.bar \{[^}]*max-width: 460px; padding: 10px 12px;/);
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
// The app's own gate (RampLightnessTests) is a lightness step of 12 L* between adjacent ramp stops.
const GATE = 12;

test('red and orange stay apart under simulated deuteranopia and protanopia, in both themes', () => {
  for (const theme of ['light', 'dark']) for (const kind of ['deuteranopia', 'protanopia']) {
    const d = dL('--prime', '--good', kind, theme);
    assert.ok(d >= GATE, `prime vs good, ${kind}, ${theme}: dL* ${d.toFixed(1)} is under ${GATE}`);
  }
});

test('control: the lightness check can fail, and the weak pair is named (good vs fair under deuteranopia)', () => {
  // Orange and yellow collapse toward one hue under deuteranopia (the repo README says the same). That pair is under the app gate, so a
  // word on every pin is what separates them. If this stops being true the label may be reconsidered; until then it is the proof the check bites.
  for (const theme of ['light', 'dark']) assert.ok(dL('--good', '--fair', 'deuteranopia', theme) < GATE, theme);
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
