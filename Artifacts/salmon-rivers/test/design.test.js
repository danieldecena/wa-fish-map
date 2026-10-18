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
