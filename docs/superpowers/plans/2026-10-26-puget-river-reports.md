# Puget Sound River Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Recent reports on the Washington Fishing Map colour rivers beyond the original eight (Puget Sound first) from named, dated, linked catch reports, drawing them from the tappable-river geometry.

**Architecture:** New rivers are ordinary `SITES` entries in `reports.js` with three extra fields (`tap`, `ll`, `added`). The page takes a pin and line from `geo.js` when it has them, else from the entry's `ll` and the tappable river's path. Two pure helpers in `reports.js` (`homeBox`, `regionName`) decide the opening view and the region wording, so they are tested in Node. Data rules for new entries are enforced by tests that skip the original eight.

**Tech Stack:** Plain browser JavaScript (UMD modules), Node's built-in test runner (`node --test`), Playwright page check (`check-week.mjs`, needs a Playwright browser).

**Spec:** `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md`

## Global Constraints

- Catch quality only: a river is coloured only when a dated source describes the fishing. No rating from rules, flows, forecasts or counts.
- Sources: named, dated, linked reports from shops, guides, guide services and agencies. Not social-media posts.
- A new rating's report is at most 14 days old on the day it is added (`asOf` ≥ `added` − 14 days, and not after `added`).
- `slow` only from the source's own word, kept in `phrase`.
- A river WDFW has closed for a species gets no rating for that species.
- `geo.js` is generated elsewhere: never hand-edit it.
- The page makes no network requests (a test enforces it).
- Species names are exact app names (`test/species-vocab.test.js`).
- The original eight entries are unchanged and carry no `added` field.
- Work lands through a branch and a PR into `main`; Daniel merges. Nothing is published until after merge.
- Commits: explicit pathspec, imperative subject, a body that says why, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never amend, never `--no-verify`.
- Run Node tests from the repo root: `node --test "Artifacts/salmon-rivers/test/*.test.js"`. Baseline before this plan: 204 pass, 0 fail, 3 skipped.
- `check-week.mjs` needs a Playwright browser. This Mac has none; installing one is a download that needs Daniel's OK. Where a task says to run it and no browser is available, record "not run" in the PR.

## File structure

| File | Change |
|------|--------|
| `Artifacts/salmon-rivers/reports.js` | Add `homeBox(points, base, pad)` and `regionName(points, sw)` to the exports. Later data passes add `SITES` entries. |
| `Artifacts/salmon-rivers/index.html` | Pin and line fallback, home bounds through `Reports.homeBox`, region wording through `Reports.regionName`. |
| `Artifacts/salmon-rivers/test/reports.test.js` | New-site rules with a self-check, `homeBox` and `regionName` tests. |
| `Artifacts/salmon-rivers/test/typical.test.js` | Baseline-pins test compares only entries without `added`. |
| `Artifacts/salmon-rivers/check-week.mjs` | One fixture case: a served `reports.js` with a Skagit entry, at 390 and 1280 px. |
| `Artifacts/salmon-rivers/README.md` | "Refresh the reports" gains the new fields and rules. |
| `docs/research/2026-10-26-puget-river-reports.md` | The first sourcing pass (new). |
| `TASKS.md` | One line for later data passes. |

---

### Task 1: Rules for new report sites

**Files:**
- Test: `Artifacts/salmon-rivers/test/reports.test.js` (append)
- Modify: `Artifacts/salmon-rivers/README.md` ("Refresh the reports" section)

