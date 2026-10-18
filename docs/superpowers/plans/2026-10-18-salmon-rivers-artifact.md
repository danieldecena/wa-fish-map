# Salmon Rivers Artifact Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the published "Washington Salmon Rivers" page honest about how old its catch reports are, readable without colour, and quick to scan, while keeping its source in this repo.

**Architecture:** The page is one static HTML file that today carries everything inline: a 428 KB map-geometry blob, the six river reports, the rating logic and the UI. Split it into `geo.js` (geometry, treated as data), `reports.js` (report data plus pure logic, unit-tested with Node's built-in test runner) and `index.html` (markup, CSS, DOM code). Then add dated reports with a freshness rule, fix the pin labels that never display and put a rating word and a visible edge on every pin, add a ranked river list, and fix sheet accessibility and contrast. A design critique of the live page (2026-10-18) added the label fix, the pin contrast work and the dark-mode teal and Directions changes.

**Tech Stack:** Plain HTML, CSS and ES5-style JavaScript (no framework, no build step, no dependencies), Node 20+ `node:test` for logic tests (host has Node 26), the Claude Browser pane for DOM checks, the `Artifact` tool for publishing.

**Spec:** None exists. The live page is the spec: https://claude.ai/artifact/9oA145toRsmFcDYurdJbey (version `1792352926-fede`, 2026-10-17 data). The product rules come from this repo's `CLAUDE.md` section "Not this app" and are restated in Global Constraints below. Behaviour to preserve is every visible behaviour of that version except the changes this plan lists.

## Global Constraints

Every task's requirements include these.

- No framework, no bundler, no npm dependencies, no network requests from the page at runtime (outbound links only, as today).
- Guidance, not regulation: the "Before you go" advisory, the WDFW rules link and the footer line "Recent catch reports, not season dates. Not for navigation or safety decisions." stay on every river sheet. A rating is a reading of recent catch reports, never a claim that a fishery is open.
- Never invent a report date or a fishing fact. A report whose source gives no date gets `asOf: null`, and the page says "Date not given".
- Report wording changes are limited to deleting dates that the new date chip now shows (for example "(Oct 15)"). Numbers and claims stay as published.
- Pure logic never reads the clock. `reports.js` functions take `today` as a `YYYY-MM-DD` string; only `index.html` reads `new Date()`.
- Stale means older than 7 days: `STALE_DAYS = 7`; a report exactly 7 days old is still fresh.
- Every button is at least 44 px tall (matches this repo's 44pt marker target rule).
- Rating colours stay as defined on `:root` (light and dark); no new rating hues. The only token additions are `--pin-edge` (Task 4) and `--on-text` (Task 6). Rating must also be readable as text, never by hue alone.
- Contrast floors: 4.5:1 for text, 3:1 for pins and other graphics against what is behind them, in light and dark.
- No emoji and no em dashes in UI copy, code or comments.
- `geo.js` is data extracted from the published page. Do not hand-edit it.
- Publishing replaces a live page that Daniel owns: get a clear yes in chat before the publish step (Task 7).
- Commits: new commits only, never amend, never `--no-verify`, imperative subject, a body that says why, `git add` with explicit paths, end with `Co-Authored-By: Claude <noreply@anthropic.com>`.

## File Structure

All new files live in `Artifacts/salmon-rivers/`, beside the repo's other `Artifacts/*/artifact.json` bindings.

| File | Responsibility |
| --- | --- |
| `artifact.json` | Binds this folder to the live URL, per the repo convention. "Refresh by PASSING THIS URL." |
| `index.html` | Page source: `<title>`, CSS, markup, DOM and gesture code. No `<!doctype>`/`<head>`; the publisher wraps it. |
| `geo.js` | `window.GEO = {...}`: projection, river lines, highlighted rivers, pin positions, bounds. Generated once from the published page. |
| `reports.js` | `SITES` report data plus pure functions (rating pick, freshness, ranking, formatting). Works in the browser (`window.Reports`) and Node (`module.exports`). |
| `test/reports.test.js` | Node tests for `reports.js`. |
| `test/baseline-pins.json` | Pin colours per species filter captured from the unmodified page, used to prove Task 2 changed nothing visible. |
| `baseline.html` | The unmodified published page body, kept as the rollback source. |
| `serve.js` | 25-line static server that wraps `index.html` in the same document skeleton the publisher uses, for local checks. |
| `../../.claude/launch.json` | Registers `serve.js` so the Browser pane can start it. |

## Out of scope (not planned, and why)

- More rivers or regions: needs sourced catch reports, which is research, not code.
- Fetching live reports at runtime: the page has no backend and the sources are third-party articles.
- Deep links to a selected river: artifact pages run in a sandboxed frame where the hash is not reliably shareable.
- Android-friendly directions link: the page is deliberately Apple-Maps-flavoured like the app.

---

### Task 1: Put the page source in the repo and prove the split renders identically

**Files:**
- Create: `Artifacts/salmon-rivers/index.html`, `geo.js`, `baseline.html`, `serve.js`, `artifact.json`, `test/baseline-pins.json`
- Create: `.claude/launch.json`

**Interfaces:**
- Produces: `window.GEO` (same shape as the old `DATA`: `proj`, `base`, `hl`, `pins`, `bounds`). `index.html` reads it as `var D = window.GEO;`. Local server at `http://127.0.0.1:4173/`.

- [ ] **Step 1: Fetch the published page**

Use the Artifact tool (not curl):

```
Artifact action=read url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
```

The result names a saved file ("full HTML saved to ..."). Call that path `$SRC` below. The version must be `1792352926-fede`; if it is newer, someone edited the page since this plan was written, so stop and show Daniel the difference before continuing.

- [ ] **Step 2: Write the one-time split script (do not commit it)**

Save as `$TMPDIR/split.js`:

```js
// One-time: node split.js <saved-artifact.html> <outDir>
const fs = require('fs');
const [src, out] = process.argv.slice(2);
const lines = fs.readFileSync(src, 'utf8').split('\n');

const start = lines.findIndex(l => l.startsWith('<title>'));
const end = lines.findIndex(l => l.startsWith('</body></html>'));
const di = lines.findIndex(l => l.startsWith('const DATA = '));
if (start < 0 || end < 0 || di < 0) throw new Error('unexpected artifact shape');
if (lines[di - 1].trim() !== '<script>') throw new Error('DATA is not the first line of its script');

const json = lines[di].slice('const DATA = '.length).replace(/;\s*$/, '');
JSON.parse(json); // throws if the line is not pure JSON

const page = lines.slice(start, end);
fs.writeFileSync(`${out}/baseline.html`, page.join('\n') + '\n');

const split = page.slice();
split.splice(di - start - 1, 2, '<script src="geo.js"></script>', '<script>');
const html = split.join('\n').replace('var D = DATA;', 'var D = window.GEO;') + '\n';
if (!html.includes('var D = window.GEO;') || html.includes('const DATA')) throw new Error('split failed');

fs.writeFileSync(`${out}/geo.js`, `window.GEO = ${json};\n`);
fs.writeFileSync(`${out}/index.html`, html);
console.log('ok', { geoBytes: json.length, htmlBytes: html.length });
```

- [ ] **Step 3: Run it**

```bash
mkdir -p Artifacts/salmon-rivers/test
node "$TMPDIR/split.js" "$SRC" Artifacts/salmon-rivers
```

Expected: prints `ok { geoBytes: 428459, htmlBytes: <about 30000> }`. `index.html` is now small enough to read whole.

- [ ] **Step 4: Check `geo.js` loads in Node**

```bash
node -e 'global.window={};require("./Artifacts/salmon-rivers/geo.js");const g=window.GEO;console.log(Object.keys(g).join(","),g.pins.cowlitz.xy)'
```

Expected: `proj,base,hl,pins,bounds [ 163.03, 260.32 ]`

- [ ] **Step 5: Add the local server**

`Artifacts/salmon-rivers/serve.js`:

```js
// Local check server: node Artifacts/salmon-rivers/serve.js  ->  http://127.0.0.1:4173/
// Wraps index.html in the document skeleton the publisher adds, so quirks mode
// and default styles match the live page.
const http = require('http'), fs = require('fs'), path = require('path');
const root = __dirname;
const types = { '.js': 'text/javascript; charset=utf-8', '.json': 'application/json' };
const head = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}html{scroll-padding-top:env(safe-area-inset-top,0px)}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}img{max-width:100%}[hidden]:not([hidden=until-found i]){display:none!important}</style></head><body>\n';
http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel === '/' ? 'index.html' : rel);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    if (path.basename(file) === 'index.html') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }).end(head + buf + '</body></html>');
    } else {
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }).end(buf);
    }
  });
}).listen(4173, '127.0.0.1');
```

`.claude/launch.json`:

```json
{
  "version": "0.0.1",
  "configurations": [
    { "name": "salmon-rivers", "runtimeExecutable": "node", "runtimeArgs": ["Artifacts/salmon-rivers/serve.js"], "port": 4173 }
  ]
}
```

- [ ] **Step 6: Open the page and capture the baseline**

Start `salmon-rivers` with `preview_start`. In the page, run this in the console (the `javascript_tool` accepts top-level `await`):

```js
(async () => {
  const out = {};
  for (const f of ['all', 'coho', 'chinook']) {
    document.querySelector(`.seg button[data-f="${f}"]`).click();
    out[f] = [...document.querySelectorAll('.pin')]
      .map(p => p.dataset.id + ':' + p.style.getPropertyValue('--rc') + ':' + p.classList.contains('closed')).sort();
  }
  document.querySelector('.seg button[data-f="all"]').click();
  return JSON.stringify(out, null, 2);
})()
```

Expected for `all`: six entries, `cowlitz` and `columbia` are `var(--prime):false`, `lewis`, `wind`, `klickitat`, `drano` are `var(--good):false`. Expected for `chinook`: `columbia:var(--fair):true`, `cowlitz:var(--fair):true`, `drano:var(--good):false`, `klickitat:var(--good):false`, `lewis:var(--fair):false`, `wind:var(--fair):false`. Save the whole output to `Artifacts/salmon-rivers/test/baseline-pins.json`.

Also confirm: `document.querySelectorAll('.pin').length === 6`, `document.querySelector('.title').textContent === 'Salmon this month'`, and `read_console_messages` with `onlyErrors` returns nothing.

- [ ] **Step 7: Bind the folder to the live URL**

`Artifacts/salmon-rivers/artifact.json`:

```json
{
  "url": "https://claude.ai/artifact/9oA145toRsmFcDYurdJbey",
  "title": "Washington Salmon Rivers",
  "identified": "2026-10-18, named by Daniel when asking for improvements",
  "account": "danieldecena@icloud.com",
  "what": "Full-bleed river map of six southwest Washington salmon fisheries (Cowlitz, Lower Columbia, Lewis, Wind, Klickitat, Drano Lake) with a coho/chinook filter and a detail sheet. Catch-report ratings, not season dates.",
  "baselineVersion": "1792352926-fede",
  "note": "Source is index.html plus geo.js and reports.js in this folder; baseline.html is the pre-split single-file page and the rollback source. Refresh by PASSING THIS URL and files={geo.js, reports.js}."
}
```

- [ ] **Step 8: Commit**

```bash
git add Artifacts/salmon-rivers .claude/launch.json
git commit -m "Bring the salmon rivers artifact source into the repo

The published page had no local source, so nothing could be reviewed,
tested or rolled back. Split its 428 KB geometry blob out of the HTML,
keep the original page as baseline.html, and capture pin colours from the
unmodified page so later changes can be proved visually neutral.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Pure report logic with dated reports (no visible change)

**Files:**
- Create: `Artifacts/salmon-rivers/reports.js`, `Artifacts/salmon-rivers/test/reports.test.js`
- Modify: `Artifacts/salmon-rivers/index.html` (script tag, report/logic block)

**Interfaces:**
- Consumes: `window.GEO.pins` (from Task 1).
- Produces, all on `Reports` (`window.Reports` in the page, `require('./reports.js')` in Node):
  - `SITES`: array of `{ id, name, sub, hl, extra?, coho: SP, chinook: SP }` where `SP = { r: 'prime'|'good'|'fair', asOf: 'YYYY-MM-DD'|null, d: string, release?: true }`
  - `RANK`, `LABEL`, `SP_NAME`, `STALE_DAYS`
  - `viewOf(site, filter, today) -> { r, release, k, fresh, asOf }` where `filter` is `'all'|'coho'|'chinook'`
  - `freshness(asOf, today) -> 'fresh'|'stale'|'undated'`
  - `ageDays(asOf, today) -> number|null`
  - `formatDay(iso) -> 'Oct 17'`
  - `describeAge(asOf, today) -> 'Oct 17 · yesterday' | 'Date not given'`
  - `latestReport(sites) -> 'YYYY-MM-DD'|null`
  - `staleNotice(sites, today) -> string|null`
  - `rankSites(sites, filter, today) -> [{ site, vw }]`
  - `ratingWord(vw) -> 'Excellent' | 'Fair, release only'`

- [ ] **Step 1: Write the failing tests**

`Artifacts/salmon-rivers/test/reports.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const R = require('../reports.js');

const TODAY = '2026-10-18';
const site = id => R.SITES.find(s => s.id === id);
const pick = (id, filter, today = TODAY) => {
  const v = R.viewOf(site(id), filter, today);
  return { r: v.r, k: v.k, release: v.release };
};

test('viewOf keeps the colours the published page showed on 2026-10-18', () => {
  // Expected values come from the unmodified page (test/baseline-pins.json).
  const expect = {
    cowlitz:   { all: ['prime', 'coho', false],    coho: ['prime', 'coho', false], chinook: ['fair', 'chinook', true] },
    columbia:  { all: ['prime', 'coho', false],    coho: ['prime', 'coho', false], chinook: ['fair', 'chinook', true] },
    lewis:     { all: ['good', 'coho', false],     coho: ['good', 'coho', false],  chinook: ['fair', 'chinook', false] },
    wind:      { all: ['good', 'coho', false],     coho: ['good', 'coho', false],  chinook: ['fair', 'chinook', false] },
    klickitat: { all: ['good', 'coho', false],     coho: ['good', 'coho', false],  chinook: ['good', 'chinook', false] },
    drano:     { all: ['good', 'coho', false],     coho: ['good', 'coho', false],  chinook: ['good', 'chinook', false] },
  };
  for (const id of Object.keys(expect)) {
    for (const f of ['all', 'coho', 'chinook']) {
      const [r, k, release] = expect[id][f];
      assert.deepEqual(pick(id, f), { r, k, release }, `${id}/${f}`);
    }
  }
});

test('a report exactly 7 days old is fresh, 8 days old is stale', () => {
  assert.equal(R.freshness('2026-10-11', TODAY), 'fresh');
  assert.equal(R.freshness('2026-10-10', TODAY), 'stale');
  assert.equal(R.freshness('2026-10-18', TODAY), 'fresh');
});

test('an undated report is "undated", never fresh', () => {
  assert.equal(R.freshness(null, TODAY), 'undated');
  assert.equal(R.ageDays(null, TODAY), null);
  assert.equal(R.describeAge(null, TODAY), 'Date not given');
});

test('a fresh lower rating beats a stale higher one', () => {
  const s = { id: 'x', name: 'X', coho: { r: 'prime', asOf: '2026-10-01', d: '' }, chinook: { r: 'fair', asOf: '2026-10-17', d: '' } };
  const v = R.viewOf(s, 'all', TODAY);
  assert.equal(v.k, 'chinook');
  assert.equal(v.fresh, true);
});

test('when everything is stale the best rating still shows', () => {
  const v = R.viewOf(site('cowlitz'), 'all', '2026-11-30');
  assert.equal(v.r, 'prime');
  assert.equal(v.k, 'coho');
  assert.equal(v.fresh, false);
});

test('release-only still loses to a retainable species even if the release one is fresher', () => {
  const s = { id: 'x', name: 'X', coho: { r: 'fair', asOf: '2026-10-01', d: '' }, chinook: { r: 'prime', release: true, asOf: '2026-10-17', d: '' } };
  assert.equal(R.viewOf(s, 'all', TODAY).k, 'coho');
});

test('a missing species yields the unrated view', () => {
  const v = R.viewOf({ id: 'x', name: 'X' }, 'all', TODAY);
  assert.deepEqual({ r: v.r, k: v.k, release: v.release, fresh: v.fresh }, { r: 'unrated', k: null, release: false, fresh: false });
});

test('dates: format, age words, future dates, invalid input', () => {
  assert.equal(R.formatDay('2026-10-17'), 'Oct 17');
  assert.equal(R.describeAge('2026-10-17', TODAY), 'Oct 17 · yesterday');
  assert.equal(R.describeAge('2026-10-18', TODAY), 'Oct 18 · today');
  assert.equal(R.describeAge('2026-10-03', TODAY), 'Oct 3 · 15 days ago');
  assert.equal(R.describeAge('2026-10-19', TODAY), 'Oct 19 · today'); // clock skew: never "-1 days ago"
  assert.throws(() => R.ageDays('Oct 3', TODAY));
  assert.throws(() => R.ageDays('2026-02-31', TODAY));
});

test('latestReport is the newest dated report and ignores undated ones', () => {
  assert.equal(R.latestReport(R.SITES), '2026-10-17');
  assert.equal(R.latestReport([{ id: 'x', name: 'X', coho: { r: 'fair', asOf: null, d: '' } }]), null);
});

test('staleNotice appears only when the newest report is older than 7 days', () => {
  assert.equal(R.staleNotice(R.SITES, '2026-10-24'), null); // 7 days
  assert.match(R.staleNotice(R.SITES, '2026-10-26'), /9 days old \(Oct 17\)/);
  assert.equal(R.staleNotice([{ id: 'x', name: 'X' }], TODAY), null); // nothing dated, nothing to claim
});

test('rankSites: retainable first, fresh before stale, then rating, then name', () => {
  const ids = (f) => R.rankSites(R.SITES, f, TODAY).map(e => e.site.id);
  assert.deepEqual(ids('all'), ['cowlitz', 'columbia', 'drano', 'klickitat', 'lewis', 'wind']);
  assert.deepEqual(ids('chinook'), ['drano', 'klickitat', 'lewis', 'wind', 'cowlitz', 'columbia']);
});

test('ratingWord carries the release-only caveat as text', () => {
  assert.equal(R.ratingWord({ r: 'prime', release: false }), 'Excellent');
  assert.equal(R.ratingWord({ r: 'fair', release: true }), 'Fair, release only');
  assert.equal(R.ratingWord({ r: 'unrated', release: false }), 'No report');
});

test('report data: ids unique, ratings valid, dates real, no dates left in prose', () => {
  const ids = new Set();
  for (const s of R.SITES) {
    assert.ok(!ids.has(s.id), `duplicate ${s.id}`); ids.add(s.id);
    for (const k of ['coho', 'chinook']) {
      const sp = s[k];
      assert.ok(['prime', 'good', 'fair'].includes(sp.r), `${s.id}/${k} rating`);
      if (sp.asOf !== null) R.ageDays(sp.asOf, TODAY); // throws on a bad date
      assert.doesNotMatch(sp.d, /\b(Oct|Nov|Dec)\s+\d{1,2}\b/, `${s.id}/${k} prose still names a date`);
    }
  }
  assert.equal(ids.size, 6);
});
```

- [ ] **Step 2: Run to confirm it fails**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js"
```

Expected: FAIL with `Cannot find module '../reports.js'`.

- [ ] **Step 3: Write `reports.js`**

Before filling the Columbia Chinook date, open "The Guide's Forecast" page linked in the sheet footer. If it dates the Chinook closure statement, use that date; if it does not, leave `asOf: null`. Do not guess.

`Artifacts/salmon-rivers/reports.js`:

```js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Reports = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var RANK = { prime: 3, good: 2, fair: 1, slow: 0, unrated: -1 };
  var LABEL = { prime: 'Excellent', good: 'Good', fair: 'Fair', unrated: 'No report' };
  var SP_NAME = { coho: 'Coho', chinook: 'Chinook' };
  var STALE_DAYS = 7;
  var DAY = 86400000;
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /* Reports through Oct 17, 2026. asOf is the date of the report each rating comes from. */
  var SITES = [
    { id: 'cowlitz', name: 'Cowlitz River', sub: 'Below the hatchery at Salkum', hl: true,
      coho: { r: 'prime', asOf: '2026-10-17', d: 'Tacoma Power recovered 3,094 adult coho and 1,876 jacks at the hatchery separator over six days.' },
      chinook: { r: 'fair', release: true, asOf: '2026-10-03', d: 'Chinook are being caught here but must be released.' } },
    { id: 'columbia', name: 'Lower Columbia River', sub: 'Tongue Point to Bonneville Dam', hl: true,
      coho: { r: 'prime', asOf: '2026-10-11', d: 'Coho fishing was excellent in the flight count: 157 salmonid boats and 22 Washington bank rods on this stretch.' },
      chinook: { r: 'fair', release: true, asOf: null, d: 'The mainstem is closed for Chinook retention. Plenty are still caught and released.' } },
    { id: 'lewis', name: 'Lewis River', sub: 'Mouth to Merwin Dam', hl: true,
      coho: { r: 'good', asOf: '2026-10-13', d: '138 bank anglers kept 14 coho and 2 jacks and released 10 coho in the creel.' },
      chinook: { r: 'fair', asOf: '2026-10-13', d: 'Same creel: 3 Chinook and 1 jack kept.' }, extra: 'nws' },
    { id: 'wind', name: 'Wind River', sub: 'Lower river near Carson', hl: true,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Reported very good for coho.' },
      chinook: { r: 'fair', asOf: '2026-10-03', d: 'Chinook were still biting on the Wind River and Drano Lake.' } },
    { id: 'klickitat', name: 'Klickitat River', sub: 'Lower river near Lyle', hl: true,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      chinook: { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } },
    { id: 'drano', name: 'Drano Lake', sub: 'Mouth of the Little White Salmon River', hl: false,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      chinook: { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } }
  ];

  function parseDay(iso) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    if (!m) throw new Error('bad date: ' + iso);
    var ms = Date.UTC(+m[1], +m[2] - 1, +m[3]);
    var d = new Date(ms);
    if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) throw new Error('bad date: ' + iso);
    return ms;
  }
  function ageDays(asOf, today) {
    if (asOf === null || asOf === undefined) return null;
    return Math.round((parseDay(today) - parseDay(asOf)) / DAY);
  }
  function freshness(asOf, today) {
    var a = ageDays(asOf, today);
    if (a === null) return 'undated';
    return a <= STALE_DAYS ? 'fresh' : 'stale';
  }
  function formatDay(iso) {
    var d = new Date(parseDay(iso));
    return MONTHS[d.getUTCMonth()] + ' ' + d.getUTCDate();
  }
  function describeAge(asOf, today) {
    var a = ageDays(asOf, today);
    if (a === null) return 'Date not given';
    var when = a <= 0 ? 'today' : a === 1 ? 'yesterday' : a + ' days ago';
    return formatDay(asOf) + ' · ' + when;
  }

  // c replaces best when: best is release-only and c is not; else c is fresh and best is not; else c rates higher.
  function better(c, best) {
    if (!best) return true;
    if (best.release !== c.release) return best.release;
    if (best.fresh !== c.fresh) return c.fresh;
    return RANK[c.r] > RANK[best.r];
  }
  function viewOf(site, filter, today) {
    var keys = filter === 'all' ? ['coho', 'chinook'] : [filter];
    var best = null;
    keys.forEach(function (k) {
      var sp = site[k];
      if (!sp) return;
      var c = { r: sp.r, release: !!sp.release, k: k, asOf: sp.asOf === undefined ? null : sp.asOf, fresh: freshness(sp.asOf, today) === 'fresh' };
      if (better(c, best)) best = c;
    });
    return best || { r: 'unrated', release: false, k: null, asOf: null, fresh: false };
  }

  function latestReport(sites) {
    var latest = null;
    sites.forEach(function (s) {
      ['coho', 'chinook'].forEach(function (k) {
        var a = s[k] && s[k].asOf;
        if (a && (latest === null || a > latest)) latest = a;
      });
    });
    return latest;
  }
  function staleNotice(sites, today) {
    var latest = latestReport(sites);
    if (latest === null) return null;
    var a = ageDays(latest, today);
    if (a <= STALE_DAYS) return null;
    return 'The newest report here is ' + a + ' days old (' + formatDay(latest) + '). Check WDFW or The Guide’s Forecast for current catch.';
  }

  function rankSites(sites, filter, today) {
    return sites.map(function (s) { return { site: s, vw: viewOf(s, filter, today) }; }).sort(function (a, b) {
      if (a.vw.release !== b.vw.release) return a.vw.release ? 1 : -1;
      if (a.vw.fresh !== b.vw.fresh) return a.vw.fresh ? -1 : 1;
      if (RANK[a.vw.r] !== RANK[b.vw.r]) return RANK[b.vw.r] - RANK[a.vw.r];
      return a.site.name < b.site.name ? -1 : a.site.name > b.site.name ? 1 : 0;
    });
  }
  function ratingWord(vw) { return LABEL[vw.r] + (vw.release ? ', release only' : ''); }

  return {
    SITES: SITES, RANK: RANK, LABEL: LABEL, SP_NAME: SP_NAME, STALE_DAYS: STALE_DAYS,
    viewOf: viewOf, freshness: freshness, ageDays: ageDays, formatDay: formatDay, describeAge: describeAge,
    latestReport: latestReport, staleNotice: staleNotice, rankSites: rankSites, ratingWord: ratingWord
  };
});
```

- [ ] **Step 4: Run to confirm it passes**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js"
```

Expected: every test passes, `fail 0`. If `rankSites` or the baseline-equivalence test fails, fix `reports.js`, not the expectations: they were derived by hand from the unmodified page's logic.

- [ ] **Step 5: Point `index.html` at `Reports`**

Add the script tag after the `geo.js` tag:

```html
<script src="geo.js"></script>
<script src="reports.js"></script>
<script>
```

In the inline script, delete these three blocks (find them by their first line):
1. `var RANK = {` through `var SP_NAME = {...};` (three one-line declarations)
2. `/* ---- site content: reports through Oct 17, 2026 ---- */` through the line `SITES.forEach(function (s) { var p = D.pins[s.id]; s.ll = p.ll; s.xy = p.xy; });`
3. `function viewOf(s) {` through its closing `}` (the 9-line function after `var selected = null;`)

Insert in their place, where block 1 was:

```js
  var RANK = Reports.RANK, LABEL = Reports.LABEL, SP_NAME = Reports.SP_NAME;
  var STALE_DAYS = Reports.STALE_DAYS;

  function todayISO() {
    var d = new Date(), p = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
  }
  // ?today=YYYY-MM-DD lets a reviewer see how the page ages; it changes nothing on the live page for normal visitors.
  var override = /[?&]today=(\d{4}-\d{2}-\d{2})/.exec(location.search);
  var TODAY = override ? override[1] : todayISO();

  var SITES = Reports.SITES;
  SITES.forEach(function (s) { var p = D.pins[s.id]; s.ll = p.ll; s.xy = p.xy; });
```

and where block 3 was (after `var selected = null;`):

```js
  function viewOf(s) { return Reports.viewOf(s, filter, TODAY); }
```

- [ ] **Step 6: Prove nothing visible changed**

Reload the page and rerun the Task 1 Step 6 snippet. Compare its output to `test/baseline-pins.json` (for example `JSON.stringify(result) === JSON.stringify(JSON.parse(baselineText))` after normalising whitespace). Expected: identical. Also: no console errors, and tapping the Lewis pin still opens the sheet (the sheet still reads `sp.d` and `sp.r`, which keep their shape).

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/index.html
git commit -m "Move salmon report data and rating logic into a tested module

Reports now carry the date they come from and the rating pick prefers a
fresh report over a stale one, so the page can stop implying that every
rating is current. Pin colours on 2026-10-18 match the unmodified page.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Show how old each report is

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` (title, header, bar markup, CSS, `fillSheet`, boot)

**Interfaces:**
- Consumes: `Reports.latestReport`, `Reports.staleNotice`, `Reports.describeAge`, `Reports.freshness`, `TODAY` and `STALE_DAYS` from Task 2.
- Produces: `#sub` (header subtitle), `#notice` (stale banner), `.chip.old` (dashed chip for non-fresh reports).

- [ ] **Step 1: Retitle the page to match its scope**

The tab title says "Washington" while the page covers southwest Washington only. Change the first line of `index.html`:

```html
<title>SW Washington Salmon Rivers</title>
```

- [ ] **Step 2: Derive the header date from the data**

Replace the static subtitle div:

```html
<div class="sub" id="sub"></div>
```

and add this to the boot section, before `init();`:

```js
  $('#sub').textContent = 'Southwest Washington · reports through ' + Reports.formatDay(Reports.latestReport(SITES));
```

- [ ] **Step 3: Add the stale banner**

In the markup, inside `<div class="glass bar" id="bar">`, after the `.seg` radiogroup:

```html
<div class="notice" id="notice" role="status" hidden></div>
```

CSS (next to `.seg` rules):

```css
.notice { font-size: 12px; line-height: 16px; background: var(--fill-advisory); border-radius: 10px; padding: 8px 10px; }
```

Boot, before `init();` and before the `#sub` line:

```js
  var notice = Reports.staleNotice(SITES, TODAY);
  if (notice) { $('#notice').textContent = notice; $('#notice').hidden = false; }
```

The banner must be set before `init()` because `pads()` measures the bar's height to fit the map.

- [ ] **Step 4: Put the date on every species row**

In `fillSheet`, replace the `.ch` part of the row template. Old:

```js
'</div></div><div class="ch">' + badge(sp.r, sp.release) + (sp.release ? '<span class="chip">Release only</span>' : '') + '</div></div>';
```

New:

```js
'</div></div><div class="ch">' + badge(sp.r, sp.release) + (sp.release ? '<span class="chip">Release only</span>' : '') +
  '<span class="chip' + (Reports.freshness(sp.asOf, TODAY) === 'fresh' ? '' : ' old') + '">' + esc(Reports.describeAge(sp.asOf, TODAY)) + '</span></div></div>';
```

CSS, next to `.chip`:

```css
.chip.old { outline: 1px dashed var(--ink2); outline-offset: -1px; }
```

Stale is shown by the dashed outline and by the words "15 days ago", never by colour alone.

- [ ] **Step 5: Verify at three dates**

With the dev server running, load each URL and read the values with `javascript_tool`:

| URL | Expect |
| --- | --- |
| `http://127.0.0.1:4173/?today=2026-10-18` | `#notice` hidden; `#sub` text `Southwest Washington · reports through Oct 17`; open Cowlitz: coho chip `Oct 17 · yesterday` (no `old`), chinook chip `Oct 3 · 15 days ago` with class `old` |
| `http://127.0.0.1:4173/?today=2026-10-24` | `#notice` still hidden (newest report is 7 days old) |
| `http://127.0.0.1:4173/?today=2026-10-26` | `#notice` visible, text contains `9 days old (Oct 17)`; map still fits below the banner (pins not under the bar); open Lower Columbia: chinook chip reads `Date not given` with class `old` |

Check: `document.title === 'SW Washington Salmon Rivers'`, no console errors.

- [ ] **Step 6: Commit**

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "Date every salmon report and warn when the page has gone stale

A static page that says 'recent catch reports' silently goes wrong as the
days pass. Each species row now shows the report's date and age, the header
date comes from the data, and a banner appears once the newest report is
over a week old. Also retitle the page: it covers southwest Washington only.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Make pin labels appear, say the rating in words, and give pins an edge

**Why:** Three findings from the design critique (2026-10-18, live page at 1280 and 375 px wide):

1. **Pin labels never appear.** `render()` hides a label when its box overlaps an already placed box. The pin's own box (`[p.x - 15, p.y - 36, 30, 38]`) reaches `p.x + 15` while the label box starts at `p.x + 13`, so every label overlaps its own pin by 2 px and is hidden. At the default view all six labels have `display: none`, and the selected pin shows no name either. Adding words to labels that never display would change nothing, so this is fixed first.
2. **Rating is hue only on the map.** Measured with this repo's colour-blind gate (`scripts/cvd_check.py` and `CVDSeparationTests.swift`: Machado 2009 severity 1.0, a pair passes if ΔL\* ≥ 12 or ΔE76 ≥ 30), Good (orange) and Fair (yellow) fail for deuteranopia: ΔL\* 11.3 and ΔE 12.9 in light mode, 11.7 and 13.5 in dark mode. Excellent/Good pass. The palette stays (it is the app's), so the words move onto the map.
3. **Pins are faint on the light map.** Against the basemap `#f2f2f7`: Excellent 3.18:1, Good 1.97:1, Fair 1.35:1 (non-text contrast needs 3:1), and the white count inside an orange cluster badge is 2.2:1 (bold 11 px text needs 4.5:1). The white edge does nothing on a light map. Dark mode is fine (4.99 to 12.05:1).

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` (CSS tokens, `render`, `applyStyles`, boot measurement)

**Interfaces:**
- Consumes: `Reports.ratingWord(vw)` from Task 2.
- Produces: pin labels reading `<short name> · <rating word>`; `glyphColor(r)`; `--pin-edge` token.

- [ ] **Step 1: Reproduce the missing labels**

Load `http://127.0.0.1:4173/?today=2026-10-18` at 1280x800 and run:

```js
[...document.querySelectorAll('#over > text.lab')].filter(t => t.style.display !== 'none').map(t => t.textContent)
```

Expected now: `[]`. If it is not empty, the bug is already fixed elsewhere; skip to Step 4.

- [ ] **Step 2: Fix the collision box**

In `render()`, in the pin-label loop, change the label box so it starts where the pin box ends. Old:

```js
      var bx = [p.x + 13, p.y - 30, pn.w + 4, 14];
```

New:

```js
      var bx = [p.x + 15, p.y - 30, pn.w + 4, 14];
```

`overlap()` uses strict `<`, so boxes that only touch do not collide.

- [ ] **Step 3: Verify and commit the bug fix on its own**

Rerun the Step 1 snippet. Expected: non-empty and includes `Cowlitz`. At the `mobile` preset expect at least `Cowlitz` (Wind and Drano cluster at that width, so a missing label there is correct). Open a river and confirm the selected pin shows its name.

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "Show the salmon pin labels

Each label's collision box started 2 px inside its own pin's box, so
render() hid every label at every zoom. Start the label box where the pin
box ends.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] **Step 4: Write the label from the view**

In `applyStyles`, inside the `SITES.forEach` after `var pn = pinNodes[s.id];`, add:

```js
      pn.lab.textContent = s.name.replace(' River', '') + ' · ' + Reports.ratingWord(vw);
      pn.lab.style.display = '';          // getBBox needs a displayed node; render() re-hides it
      pn.w = pn.lab.getBBox().width;
```

Every caller of `applyStyles` is followed by `render()` (filter change, `openSheet`, `closeSheet`, and boot via `setView`), which sets each label's display again, so the temporary `display = ''` never persists.

Delete the now-redundant boot measurement (labels are measured in `applyStyles` at boot):

```js
  SITES.forEach(function (s) { pinNodes[s.id].w = pinNodes[s.id].lab.getBBox().width; });
```

Keep the landmark measurement line above it.

- [ ] **Step 5: Give pins a dark edge on the light map and a dark mark on orange**

Tokens. In the light `:root` block add `--pin-edge: rgba(0,0,0,0.55);`. In both dark blocks (the `@media (prefers-color-scheme: dark)` one and `:root[data-theme="dark"]`) add `--pin-edge: rgba(255,255,255,0.95);`. A 0.55 black edge over `#f2f2f7` composites to about `#6d6d6f`, 4.6:1 against the map.

CSS: replace the hard-coded white edges.

```css
.pin .balloon { fill: var(--rc); stroke: var(--pin-edge); stroke-width: 1.5; }
.cluster circle { fill: var(--rc); stroke: var(--pin-edge); stroke-width: 2; }
```

JS: Good needs the dark mark as well as Fair. Add the helper near `colorVar` and use it in both places that set `--gl`:

```js
  function glyphColor(r) { return r === 'fair' || r === 'good' ? 'rgba(0,0,0,0.72)' : '#fff'; }
```

In `applyStyles`: `pn.g.style.setProperty('--gl', glyphColor(vw.r));`
In `render()`, cluster branch: `c.g.style.setProperty('--gl', glyphColor(g[0].vw.r));`

Black at 0.72 over `#ff9500` composites to about `#472a00`, 6.5:1, which clears 4.5:1 for the cluster count. A helper is warranted here because two copies of this condition drifting apart is exactly how the old Fair-only rule came about.

- [ ] **Step 6: Verify**

Load `http://127.0.0.1:4173/?today=2026-10-18` and run:

```js
[...document.querySelectorAll('#over > text.lab')].map(t => t.textContent)
```

Expected for `All salmon`: `["Cowlitz · Excellent","Lower Columbia · Excellent","Lewis · Good","Wind · Good","Klickitat · Good","Drano Lake · Good"]`. Click Chinook and rerun; expected: `["Cowlitz · Fair, release only","Lower Columbia · Fair, release only","Lewis · Fair","Wind · Fair","Klickitat · Good","Drano Lake · Good"]`.

Screenshot at 1280x800 and at the `mobile` preset, light and dark (`resize_window` with `colorScheme`). Confirm: the visible labels are legible against the halo; the Good and Fair pins have a clear dark outline in light mode and still read in dark mode; the cluster count on the orange badge is dark. Record in the commit body which labels show at the default view in each size. Crowded pins losing a label is expected, and Task 5's list is the fallback.

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "Print the rating word on salmon pins and give pins a visible edge

Orange and yellow collapse for deuteranopes under this repo's colour-blind
gate, and the pins relied on hue alone. Labels now read 'Lewis · Good',
with 'release only' spelled out. Good and Fair pins were 1.97:1 and 1.35:1
against the light basemap, so pins get a dark edge in light mode, and the
cluster count on orange is dark instead of white (2.2:1).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: A ranked list of rivers

**Why:** The map holds six places but makes you hunt for them, hides labels where pins crowd, and offers keyboard and screen-reader users no overview. A list answers "where should I go today" in one look, and it is the fallback when a pin label is hidden.

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` (bar markup, CSS, sheet JS)

**Interfaces:**
- Consumes: `Reports.rankSites`, `Reports.describeAge`, `badge()`, `esc()`, `openSheet(id)` (existing).
- Produces: `#listbtn`, `fillList()`, `openList()`, a `mode` variable (`'detail' | 'list' | null`) and `showSheet()`, which Task 6 extends.

- [ ] **Step 1: Add the Rivers button next to the species filter**

Wrap the radiogroup in a row. Old:

```html
      <div class="seg" role="radiogroup" aria-label="Species">
        ...three buttons...
      </div>
```

New:

```html
      <div class="ctl">
        <div class="seg" role="radiogroup" aria-label="Species">
          ...three buttons, unchanged...
        </div>
        <button type="button" class="listbtn" id="listbtn" aria-expanded="false" aria-controls="sheet">Rivers</button>
      </div>
```

CSS next to `.seg`:

```css
.ctl { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 6px; }
.listbtn { border: 1px solid var(--glass-line); background: transparent; cursor: pointer; padding: 6px 14px; min-height: 44px; border-radius: 999px; font-size: 12px; line-height: 16px; font-weight: 600; }
.listbtn[aria-expanded="true"] { background: var(--on); border-color: var(--on); color: #fff; }
.lrow { border: 0; width: 100%; text-align: left; cursor: pointer; min-height: 44px; font: inherit; color: inherit; }
.lede { margin: 0 0 10px; font-size: 12px; line-height: 16px; color: var(--ink2); }
```

- [ ] **Step 2: Add `fillList` and the sheet mode**

Add above `fillSheet`:

```js
  var mode = null; // 'detail' | 'list' | null
  function fillList() {
    var rows = Reports.rankSites(SITES, filter, TODAY).map(function (e) {
      var s = e.site, vw = e.vw;
      var line = vw.k ? SP_NAME[vw.k] + ' · ' + Reports.describeAge(vw.asOf, TODAY) : 'No report';
      return '<button type="button" class="row lrow" data-id="' + s.id + '"><span class="rt"><span class="nm">' + esc(s.name) +
        '</span><span class="dt">' + esc(line) + '</span></span><span class="ch">' + badge(vw.r, vw.release) +
        (vw.release ? '<span class="chip">Release only</span>' : '') + '</span></button>';
    }).join('');
    $('#stitle').textContent = 'Rivers';
    $('#sbody').innerHTML = '<p class="lede">' + (filter === 'all' ? 'All salmon' : SP_NAME[filter]) +
      ', best first. Fresh reports rank above older ones.</p><div class="rows">' + rows + '</div>';
    $('#sbody').scrollTop = 0;
  }
```

- [ ] **Step 3: Replace the open/close functions and the handlers**

Replace `openSheet`'s first lines and `closeSheet`, and add `showSheet`/`openList`. The camera code in the middle of `openSheet` does not change.

```js
  function showSheet() {
    sheet.classList.add('open'); sheet.setAttribute('aria-hidden', 'false');
    appEl.classList.add('sheet-open');
  }
  function openSheet(id) {
    selected = id; mode = 'detail';
    fillSheet(id);
    showSheet();
    $('#listbtn').setAttribute('aria-expanded', 'false');
    applyStyles();
    var s = SITES.filter(function (q) { return q.id === id; })[0];
    var wide = window.innerWidth >= 760;
    var sh = sheet.getBoundingClientRect().height || 0;
    var ns = Math.max(v.s, s0 * 1.5);
    var barB = $('#bar').getBoundingClientRect().bottom;
    var tx, ty;
    if (wide) { tx = (W - 392) / 2 - s.xy[0] * ns; ty = H / 2 + 20 - s.xy[1] * ns; }
    else { tx = W / 2 - s.xy[0] * ns; ty = (barB + (H - Math.min(sh, H * 0.66))) / 2 + 24 - s.xy[1] * ns; }
    animateTo({ s: ns, tx: tx, ty: ty }, 320);
  }
  function openList() {
    selected = null; mode = 'list';
    fillList();
    showSheet();
    $('#listbtn').setAttribute('aria-expanded', 'true');
    applyStyles(); render();
  }
  function closeSheet() {
    selected = null; mode = null;
    sheet.classList.remove('open'); sheet.setAttribute('aria-hidden', 'true');
    appEl.classList.remove('sheet-open');
    $('#listbtn').setAttribute('aria-expanded', 'false');
    applyStyles(); render();
  }
  $('#listbtn').addEventListener('click', function () { if (mode === 'list') closeSheet(); else openList(); });
  $('#sbody').addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('.lrow') : null;
    if (b) openSheet(b.getAttribute('data-id'));
  });
```

In the species filter click handler, replace `if (selected) fillSheet(selected);` with:

```js
      if (mode === 'detail') fillSheet(selected); else if (mode === 'list') fillList();
```

Replace the Escape handler's condition `if (e.key === 'Escape' && selected)` with `if (e.key === 'Escape' && mode)`.

- [ ] **Step 4: Verify the list**

Load `http://127.0.0.1:4173/?today=2026-10-18`, click `#listbtn`:

```js
[...document.querySelectorAll('.lrow .nm')].map(n => n.textContent)
```

Expected: `["Cowlitz River","Lower Columbia River","Drano Lake","Klickitat River","Lewis River","Wind River"]`. Then click Chinook (the open list re-renders): expected `["Drano Lake","Klickitat River","Lewis River","Wind River","Cowlitz River","Lower Columbia River"]`. Click the Lewis row: the sheet switches to Lewis detail, the map moves, `#listbtn` has `aria-expanded="false"`. Click `#listbtn` twice: opens, closes. Escape closes the list. At the `mobile` preset the list sheet leaves the bar visible and hides the legend, as the detail sheet does. No console errors.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "Add a ranked list of rivers to the salmon page

The map hides pin labels where pins crowd and gives keyboard and screen
reader users no overview. The Rivers button lists all six best-first for
the chosen species, fresh reports ahead of old ones.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Sheet accessibility, readable teal, Directions above the fold, 44 px buttons

**Why:** Findings from the design critique: the river name appears twice in the sheet; focus stays on the map when the sheet opens; filter buttons are 30 px and Done is 32 px; the teal used for links and the Done button is 3.55:1 on the dark sheet (needs 4.5:1; it is 4.80:1 on white, fine); on a phone the Directions button sits below the fold (sheet content 616 px in a 476 px viewport), though it is the main action.

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` (sheet markup, CSS tokens and rules, `fillSheet`, `showSheet`, `closeSheet`)

**Interfaces:**
- Consumes: `showSheet`, `closeSheet`, `mode` from Task 5.
- Produces: one heading per sheet (`#stitle` is an `h2`), focus into the sheet on open and back to the opener on close, `--on-text` token.

- [ ] **Step 1: One title, not two**

Keep the bar title (it stays visible while the body scrolls) and make it the heading.

Markup: change `<span class="st" id="stitle"></span>` to `<h2 class="st" id="stitle"></h2>`, and on the aside replace `aria-label="River details"` with `aria-labelledby="stitle" tabindex="-1"`.

CSS: replace the `.sbar .st` rule:

```css
.sbar .st { margin: 6px 0 0; font-size: 15px; line-height: 20px; font-weight: 600; }
```

In `fillSheet`, remove `<h2>` from the head template. Old: `'<div class="head"><h2>' + esc(s.name) + '</h2><p>' + esc(s.sub) + '</p>' +`. New: `'<div class="head"><p>' + esc(s.sub) + '</p>' +`. Delete the now-unused `.head h2` CSS rule.

- [ ] **Step 2: Move focus into the sheet and back out**

Replace `showSheet` and `closeSheet` with:

```js
  var returnFocus = null;
  function showSheet() {
    if (!sheet.classList.contains('open')) returnFocus = document.activeElement;
    sheet.classList.add('open'); sheet.setAttribute('aria-hidden', 'false');
    appEl.classList.add('sheet-open');
    sheet.focus({ preventScroll: true });
  }
  function closeSheet() {
    selected = null; mode = null;
    sheet.classList.remove('open'); sheet.setAttribute('aria-hidden', 'true');
    appEl.classList.remove('sheet-open');
    $('#listbtn').setAttribute('aria-expanded', 'false');
    applyStyles(); render();
    var back = returnFocus; returnFocus = null;
    if (back && back !== document.body && document.contains(back) && back.focus) back.focus({ preventScroll: true });
  }
```

Restoring focus after `render()` matters: a pin that was clustered is only displayed again once `render()` runs. `showSheet` records the opener only when the sheet was closed, so opening a river from the list keeps the original opener.

CSS: `#sheet:focus { outline: none; }` (programmatic focus on the container should not draw a ring).

- [ ] **Step 3: 44 px targets**

```css
.seg button { min-height: 44px; padding: 0 14px; }
.sbar button { min-height: 44px; }
```

Replace the existing `min-height: 30px` and `min-height: 32px` and the `padding: 6px 12px` / `padding: 6px 4px` declarations on those two rules.

- [ ] **Step 4: Readable teal in dark mode**

Add a text-colour token. Light `:root` block: `--on-text: #007c9e;` (4.80:1 on white). Both dark blocks: `--on-text: #4fc3dc;` (about 8.3:1 on `#1c1c1e`). Keep `--on` as is for fills, because white on `--on` is 4.80:1 in both modes.

Use it wherever teal is text on the surface or sheet:

```css
a { color: var(--on-text); }
.sbar button { color: var(--on-text); }
.lab.water { fill: var(--on-text); }
```

(In `.sbar button` the existing rule sets `color: var(--on)`; change that declaration, do not add a second one.)

- [ ] **Step 5: Directions right under the header**

In `fillSheet`, move the `dir` link so it follows `head` instead of following the advisory. Old order of the final concatenation: `head + '<section>…What’s biting…</section>' + '<section class="advisory">…' + '<a class="dir" …>…</a>' + '<div class="foot">…'`. New order: `head + '<a class="dir" …>…</a>' + '<section>…What’s biting…</section>' + '<section class="advisory">…' + '<div class="foot">…'`. The advisory and footer stay in the sheet, unchanged.

- [ ] **Step 6: Verify**

Load `http://127.0.0.1:4173/?today=2026-10-18`, then:

```js
// every button is tall enough
[...document.querySelectorAll('button')].filter(b => b.getBoundingClientRect().height < 44).map(b => b.textContent)
// expect []

const pin = document.querySelector('.pin[data-id="cowlitz"]');
getComputedStyle(pin).display   // expect not 'none' at the default view
pin.focus();
pin.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
document.activeElement.id       // expect 'sheet'
document.querySelectorAll('#sheet h2').length   // expect 1
window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
document.activeElement === pin  // expect true
```

At the `mobile` preset with the Cowlitz sheet open:

```js
document.querySelector('.dir').getBoundingClientRect().bottom <= document.querySelector('#sbody').getBoundingClientRect().bottom
// expect true: Directions is visible without scrolling
```

In dark mode confirm `getComputedStyle(document.querySelector('#sdone')).color` is `rgb(79, 195, 220)`. Open the list and click a row: focus is in the sheet; Escape returns focus to `#listbtn`. Take a screenshot at `mobile`: if the species bar plus header covers more than about a third of the screen, move `.brand .sub` onto the title line rather than shrinking buttons below 44 px.

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "Tidy the salmon sheet: one heading, focus handling, readable teal

The river name appeared twice, focus stayed on the map when the sheet
opened, filter buttons were 30 px, teal text was 3.55:1 on the dark sheet,
and Directions sat below the fold on a phone. The sheet title is now the
single heading, focus moves in and returns to the opener, teal text uses a
lighter token in dark mode, Directions follows the header, and every
button is at least 44 px.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Publish to the live artifact

**Files:**
- Modify: `Artifacts/salmon-rivers/artifact.json`

- [ ] **Step 1: Run the whole check**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js"
```

Expected: `fail 0`. Walk Tasks 3 to 6 verification once more on the final `index.html` (the date table, the list order, the focus check, the 44 px check) at desktop and `mobile` presets, in light and dark.

- [ ] **Step 2: Get Daniel's yes**

This replaces a live page. Tell Daniel what changed in two or three lines (dated reports with a stale banner, rating words on pins, a ranked Rivers list, accessibility fixes), that the geometry and report facts are unchanged, and that the rollback is republishing `baseline.html`. Wait for a clear yes in chat before Step 3.

- [ ] **Step 3: Confirm nobody edited the live page, then publish**

```
Artifact action=read url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
```

Then publish. Do not pass `icon` on an update.

```
Artifact
  file_path=Artifacts/salmon-rivers/index.html
  url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
  files={ "geo.js": "Artifacts/salmon-rivers/geo.js", "reports.js": "Artifacts/salmon-rivers/reports.js" }
  label="Dated reports, rating words, Rivers list"
```

If the publish is refused because the live page changed, merge onto the newer content it hands back; never use `force`.

- [ ] **Step 4: Verify the live page**

Open the live URL in the Browser pane (or `Artifact action=open`). Expected: six pins, header `Southwest Washington · reports through Oct 17`, the Rivers button, pin labels with rating words, no console errors. This is the one step that proves relative `<script src>` files load inside the artifact sandbox.

If the page is blank or `Reports`/`GEO` is undefined: inline the two scripts and republish a single file:

```bash
mkdir -p .scratch
node -e 'const fs=require("fs"),d="Artifacts/salmon-rivers/";let h=fs.readFileSync(d+"index.html","utf8");for(const f of ["geo.js","reports.js"]){h=h.replace(`<script src="${f}"></script>`,()=>"<script>"+fs.readFileSync(d+f,"utf8")+"</script>")}fs.writeFileSync(".scratch/salmon-single.html",h)'
```

then publish `.scratch/salmon-single.html` to the same `url` with `files={ "geo.js": null, "reports.js": null }` to remove the stale supporting files. Note the outcome in `artifact.json`.

If the page is broken in some other way, roll back by publishing `Artifacts/salmon-rivers/baseline.html` to the same `url`.

- [ ] **Step 5: Record the new version and commit**

Add to `artifact.json` the version id the publish result reported:

```json
  "currentVersion": "<version id from the publish result>",
```

```bash
git add Artifacts/salmon-rivers/artifact.json
git commit -m "Record the published version of the salmon rivers artifact

Co-Authored-By: Claude <noreply@anthropic.com>"
```