**Interfaces:**
- Produces (test file scope, used by Task 2's tests in the same file): `loadGlobal(file, name)`, `GEO`, `TAP`, `newSiteProblems(site) -> string[]`.

- [ ] **Step 1: Write the rules and their self-check**

Append to `Artifacts/salmon-rivers/test/reports.test.js`:

```js
// ---- new report sites (entries with `added`): docs/superpowers/specs/2026-10-26-puget-river-reports-design.md ----
const loadGlobal = (file, name) => { const w = {}; new Function('window', fs.readFileSync(path.join(__dirname, '..', file), 'utf8'))(w); return w[name]; };
const GEO = loadGlobal('geo.js', 'GEO');
const TAP = loadGlobal('rivers-tap.js', 'RIVERTAP');
const TAP_IDS = new Set(TAP.rivers.map(r => r.id));
const ENTRY_DAYS = 14;
const dayNo = iso => Date.parse(iso + 'T00:00:00Z') / 86400000;
function newSiteProblems(s) {
  const out = [];
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(s.added))) out.push(`${s.id}: added is not YYYY-MM-DD`);
  if (!TAP_IDS.has(s.tap)) out.push(`${s.id}: tap ${s.tap} is not a river in rivers-tap.js`);
  if (!Array.isArray(s.ll) || s.ll.length !== 2) out.push(`${s.id}: ll is not [lat, lon]`);
  else {
    const x = (s.ll[1] - GEO.proj.lon0) * GEO.proj.kx, y = (GEO.proj.lat0 - s.ll[0]) * GEO.proj.k, b = GEO.bounds.state;
    if (!(x >= b[0][0] && x <= b[1][0] && y >= b[0][1] && y <= b[1][1])) out.push(`${s.id}: ll is outside Washington`);
  }
  for (const [k, sp] of Object.entries(s.reports || {})) {
    if (!sp.src || !sp.src.label || !/^https:\/\//.test(sp.src.url || '')) out.push(`${s.id}/${k}: src needs a label and an https url`);
    if (!sp.asOf) out.push(`${s.id}/${k}: a new entry needs a dated report`);
    else {
      const age = dayNo(s.added) - dayNo(sp.asOf);
      if (!(age >= 0 && age <= ENTRY_DAYS)) out.push(`${s.id}/${k}: report is ${age} days old on the day it was added (max ${ENTRY_DAYS})`);
    }
    if (sp.r === 'slow' && !sp.phrase) out.push(`${s.id}/${k}: slow needs the source's phrase`);
  }
  return out;
}
const GOOD = { id: 'fx', name: 'Fixture River', sub: 's', hl: true, tap: 'skagit-river', ll: [48.42, -122.33], added: '2026-10-25',
  reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-24', d: 'Fixture.', src: { label: 'Fixture shop, Oct 24', url: 'https://example.org/r' } } } };
const withSp = patch => ({ ...GOOD, reports: { 'Coho Salmon': { ...GOOD.reports['Coho Salmon'], ...patch } } });

test('new-site rules: a well-formed fixture passes, and each broken one fails for its own reason', () => {
  assert.deepEqual(newSiteProblems(GOOD), []);
  const cases = [
    [{ ...GOOD, tap: 'no-such-river' }, /tap no-such-river/],
    [{ ...GOOD, ll: [45.0, -110.0] }, /outside Washington/],
    [{ ...GOOD, added: 'Oct 25' }, /added is not/],
    [withSp({ src: undefined }), /src needs/],
    [withSp({ src: { label: 'x', url: 'http://x' } }), /src needs/],
    [withSp({ asOf: null }), /dated report/],
    [withSp({ asOf: '2026-10-10' }), /15 days old/],
    [withSp({ asOf: '2026-10-26' }), /-1 days old/],
    [withSp({ r: 'slow' }), /slow needs/],
  ];
  for (const [s, re] of cases) assert.match(newSiteProblems(s).join('\n'), re);
});

test('every new report site follows the rules (entries without `added` are the original eight)', () => {
  assert.deepEqual(R.SITES.filter(s => s.added).flatMap(newSiteProblems), []);
  assert.equal(R.SITES.filter(s => !s.added).length, 8, 'control: the original eight carry no added date');
});
```

- [ ] **Step 2: Run the suite**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: 206 pass, 0 fail, 3 skipped (two new tests).

- [ ] **Step 3: Watch a rule go red**

Temporarily change `if (sp.r === 'slow' && !sp.phrase)` to `if (false)` and rerun `node --test Artifacts/salmon-rivers/test/reports.test.js`.
Expected: FAIL in "new-site rules" on the `/slow needs/` case. Restore the line and rerun: PASS.

- [ ] **Step 4: Document the rules**

In `Artifacts/salmon-rivers/README.md`, section "Refresh the reports", after the existing three bullets, add:

```markdown
A river beyond the original eight (spec: `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md`) is one more `SITES` entry with three extra fields: `tap` (a river id in `rivers-tap.js`; its path is the highlighted line), `ll` (`[lat, lon]` of the pin, a named access point on that river) and `added` (the day the entry was added). For these entries, `test/reports.test.js` also requires:

- `src: { label, url }` (https) on every species report: a named shop, guide, guide service or agency, never a social-media post;
- a dated report at most 14 days old on the `added` day;
- `slow` only with the source's `phrase`;
- a pin inside Washington and a `tap` that exists.

Rate from the source's own words: hot, excellent → `prime`; good, very good, solid → `good`; fair, some fish, spotty → `fair`; slow, poor, tough → `slow`. A report about rules, flows, trout, forecasts or effort with no catch read gives no rating, and a river WDFW has closed for the species gets none. Each pass is recorded in `docs/research/` first.
```

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/README.md
git commit -m "Test the rules for report sites beyond the original eight

A new river must link a named source, carry a report at most 14 days
old when added, keep slow to the source's own word, and point at real
tappable-river geometry. The rules are self-checked against fixtures
so none can pass on nothing.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/README.md
```

---

### Task 2: `homeBox` and `regionName` in `reports.js`

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js` (add two functions before `return {`, add them to the export object)
- Test: `Artifacts/salmon-rivers/test/reports.test.js` (append)

**Interfaces:**
- Consumes: `GEO` from Task 1's test scope.
- Produces: `Reports.homeBox(points: [x, y][], base: [[x0, y0], [x1, y1]], pad?: [px, py]) -> [[x0, y0], [x1, y1]]` (default pad `[12, 24]`); `Reports.regionName(points: [x, y][], sw: box) -> 'Southwest Washington' | 'Washington'`.

- [ ] **Step 1: Write the failing tests**

Append to `Artifacts/salmon-rivers/test/reports.test.js`:

```js
// ---- opening view and region wording ----
const SW = [GEO.bounds.sw[0], [GEO.bounds.sw[1][0], 356]];
const EIGHT = Object.values(GEO.pins).map(p => p.xy);
const SKAGIT = [(-122.33 - GEO.proj.lon0) * GEO.proj.kx, (GEO.proj.lat0 - 48.42) * GEO.proj.k];

test('homeBox: the eight southwest pins leave the opening box exactly as it was', () => {
  assert.equal(EIGHT.length, 8, 'control: geo.js has the eight pins');
  assert.deepEqual(R.homeBox(EIGHT, SW), SW);
});

test('homeBox: a Skagit pin grows the box north and keeps every pin inside with its label room', () => {
  const b = R.homeBox(EIGHT.concat([SKAGIT]), SW);
  assert.ok(b[0][1] < SW[0][1], 'the top edge moved north');
  assert.equal(b[0][1], SKAGIT[1] - 24);
  for (const p of EIGHT.concat([SKAGIT])) assert.ok(p[0] - 12 >= b[0][0] && p[0] + 12 <= b[1][0] && p[1] - 24 >= b[0][1] && p[1] <= b[1][1], `pin ${p} inside`);
});

test('regionName: southwest while every pin is in the box, Washington once one is not', () => {
  assert.equal(R.regionName(EIGHT, SW), 'Southwest Washington');
  assert.equal(R.regionName(EIGHT.concat([SKAGIT]), SW), 'Washington');
});
```

- [ ] **Step 2: Run to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/reports.test.js`
Expected: FAIL with `R.homeBox is not a function` and `R.regionName is not a function`.

- [ ] **Step 3: Implement**

In `Artifacts/salmon-rivers/reports.js`, directly before `  return {`, add:

```js
  /* The Recent reports opening box: base (the southwest, down to the Columbia) grown to hold every report pin with room for
     the pin and its label above it (pad: [x, above]). Pure; the page passes its own projected points. */
  function homeBox(points, base, pad) {
    var px = pad ? pad[0] : 12, py = pad ? pad[1] : 24;
    var x0 = base[0][0], y0 = base[0][1], x1 = base[1][0], y1 = base[1][1];
    points.forEach(function (p) { x0 = Math.min(x0, p[0] - px); x1 = Math.max(x1, p[0] + px); y0 = Math.min(y0, p[1] - py); y1 = Math.max(y1, p[1]); });
    return [[x0, y0], [x1, y1]];
  }
  /* The region the map's title and label name: the southwest while every report pin is inside its box, else the state. */
  function regionName(points, sw) {
    var inside = points.every(function (p) { return p[0] >= sw[0][0] && p[0] <= sw[1][0] && p[1] >= sw[0][1] && p[1] <= sw[1][1]; });
    return inside ? 'Southwest Washington' : 'Washington';
  }
```

and change the last export line from

```js
    reportRows: reportRows, missingNote: missingNote
```

to

```js
    reportRows: reportRows, missingNote: missingNote, homeBox: homeBox, regionName: regionName
```

- [ ] **Step 4: Run the suite**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: 209 pass, 0 fail, 3 skipped.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js
git commit -m "Compute the Recent reports opening box and region name in reports.js

The page will open fitted to every report pin and stop saying
Southwest Washington once a pin lies outside the southwest. Keeping
both as pure functions lets Node test them; with today's eight pins
both return exactly what the page shows now.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js
```

---

### Task 3: Draw new sites on the map

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` (pin setup near line 590, highlight loop near line 684, `homeBounds` near line 857, region text near lines 1900, 1910 and 1968)
- Modify: `Artifacts/salmon-rivers/test/typical.test.js` (baseline-pins test near line 181)

**Interfaces:**
- Consumes: `Reports.homeBox`, `Reports.regionName` (Task 2); `TAPBY` (built in `index.html` from `RIVERTAP` before the highlight loop); `xy(lon, lat)` (declared in `index.html` line 572).
- Produces: report sites with `tap`/`ll` render as pin plus line; `SW_BOX` and `REGION` variables in the page script.

- [ ] **Step 1: Keep the baseline test on the original eight**

In `Artifacts/salmon-rivers/test/typical.test.js`, in "Recent reports pin colours still equal the baseline published on 2026-10-18", change

```js
    const now = R.SITES.map(s => {
```

to

```js
    const now = R.SITES.filter(s => !s.added).map(s => {
```

Run: `node --test Artifacts/salmon-rivers/test/typical.test.js` — Expected: PASS.

- [ ] **Step 2: Pins from `ll` when `geo.js` has none**

In `index.html`, replace

```js
  SITES.forEach(function (s) { var p = D.pins[s.id]; s.ll = p.ll; s.xy = p.xy; });
```

with

```js
  // geo.js places the original eight; a site added later (reports.js `tap`, `ll`) is projected from its own ll.
  SITES.forEach(function (s) { var p = D.pins[s.id]; if (p) { s.ll = p.ll; s.xy = p.xy; } else { s.xy = xy(s.ll[1], s.ll[0]); } });
  // Recent reports' southwest box, down to the Columbia (y 356 is 45.54 N, below Camas).
  var SW_BOX = [D.bounds.sw[0], [D.bounds.sw[1][0], 356]];
  var REGION = Reports.regionName(SITES.map(function (s) { return s.xy; }), SW_BOX);
```

- [ ] **Step 3: Lines from the tappable river when `geo.js` has none**

Replace the highlight loop

```js
  SITES.forEach(function (s) {
    if (!s.hl) return;
    var g = el('g', { 'class': 'hl', 'data-id': s.id }, vp);
    el('path', { 'class': 'casing', d: D.hl[s.id] }, g);
    el('path', { 'class': 'line', d: D.hl[s.id] }, g);
    el('path', { 'class': 'hit', d: D.hl[s.id] }, g);
    hlNodes[s.id] = g;
  });
```

with

```js
  SITES.forEach(function (s) {
    // geo.js draws the original eight; a later site borrows its tappable river's line (same viewport coordinates).
    var d = D.hl[s.id] || (s.tap && TAPBY[s.tap] ? TAPBY[s.tap].d : null);
    if (!s.hl || !d) return;
    var g = el('g', { 'class': 'hl', 'data-id': s.id }, vp);
    el('path', { 'class': 'casing', d: d }, g);
    el('path', { 'class': 'line', d: d }, g);
    el('path', { 'class': 'hit', d: d }, g);
    hlNodes[s.id] = g;
  });
```

- [ ] **Step 4: Open on every report pin**

Replace

```js
  // Typical season and Spawning open on all of Washington. Recent reports opens on the southwest, down to the Columbia (y 356 is 45.54 N, below Camas),
  // so the view does not spend its bottom edge on blank Oregon ground.
  function homeBounds() { return view !== 'reports' ? D.bounds.state : [D.bounds.sw[0], [D.bounds.sw[1][0], 356]]; }
```

with

```js
  // Typical season and Spawning open on all of Washington. Recent reports opens on the southwest box grown to hold every report pin,
  // so the view does not spend its bottom edge on blank Oregon ground and a river added beyond the southwest is on screen.
  function homeBounds() { return view !== 'reports' ? D.bounds.state : Reports.homeBox(SITES.map(function (s) { return s.xy; }), SW_BOX); }
```

- [ ] **Step 5: Name the region the pins cover**

Replace both occurrences of

```js
'Southwest Washington · reports through ' + Reports.formatDay(Reports.latestReport(SITES))
```

with

```js
REGION + ' · reports through ' + Reports.formatDay(Reports.latestReport(SITES))
```

Replace, in `setMode`,

```js
      : 'Map of salmon rivers in southwest Washington. Drag to pan, pinch or use the buttons to zoom, select a river marker for details.');
```

with

```js
      : REPORTS_ARIA);
```

Directly after the `var REGION = …` line from Step 2, add

```js
  var REPORTS_ARIA = 'Map of salmon rivers in ' + (REGION === 'Washington' ? 'Washington' : 'southwest Washington') + '. Drag to pan, pinch or use the buttons to zoom, select a river marker for details.';
```

and directly after the boot line `$('#sub').textContent = REGION + ' · reports through ' + …;` add

```js
  if (view === 'reports') map.setAttribute('aria-label', REPORTS_ARIA);
```

Run: `grep -n "Southwest Washington\|southwest Washington" Artifacts/salmon-rivers/index.html` — Expected: only the static `aria-label` on `#map` (line ~483, overwritten at boot), the `regionName` text is in `reports.js`, and the `REPORTS_ARIA` line.

- [ ] **Step 6: Run the suite**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: 209 pass, 0 fail, 3 skipped.

- [ ] **Step 7: Check the page with a throwaway fixture (do not commit it)**

Temporarily append to the end of `Artifacts/salmon-rivers/reports.js`:

```js
if (typeof window !== 'undefined') window.Reports.SITES.push({ id: 'fx-skagit', name: 'Skagit River', sub: 'Fixture', hl: true, tap: 'skagit-river', ll: [48.42, -122.33], added: '2026-10-25',
  reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-24', d: 'Fixture.', src: { label: 'Fixture', url: 'https://example.org/r' } } } });
```

Start the preview (`preview_start` name `salmon-rivers`), open `http://localhost:4173/index.html?today=2026-10-26` at 390×844 and at 1280×800, and run in the page:

```js
(() => { const pin = document.querySelector('#over .pin[data-id="fx-skagit"]'), g = document.querySelector('.hl[data-id="fx-skagit"]'), r = pin && pin.getBoundingClientRect();
  return { pin: !!pin, inView: !!r && r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight, line: !!g, rc: g && g.style.getPropertyValue('--rc'),
    sub: document.getElementById('sub').textContent, aria: document.getElementById('map').getAttribute('aria-label') }; })()
```

Expected at both sizes: `pin: true`, `inView: true`, `line: true`, `rc: "var(--good)"`, `sub` starts `Washington · reports through Oct 24`, `aria` starts `Map of salmon rivers in Washington.`; no console errors. Take one screenshot at each size. Tap the Skagit line: the report sheet opens with "Fixture" as the source.

Then remove the fixture: `git checkout -- Artifacts/salmon-rivers/reports.js` and confirm `git diff --stat Artifacts/salmon-rivers/reports.js` is empty. Reload: the map looks as before (eight rivers, "Southwest Washington" in `#sub`).

- [ ] **Step 8: Commit**

```bash
git add Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/test/typical.test.js
git commit -m "Draw report sites beyond geo.js from the tappable-river geometry

geo.js has no generator in this repo, so a river added to reports.js
takes its pin from its own ll and its line from rivers-tap.js. The map
opens on every report pin and names the region they cover. With the
eight original rivers nothing on the page changes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/test/typical.test.js
```

---

### Task 4: Page check with a served fixture

**Files:**
- Modify: `Artifacts/salmon-rivers/check-week.mjs` (insert before the line `} finally { await browser.close(); if (server) server.close(); }`)

**Interfaces:**
- Consumes: the page behaviour from Task 3; `browser`, `base`, `today`, `check` already defined in `check-week.mjs`.

- [ ] **Step 1: Add the fixture case**

Insert before `} finally { await browser.close(); if (server) server.close(); }`:

```js
// A report site beyond geo.js (spec 2026-10-26-puget-river-reports): served by intercepting reports.js, so the real data stays unchanged.
const FIXTURE = "\nif (typeof window !== 'undefined') window.Reports.SITES.push({ id: 'fx-skagit', name: 'Skagit River', sub: 'Fixture', hl: true, tap: 'skagit-river', ll: [48.42, -122.33], added: '2026-10-25', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-24', d: 'Fixture.', src: { label: 'Fixture', url: 'https://example.org/r' } } } });\n";
for (const [w, h] of [[390, 844], [1280, 800]]) {
  const fctx = await browser.newContext({ viewport: { width: w, height: h } });
  const fp = await fctx.newPage(); const ferr = [];
  fp.on('pageerror', e => ferr.push(String(e)));
  await fp.route('**/reports.js', async route => { const res = await route.fetch(); await route.fulfill({ response: res, body: (await res.text()) + FIXTURE }); });
  await fp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  const f = await fp.evaluate(() => {
    const pin = document.querySelector('#over .pin[data-id="fx-skagit"]'), g = document.querySelector('.hl[data-id="fx-skagit"]'), r = pin && pin.getBoundingClientRect();
    return { pin: !!pin, inView: !!r && r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight, line: !!g, rc: g ? g.style.getPropertyValue('--rc') : '',
      sub: document.getElementById('sub').textContent, aria: document.getElementById('map').getAttribute('aria-label') };
  });
  check(f.pin && f.inView, `map ${w}px fixture: a site beyond geo.js has a pin inside the opening view`);
  check(f.line && f.rc === 'var(--good)', `map ${w}px fixture: its line comes from the tappable river, coloured by its rating (${f.rc})`);
  check(/^Washington · reports through /.test(f.sub) && /^Map of salmon rivers in Washington\./.test(f.aria), `map ${w}px fixture: the region reads Washington (${f.sub})`);
  check(ferr.length === 0, `map ${w}px fixture: no page errors (${ferr.join(' | ').slice(0, 160)})`);
  await fctx.close();
}
```

- [ ] **Step 2: Run the page check**

Run: `node Artifacts/salmon-rivers/check-week.mjs` (set `PLAYWRIGHT_CORE` to a `playwright-core/index.mjs` if needed).
Expected: the four new `fixture` lines at both widths print `ok`, and the run ends `all checks passed`. If no Playwright browser is installed, the run stops at `browserType.launch`; record "check-week not run: no Playwright browser" for the PR and do not install one without Daniel's OK.

- [ ] **Step 3: Commit**

```bash
git add Artifacts/salmon-rivers/check-week.mjs
git commit -m "Page-check a report site drawn from the tappable-river geometry

The real data has no site beyond geo.js yet, so the check serves a
Skagit fixture through a route and confirms the pin is in the opening
view, the line takes the rating colour and the region reads Washington.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Artifacts/salmon-rivers/check-week.mjs
```

---

### Task 5: First Puget Sound sourcing pass

**Files:**
- Create: `docs/research/2026-10-26-puget-river-reports.md`
- Modify (only if a river qualifies): `Artifacts/salmon-rivers/reports.js` (`SITES`, and `SPECIES` if a new species appears), `Artifacts/salmon-rivers/README.md` (the Recent reports description), `Artifacts/salmon-rivers/artifact.json` (`what`)
- Modify: `TASKS.md`

**Interfaces:**
- Consumes: the rules tested in Task 1.

- [ ] **Step 1: Search each river**

For each of Skagit, Stillaguamish, Snohomish, Green, Puyallup and Nisqually, search for the newest dated salmon catch report from a named shop, guide, guide service or agency (for example The Avid Angler fishing reports, The Guide's Forecast, Captain Experiences guide reports, WDFW written reports). Open each candidate page and copy the exact sentence and its date. Check the river's current WDFW status in `Artifacts/salmon-rivers/rules.js` and on WDFW's emergency-rules page.

- [ ] **Step 2: Write the research note**

Create `docs/research/2026-10-26-puget-river-reports.md`:

```markdown
# Data pass: Puget Sound river catch reports (2026-10-26)

Rules: spec `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md`. A report qualifies if it is from a named shop, guide, guide service or agency, is dated, speaks to salmon catch, is at most 14 days old today, and the river is open for that species.

Format: river | species | rating | verdict | source + date + quote

## Added

(one line per qualifying river and species, or "None this pass.")

## Not added

(one line per river: the newest report found and why it does not qualify: too old, no catch read, trout only, closed, or none found)
```

Fill both sections from Step 1. Every claim carries its URL and the quoted words.

- [ ] **Step 3: Add qualifying rivers (skip if none)**

For each line under "Added", add a `SITES` entry after the Kalama entry, for example:

```js
    { id: 'skagit', name: 'Skagit River', sub: 'Mount Vernon to Marblemount', hl: true, tap: 'skagit-river', ll: [48.42, -122.33], added: '2026-10-26',
      reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-20', d: '<the source sentence, no date in it>',
        src: { label: '<Shop name>, Oct 20', url: 'https://<source url>' } } } },
```

using the note's values. If a species is not yet in `SPECIES`, add its exact app name (check `WAFishMap/Resources/fisheries.json`). Update the README's Recent reports description and `artifact.json` `what` to name the new rivers. Run `node --test "Artifacts/salmon-rivers/test/*.test.js"`: all pass.

- [ ] **Step 4: Record the next pass**

In `TASKS.md`, under `## Tasks`, add:

```markdown
- [ ] Puget Sound river reports: repeat the sourcing pass (spec 2026-10-26-puget-river-reports) when new shop or guide reports appear; a river is added only with a report at most 14 days old. First pass: docs/research/2026-10-26-puget-river-reports.md.
```

- [ ] **Step 5: Commit**

```bash
git add docs/research/2026-10-26-puget-river-reports.md TASKS.md
# plus, only if Step 3 added rivers:
# git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/README.md Artifacts/salmon-rivers/artifact.json
git commit -m "Record the first Puget Sound catch-report pass

Each river's newest named report is written down with its date and
words, and only those inside the 14-day entry rule are added, so the
map never shows a Puget river it cannot source.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/research/2026-10-26-puget-river-reports.md TASKS.md
```

(Add the three data paths to both `git add` and the pathspec if Step 3 changed them.)

---

### Task 6: PR

- [ ] **Step 1: Full run**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"` — Expected: 0 fail.
Run: `node Artifacts/salmon-rivers/check-week.mjs` if a Playwright browser is available.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin spec/puget-river-reports
gh pr create --base main --head spec/puget-river-reports --title "Catch reports for Puget Sound rivers (mechanism and first pass)" --body "<what changes on the page; tests run with counts; check-week run or not run; the research note's outcome; not published>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

The body states what was verified and what was not. Do not publish; after Daniel merges, republish per `Artifacts/salmon-rivers/artifact.json` (read live first) and record the version through a PR.
