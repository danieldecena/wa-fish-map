# Week Page, Deep Links and Tides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fifth tab, Week, to the published Washington Fishing Map that joins open seasons, fresh catch reports, new WDFW rules, upcoming dates, a 7-day NOAA tide table and the spot guides, with every card deep-linking into the exact map state; then run a design critique over the five pages and fix its top three findings.

**Architecture:** Three new UMD modules beside the existing ones in `Artifacts/salmon-rivers/` (`week.js` composes already-published data into a result and renders it; `links.js` reads and writes the map's URL state; `tides.js` builds, fetches and parses NOAA predictions), one new static page `week/index.html`, and a five-tab bar copied verbatim onto all five pages. The map page `index.html` gains one script tag and a `syncLink()` call at each state change. No new data file unless the NOAA spike fails.

**Tech Stack:** Plain ES5 browser JS (UMD modules, no bundler, no deps), `node --test` for unit tests, `playwright-core` for the page check, the claude.ai Artifact tool for publishing. Python is not needed unless the tide fallback is built.

**Spec:** `docs/superpowers/specs/2026-10-26-week-page-and-deep-links-design.md`

## Global Constraints

- Guidance, not regulation: every page keeps the disclaimer and a WDFW link in its footer.
- Rating colours and the words Prime/Good/Fair/Slow/Excellent appear only where `reports.js` or `season.js` already produce them; seasons, rules, milestones and tide heights are text and dates, never a rating colour. "Ends soon" uses the advisory wash (`--warn-wash` / `--warn`).
- Species names on the pages equal the app's exactly; nothing here adds a species name.
- No new paid service, key or subscription. NOAA CO-OPS is keyless.
- `today` comes from `?today=YYYY-MM-DD` when present, else the local calendar date; it is only ever read, never written into a URL.
- URL state uses `history.replaceState`, never `pushState`.
- Every republish passes the main URL `https://claude.ai/artifact/9oA145toRsmFcDYurdJbey` and reads the live version first.
- Work lands through branch `week-page-and-deep-links` and one PR into `main`; Daniel merges. Commits end with the attribution lines in this session's system reminder.
- Tests run with `node --test "Artifacts/salmon-rivers/test/*.test.js"` from the repo root; test files are CommonJS `.test.js` and `require` the UMD modules.
- Tab-bar labels: Week, Map, Year, Spots, Counts, in that order, 15 px, on every page.

---

## File structure

All paths are under `Artifacts/salmon-rivers/` unless noted.

| File | Responsibility |
|------|----------------|
| `links.js` (new) | Parse and serialise the map's URL state. Pure; no DOM except `history`/`location` handed in. |
| `index.html` (modify) | Load `links.js`; apply URL state on boot; call `syncLink()` on every state change; five-tab bar. |
| `week.js` (new) | `Week.build()` composes `FY`, `Reports`, `Rules` into a plain result; `Week.render()` turns a result into DOM. No fetch, no globals. |
| `tides.js` (new) | NOAA station list, nearest-station, URL builder, response parser, loader, table renderer. The site's only network call. |
| `week/index.html` (new) | Static page: styles, tab bar, empty sections, inline boot script that calls `Week` and `Tides`. |
| `spots/index.html`, `year/index.html`, `counts/index.html` (modify) | Five-tab bar only. |
| `test/links.test.js`, `test/week.test.js`, `test/tides.test.js`, `test/tabs.test.js` (new) | Unit tests; `tabs.test.js` asserts the five tab bars are identical copies. |
| `test/fixtures/noaa-seattle.json` (new) | A saved CO-OPS response for parser tests. |
| `check-week.mjs` (new) | Playwright page check over the five pages, local or published; `--shots <dir>` saves the captures the critique uses. |
| `README.md`, `artifact.json` (modify) | Week section; recorded live version. |
| `STATUS.md`, `TASKS.md` (repo root, modify) | Decision log, spike result, follow-ups. |
| `docs/design/2026-10-26-week-critique.md` (new) | The critique's findings. |

---

### Task 0: Repo access, branch, and capture the live page into the repo

The live artifact (version `1792491424-046f`) is newer than the repo snapshot and carries files the repo lacks (`rules.js`, `rivers-tap.js`, the new `sites.js` schema, `year/`, `spots/`, `counts/`, the tab bar). Everything after this task builds on what is actually published.

**Files:**
- Modify: `Artifacts/salmon-rivers/*` (captured files), `Artifacts/salmon-rivers/artifact.json`

**Interfaces:**
- Produces: a branch `week-page-and-deep-links` whose `Artifacts/salmon-rivers/` matches the live version file for file.

- [ ] **Step 1: Get the repo**

Either Daniel allows the `add_repo` call for `danieldecena/wa-fish-map` with push access, or the Mac is linked and the work happens in `~/developer/wa-fish-map`. Do not proceed on the project's `repo/` snapshot docs; they are copies.

```bash
cd ~/developer/wa-fish-map   # or the cloned path
git fetch origin && git checkout main && git pull --ff-only
git checkout -b week-page-and-deep-links
```

- [ ] **Step 2: Download every live file**

With the Artifact tool: `action: "read"`, `url: https://claude.ai/artifact/9oA145toRsmFcDYurdJbey`, `paths:` all sixteen — `cluster.js, counts.js, counts/data.js, counts/index.html, creel.js, geo.js, index.html, reports.js, rivers-tap.js, rules.js, season.js, sites.js, spots/index.html, typical.js, year/data.js, year/index.html`. Note the directory the tool saved them in; call it `$LIVE`.

- [ ] **Step 3: Diff against the repo and copy in**

```bash
diff -rq "$LIVE" Artifacts/salmon-rivers/ | grep -v '^Only in Artifacts' || true
# Expect: rules.js, rivers-tap.js, sites.js, index.html, spots/, year/, counts/ differ or are missing in the repo.
rsync -a --exclude artifact.json "$LIVE"/ Artifacts/salmon-rivers/
git status --short
```

If `index.html` in the repo has changes the live page lacks, stop and show the diff to Daniel before overwriting: the live page wins only when the repo file is simply older.

- [ ] **Step 4: Record the version and run the existing tests**

In `Artifacts/salmon-rivers/artifact.json` set the live version field to `1792491424-046f` and add to its note: `2026-10-26: live version captured; it was published outside the repo and adds rules.js, rivers-tap.js, the year/, spots/ and counts/ subpages and the five... four-tab bar.`

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js"
```

Expected: the existing suite passes (134 tests as of 2026-10-20). If `test/typical.test.js` fails on a stale snapshot, rerun `scripts/build_typical_sites.py` as CLAUDE.md says and re-run; if anything else fails, report it — do not fix unrelated tests here.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers
git commit -m "pages: capture live Washington Fishing Map 1792491424-046f into the repo"
```

---

### Task 1: Spike — can the published origin reach NOAA, and are the station ids right?

**Files:**
- Create (throwaway): `/tmp/tide-probe/index.html`
- Modify: `STATUS.md` (decision log entry)

**Interfaces:**
- Produces: a yes/no recorded in `STATUS.md`, and a verified `STATIONS` list for Task 6.

- [ ] **Step 1: Verify the eleven station ids against NOAA's metadata API**

```bash
for id in 9447130 9446484 9447659 9444900 9449880 9449424 9444090 9443090 9442396 9441102 9440910; do
  curl -s "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/$id.json" \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s).stations[0];console.log(j.id,JSON.stringify(j.name),j.lat,j.lng)})'
done
```

Expected: eleven lines, each a Washington station name with coordinates. Save the output; Task 6 uses these exact names and coordinates. If an id returns an error or a non-Washington name, find the right id by searching `https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions` for the name and replace it. (If the workspace shell cannot reach NOAA, run this on the Mac or in the browser.)

- [ ] **Step 2: Write the probe page**

```html
<!doctype html><meta charset="utf-8"><title>Tide probe</title>
<pre id="out">fetching…</pre>
<script>
var u = 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&datum=MLLW&interval=hilo&units=english&time_zone=lst_ldt&format=json&station=9447130&begin_date=20261026&end_date=20261027';
fetch(u).then(function (r) { return r.json(); }).then(function (j) {
  document.getElementById('out').textContent = j.predictions ? 'OK ' + j.predictions.length + ' extremes' : 'NOAA error: ' + JSON.stringify(j);
}).catch(function (e) { document.getElementById('out').textContent = 'FETCH FAILED: ' + e; });
</script>
```

- [ ] **Step 3: Publish it as a scratch artifact and read the result**

Publish `/tmp/tide-probe/index.html` with the Artifact tool WITHOUT a `url` (a new, throwaway artifact; never the main URL). Open it in the built-in browser and read `#out`.

Expected: `OK 8 extremes` (two days of highs and lows). `FETCH FAILED` means CSP or CORS blocks it from the artifact origin.

- [ ] **Step 4: Record the answer and delete the probe**

Add to `STATUS.md` under the decision log, dated 2026-10-26: `Spike: fetch to api.tidesandcurrents.noaa.gov from a published artifact — <OK n extremes | FETCH FAILED: reason>. Station ids verified: <list>.` Then delete the probe artifact with `action: "delete"` (Daniel confirms).

If it FAILED: before Task 6, add a task "build `week/tides-data.js`" — a Python script `scripts/build_tides.py` that fetches 14 days for every station and writes `window.TIDES = { "9447130": {...predictions json...}, ... }`; `Tides.load` then reads `window.TIDES[station]` instead of fetching. The rest of this plan is unchanged.

- [ ] **Step 5: Commit**

```bash
git add STATUS.md
git commit -m "status: record NOAA fetch spike and verified tide station ids"
```

---

### Task 2: `links.js` — read and write URL state

**Files:**
- Create: `Artifacts/salmon-rivers/links.js`
- Test: `Artifacts/salmon-rivers/test/links.test.js`

**Interfaces:**
- Produces:
  - `Links.MODES` = `['reports','typical','spawning']`
  - `Links.read(search: string) -> { mode: string|null, month: number|null, species: string|null, site: string|null, river: string|null, today: string|null }`
  - `Links.toQuery(state) -> string` (`''` or `'?k=v&…'`)
  - `Links.write(state, history, location) -> void`

- [ ] **Step 1: Write the failing tests**

```js
// Artifacts/salmon-rivers/test/links.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Links = require('../links.js');

test('read: empty search gives all nulls', () => {
  assert.deepEqual(Links.read(''), { mode: null, month: null, species: null, site: null, river: null, today: null });
});

test('read: every key round-trips', () => {
  const r = Links.read('?mode=spawning&month=11&species=Coho%20Salmon&site=enchantment&today=2026-10-26');
  assert.equal(r.mode, 'spawning');
  assert.equal(r.month, 11);
  assert.equal(r.species, 'Coho Salmon');
  assert.equal(r.site, 'enchantment');
  assert.equal(r.today, '2026-10-26');
});

test('read: unknown mode, bad month and bad today read as null', () => {
  const r = Links.read('?mode=heat&month=13&today=yesterday');
  assert.equal(r.mode, null);
  assert.equal(r.month, null);
  assert.equal(r.today, null);
  assert.equal(Links.read('?month=0').month, null);
  assert.equal(Links.read('?month=abc').month, null);
});

test('toQuery: defaults are omitted', () => {
  assert.equal(Links.toQuery({ mode: 'reports' }), '');
  assert.equal(Links.toQuery({ mode: null, species: null }), '');
});

test('toQuery: only keys that apply to the mode are written', () => {
  assert.equal(Links.toQuery({ mode: 'reports', river: 'cowlitz', site: 'x', month: 5 }), '?river=cowlitz');
  assert.equal(Links.toQuery({ mode: 'spawning', month: 11, site: 'enchantment', river: 'cowlitz' }), '?mode=spawning&month=11&site=enchantment');
  assert.equal(Links.toQuery({ mode: 'typical', month: 11, site: 'abc', species: 'Coho Salmon' }), '?mode=typical&species=Coho+Salmon&site=abc');
});

test('toQuery: today is carried when present and never invented', () => {
  assert.equal(Links.toQuery({ mode: 'reports', today: '2026-10-26' }), '?today=2026-10-26');
  assert.equal(Links.toQuery({ mode: 'reports' }).indexOf('today'), -1);
});

test('write: replaceState with pathname + query + hash, and no call when unchanged', () => {
  const calls = [];
  const history = { replaceState: (a, b, url) => calls.push(url) };
  const location = { pathname: '/artifact/x/index.html', search: '', hash: '#top' };
  Links.write({ mode: 'spawning', month: 3 }, history, location);
  assert.deepEqual(calls, ['/artifact/x/index.html?mode=spawning&month=3#top']);
  location.search = '?mode=spawning&month=3';
  Links.write({ mode: 'spawning', month: 3 }, history, location);
  assert.equal(calls.length, 1);
});
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/links.test.js`
Expected: FAIL, `Cannot find module '../links.js'`.

- [ ] **Step 3: Write `links.js`**

```js
// Artifacts/salmon-rivers/links.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Links = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* URL state for the map page. read() parses location.search; write() puts the current state back with
     history.replaceState so a shared link opens on the same mode, month, species and sheet. Never pushState:
     Back leaves the site instead of walking through map taps. `today` is carried through but never invented. */
  var MODES = ['reports', 'typical', 'spawning'];
  /* Which keys mean anything in each mode. Typical season has no month control, so month is spawning-only. */
  var KEYS = { reports: ['species', 'river'], typical: ['species', 'site'], spawning: ['month', 'species', 'site'] };
  var DATE = /^\d{4}-\d{2}-\d{2}$/;

  function params(search) {
    return new URLSearchParams(search && search.charAt(0) === '?' ? search.slice(1) : (search || ''));
  }
  function read(search) {
    var p = params(search);
    var mode = p.get('mode'), month = parseInt(p.get('month') || '', 10), today = p.get('today');
    return {
      mode: MODES.indexOf(mode) >= 0 ? mode : null,
      month: month >= 1 && month <= 12 ? month : null,
      species: p.get('species') || null,
      site: p.get('site') || null,
      river: p.get('river') || null,
      today: today && DATE.test(today) ? today : null
    };
  }
  function toQuery(state) {
    var mode = state && MODES.indexOf(state.mode) >= 0 ? state.mode : 'reports';
    var p = new URLSearchParams();
    if (mode !== 'reports') p.set('mode', mode);
    KEYS[mode].forEach(function (k) {
      var v = state[k];
      if (v !== null && v !== undefined && v !== '') p.set(k, String(v));
    });
    if (state && state.today && DATE.test(state.today)) p.set('today', state.today);
    var s = p.toString();
    return s ? '?' + s : '';
  }
  function write(state, history, location) {
    var q = toQuery(state);
    if ((location.search || '') === q) return;
    history.replaceState(null, '', location.pathname + q + (location.hash || ''));
  }

  return { MODES: MODES, KEYS: KEYS, read: read, toQuery: toQuery, write: write };
});
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `node --test Artifacts/salmon-rivers/test/links.test.js`
Expected: 7 passing.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/links.js Artifacts/salmon-rivers/test/links.test.js
git commit -m "pages: links.js reads and writes the map's URL state"
```

---

### Task 3: Wire deep links into `index.html`

**Files:**
- Modify: `Artifacts/salmon-rivers/index.html` — the `<script src>` block (around line 515), `pickSpecies` (~1123), `openRiver` (~1577), `openSheet` (~1605), `openList` (~1625), `closeSheet` (~1635), `setMonth` (~1520), `setMode` (~1759), the boot lines after `init();` (~1821). Line numbers are from the live version; find them by the function names.

**Interfaces:**
- Consumes: `Links.read`, `Links.write` from Task 2.
- Produces: `syncLink()` inside the page's IIFE; the page honours `?mode=&month=&species=&site=&river=&today=`.

- [ ] **Step 1: Load the module**

After `<script src="sites.js"></script>` add:

```html
<script src="links.js"></script>
```

- [ ] **Step 2: Add `syncLink()` and `speciesKnown()` just above `/* ---- boot ---- */`**

```js
  /* ---- URL state (links.js): what the page shows is what the address bar says ---- */
  var LINK0 = (window.Links && window.Links.read) ? Links.read(location.search) : { mode: null, month: null, species: null, site: null, river: null, today: null };
  function syncLink() {
    if (!window.Links) return;
    var rep = view === 'reports';
    Links.write({
      mode: view,
      month: view === 'spawning' ? SMONTH : null,
      species: species,
      site: !rep && mode === 'detail' ? selected : null,
      river: rep ? (mode === 'detail' ? selected : riverSel) : null,
      today: LINK0.today
    }, window.history, window.location);
  }
  function speciesKnown(name) {
    var found = false;
    document.querySelectorAll('#sppanel button').forEach(function (b) { if (b.getAttribute('data-species') === name) found = true; });
    return found;
  }
```

- [ ] **Step 3: Call `syncLink()` at each state change**

Add `syncLink();` as the last line of: `pickSpecies`, `setMonth` (after the `if (mode === 'detail') …` line), `openRiver` (immediately after `applyStyles(); render();`, before the `if (px == null) return;` line, so the early return does not skip it), `openSheet` (after `animateTo(...)`), `openList` (after `applyStyles(); render();`), `closeSheet` (after `applyStyles(); render();`), and `setMode` (after the final `render();`).

- [ ] **Step 4: Replace the boot regex lines**

Replace these two lines at the end of the IIFE:

```js
  if (/[?&]mode=typical(&|$)/.test(location.search)) setMode('typical');
  else if (/[?&]mode=spawning(&|$)/.test(location.search)) setMode('spawning');
```

with:

```js
  // Deep links (links.js): mode first, then month and species, then the sheet, so each step sees the state the one before it set.
  if (LINK0.mode && LINK0.mode !== 'reports') setMode(LINK0.mode);
  if (LINK0.month && view === 'spawning') setMonth(LINK0.month);
  if (LINK0.species && speciesKnown(LINK0.species)) pickSpecies(LINK0.species);
  if (view === 'reports' && LINK0.river) {
    if (SITES.some(function (s) { return s.id === LINK0.river; })) openSheet(LINK0.river);
    else if (TAPBY[LINK0.river]) openRiver(LINK0.river);
  } else if (view !== 'reports' && LINK0.site && siteOf(LINK0.site)) {
    openSheet(LINK0.site);
  }
  syncLink();
```

- [ ] **Step 5: Check it by hand in a browser**

Serve the folder (`cd Artifacts/salmon-rivers && python3 -m http.server 8787`) and open, one at a time, confirming each:
- `http://localhost:8787/index.html?mode=spawning&month=11&site=enchantment` → Spawning, November selected in the ribbon, the Enchantment Park sheet open, address bar unchanged.
- `…/index.html?mode=reports&river=cowlitz` → the Cowlitz report sheet open; tap Done → address bar becomes `…/index.html` (no query).
- `…/index.html?mode=typical&species=Coho%20Salmon` → Typical season with Coho Salmon chosen; the address bar shows `?mode=typical&species=Coho+Salmon`.
- `…/index.html?site=nonsense&mode=spawning` → Spawning, no sheet, no console error.
- `…/index.html?today=2026-10-01` → stays `?today=2026-10-01` after switching modes.
- Browser Back from any of these leaves the page (no in-page history).

Expected: all six as described. Task 8's page check automates the first, second and fourth.

- [ ] **Step 6: Run the whole Node suite**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: all pass (the map page has no Node tests of its own; this guards the shared modules).

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/index.html
git commit -m "pages: map honours deep links and keeps the address bar in sync"
```

---

### Task 4: `week.js` — `Week.build()`

**Files:**
- Create: `Artifacts/salmon-rivers/week.js`
- Test: `Artifacts/salmon-rivers/test/week.test.js`

**Interfaces:**
- Consumes: `FY` (`{ updated, seasons[], milestones[] }` from `year/data.js`), the `Reports` module (`SITES, SPECIES, LABEL, RANK, STALE_DAYS, describeAge`), the `Rules` module (`RULES, CHECKED`).
- Produces: `Week.build(FY, Reports, Rules, today)`, `Week.range(today)`, `Week.fmt(iso)`, `Week.SPOTS`, constants `Week.RULE_DAYS = 14`, `Week.UPCOMING = 3`. Result shape:

```
{ range: { start, end, days: [7 isos] },
  open:     [{ id, name, where, end, daysLeft, soon, flavor, note, sources: [{ label, url, checked }] }],
  reported: [{ id, name, sub, href, species: [{ name, r, label, release, asOf, age, d, src }] }],
  rules:    [{ rivers, published, d, url }],
  upcoming: [{ kind, date, daysUntil, label, detail }],
  spots:    [{ id, name, sub, href }] }
```

- [ ] **Step 1: Write the failing tests**

```js
// Artifacts/salmon-rivers/test/week.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Week = require('../week.js');
const Reports = require('../reports.js');
const Rules = require('../rules.js');

const season = (id, start, end, extra) => Object.assign({ id, name: id, cat: 'salmon', start, end, flavor: 2, where: 'somewhere', note: 'n', source: { label: 'src', url: 'u', checked: '2026-10-18' } }, extra || {});
const FY0 = { updated: '2026-10-19', seasons: [], milestones: [] };
const R0 = { SITES: [], SPECIES: Reports.SPECIES, LABEL: Reports.LABEL, RANK: Reports.RANK, STALE_DAYS: 7, describeAge: Reports.describeAge };
const RL0 = { RULES: [], CHECKED: '2026-10-20' };

test('range: Monday to Sunday containing today, across month and year boundaries', () => {
  assert.deepEqual(Week.range('2026-10-26').days.slice(0, 1), ['2026-10-26']);          // a Monday
  assert.equal(Week.range('2026-10-26').end, '2026-11-01');
  assert.equal(Week.range('2026-11-01').start, '2026-10-26');                            // Sunday belongs to the week before
  assert.equal(Week.range('2027-01-01').start, '2026-12-28');
  assert.equal(Week.range('2026-10-28').days.length, 7);
});

test('build: every section is present and empty with no data', () => {
  const r = Week.build(FY0, R0, RL0, '2026-10-26');
  assert.deepEqual(r.open, []); assert.deepEqual(r.reported, []); assert.deepEqual(r.rules, []); assert.deepEqual(r.upcoming, []);
  assert.deepEqual(r.spots, Week.SPOTS);
});

test('open now: inclusive at both ends, sorted by end then name, soon within 7 days', () => {
  const FY = { updated: '', milestones: [], seasons: [
    season('b', '2026-10-01', '2026-10-31'), season('a', '2026-10-01', '2026-10-31'),
    season('later', '2026-10-01', '2026-11-30'), season('ended', '2026-09-01', '2026-10-25'), season('future', '2026-10-27', '2026-12-01') ] };
  const r = Week.build(FY, R0, RL0, '2026-10-26');
  assert.deepEqual(r.open.map(s => s.id), ['a', 'b', 'later']);
  assert.equal(r.open[0].daysLeft, 5); assert.equal(r.open[0].soon, true);
  assert.equal(r.open[2].daysLeft, 35); assert.equal(r.open[2].soon, false);
  assert.equal(Week.build(FY, R0, RL0, '2026-10-31').open[0].daysLeft, 0);
  assert.equal(Week.build(FY, R0, RL0, '2026-11-01').open.map(s => s.id).join(), 'later');
  assert.equal(Week.build(FY, R0, RL0, '2026-10-24').open[0].soon, true);   // 7 days exactly
  assert.equal(Week.build(FY, R0, RL0, '2026-10-23').open[0].soon, false);  // 8 days
});

test('open now: sources normalise to an array', () => {
  const FY = { updated: '', milestones: [], seasons: [ season('x', '2026-10-01', '2026-10-31', { source: [{ label: 'p', url: 'u1', checked: '2026-10-18' }, { label: 'q', url: 'u2', checked: '2026-10-18' }] }) ] };
  assert.deepEqual(Week.build(FY, R0, RL0, '2026-10-26').open[0].sources.map(s => s.label), ['p', 'q']);
});

test('reported: 7 days inclusive, null never, species in Reports.SPECIES order, sites by best keepable rating then name', () => {
  const R = Object.assign({}, R0, { SITES: [
    { id: 'z', name: 'Z River', sub: 's', reports: { 'Chinook Salmon': { r: 'good', asOf: '2026-10-19', d: 'c' }, 'Coho Salmon': { r: 'fair', asOf: '2026-10-25', d: 'a' } } },
    { id: 'old', name: 'Old', sub: 's', reports: { 'Coho Salmon': { r: 'prime', asOf: '2026-10-18', d: 'x' } } },
    { id: 'undated', name: 'U', sub: 's', reports: { 'Coho Salmon': { r: 'prime', asOf: null, d: 'x' } } },
    { id: 'rel', name: 'A Release', sub: 's', reports: { 'Chinook Salmon': { r: 'prime', release: true, asOf: '2026-10-26', d: 'r' } } },
    { id: 'g', name: 'G', sub: 's', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-26', d: 'y', src: { label: 'L', url: 'U' } } } } ] });
  const r = Week.build(FY0, R, RL0, '2026-10-26');
  assert.deepEqual(r.reported.map(s => s.id), ['g', 'z', 'rel']);
  assert.deepEqual(r.reported[1].species.map(s => s.name), ['Coho Salmon', 'Chinook Salmon']);
  assert.equal(r.reported[1].species[0].label, 'Fair');
  assert.equal(r.reported[2].species[0].label, 'Excellent, release only');
  assert.equal(r.reported[0].species[0].age, 'Oct 26 · today');
  assert.equal(r.reported[0].href, '../index.html?mode=reports&river=g');
  assert.equal(r.reported[0].species[0].src.label, 'L');
});

test('rules: 14 days inclusive, newest first', () => {
  const RL = { CHECKED: '2026-10-20', RULES: [
    { rivers: ['A'], published: '2026-10-12', d: 'old', url: 'u' },
    { rivers: ['B'], published: '2026-10-16', d: 'mid', url: 'u' },
    { rivers: ['C'], published: '2026-10-26', d: 'new', url: 'u' },
    { rivers: ['D'], published: '2026-10-11', d: 'too old', url: 'u' } ] };
  const r = Week.build(FY0, R0, RL, '2026-10-26');
  assert.deepEqual(r.rules.map(x => x.d), ['new', 'mid', 'old']);
});

test('upcoming: seasons after today and milestones merged by date, capped at 3', () => {
  const FY = { updated: '', seasons: [ season('s1', '2026-11-01', '2026-11-30'), season('s2', '2026-12-10', '2026-12-31'), season('now', '2026-10-01', '2026-10-31') ],
    milestones: [ { date: '2026-11-05', label: 'm1', note: 'note1' }, { date: '2026-10-28', label: 'm0', note: 'note0' } ] };
  const r = Week.build(FY, R0, RL0, '2026-10-26');
  assert.deepEqual(r.upcoming.map(u => u.label), ['m0', 's1', 'm1']);
  assert.deepEqual(r.upcoming.map(u => u.daysUntil), [2, 6, 10]);
  assert.equal(r.upcoming[1].kind, 'season'); assert.equal(r.upcoming[1].detail, 'somewhere');
  assert.equal(r.upcoming[0].kind, 'milestone'); assert.equal(r.upcoming[0].detail, 'note0');
});

test('malformed dates throw', () => {
  assert.throws(() => Week.build(FY0, R0, RL0, '2026-13-01'), /bad date/);
  assert.throws(() => Week.build({ updated: '', milestones: [], seasons: [season('x', '2026-02-30', '2026-03-01')] }, R0, RL0, '2026-10-26'), /bad date/);
});

test('fmt', () => { assert.equal(Week.fmt('2026-11-01'), 'Nov 1'); assert.equal(Week.fmtDow('2026-11-01'), 'Sun Nov 1'); });

test('the real published data builds without throwing', () => {
  // year/data.js sets window.FY; evaluate it the way the page does.
  const fs = require('node:fs'), path = require('node:path');
  const w = {}; new Function('window', fs.readFileSync(path.join(__dirname, '..', 'year', 'data.js'), 'utf8'))(w);
  const r = Week.build(w.FY, Reports, Rules, '2026-10-26');
  assert.ok(r.range.days.length === 7);
});
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/week.test.js`
Expected: FAIL, `Cannot find module '../week.js'`.

- [ ] **Step 3: Write `week.js` (build half; `render` comes in Task 5)**

```js
// Artifacts/salmon-rivers/week.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Week = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* "This week": composes what the site already publishes — dated seasons and milestones (year/data.js), dated catch reports
     (reports.js) and dated WDFW notices (rules.js) — into one result. Nothing here is a rating of its own: report badges reuse
     reports.js' word and token; seasons, rules, milestones and tides are dates and text. Guidance, not regulation. */
  var DAY = 86400000, RULE_DAYS = 14, UPCOMING = 3;
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  /* Spot guides, until the spot-guide template sub-project turns these into data. */
  var SPOTS = [{ id: 'three-friends', name: 'Three Friends Fishing Hole', sub: 'Green River · Kent', href: '../spots/index.html' }];

  /* UTC day number for YYYY-MM-DD; throws on anything else, the same rule as reports.js. */
  function dayNum(iso) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso));
    if (!m) throw new Error('bad date: ' + iso);
    var ms = Date.UTC(+m[1], +m[2] - 1, +m[3]), d = new Date(ms);
    if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) throw new Error('bad date: ' + iso);
    return ms / DAY;
  }
  function isoOf(n) { return new Date(n * DAY).toISOString().slice(0, 10); }
  function fmt(iso) { var d = new Date(dayNum(iso) * DAY); return MONTHS[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  function fmtDow(iso) { return DOW[new Date(dayNum(iso) * DAY).getUTCDay()] + ' ' + fmt(iso); }
  function range(today) {
    var t = dayNum(today), mon = t - ((new Date(t * DAY).getUTCDay() + 6) % 7), days = [];
    for (var i = 0; i < 7; i++) days.push(isoOf(mon + i));
    return { start: days[0], end: days[6], days: days };
  }
  function sources(src) { return !src ? [] : Array.isArray(src) ? src : [src]; }
  function byDateThenLabel(a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : a.label < b.label ? -1 : a.label > b.label ? 1 : 0; }

  function openNow(seasons, t) {
    return seasons.filter(function (s) { return dayNum(s.start) <= t && t <= dayNum(s.end); })
      .map(function (s) {
        var left = dayNum(s.end) - t;
        return { id: s.id, name: s.name, where: s.where || '', end: s.end, daysLeft: left, soon: left <= 7, flavor: s.flavor, note: s.note || '', sources: sources(s.source) };
      })
      .sort(function (a, b) { return a.end < b.end ? -1 : a.end > b.end ? 1 : a.name < b.name ? -1 : a.name > b.name ? 1 : 0; });
  }
  function reported(R, today) {
    var t = dayNum(today), out = [];
    R.SITES.forEach(function (site) {
      var have = site.reports || {}, rows = [];
      R.SPECIES.forEach(function (k) {
        var sp = have[k];
        if (!sp || !sp.asOf) return;
        if (t - dayNum(sp.asOf) > R.STALE_DAYS) return;
        rows.push({ name: k, r: sp.r, label: R.LABEL[sp.r] + (sp.release ? ', release only' : ''), release: !!sp.release, asOf: sp.asOf, age: R.describeAge(sp.asOf, today), d: sp.d, src: sp.src || null });
      });
      if (!rows.length) return;
      var keep = rows.filter(function (x) { return !x.release; });
      var best = Math.max.apply(null, (keep.length ? keep : rows).map(function (x) { return R.RANK[x.r]; }));
      out.push({ id: site.id, name: site.name, sub: site.sub || '', href: '../index.html?mode=reports&river=' + encodeURIComponent(site.id), species: rows, _keep: keep.length > 0, _best: best });
    });
    out.sort(function (a, b) {
      if (a._keep !== b._keep) return a._keep ? -1 : 1;
      if (a._best !== b._best) return b._best - a._best;
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
    out.forEach(function (o) { delete o._keep; delete o._best; });
    return out;
  }
  function newRules(rules, t) {
    return rules.filter(function (r) { return t - dayNum(r.published) <= RULE_DAYS && dayNum(r.published) <= t; })
      .map(function (r) { return { rivers: r.rivers.slice(), published: r.published, d: r.d, url: r.url }; })
      .sort(function (a, b) { return a.published < b.published ? 1 : a.published > b.published ? -1 : 0; });
  }
  function upcoming(FY, t) {
    var items = [];
    FY.seasons.forEach(function (s) { if (dayNum(s.start) > t) items.push({ kind: 'season', date: s.start, label: s.name, detail: s.where || '' }); });
    (FY.milestones || []).forEach(function (m) { if (dayNum(m.date) > t) items.push({ kind: 'milestone', date: m.date, label: m.label, detail: m.note || '' }); });
    items.sort(byDateThenLabel);
    return items.slice(0, UPCOMING).map(function (i) { i.daysUntil = dayNum(i.date) - t; return i; });
  }

  function build(FY, R, RL, today) {
    var t = dayNum(today);
    return {
      range: range(today),
      open: openNow(FY.seasons || [], t),
      reported: reported(R, today),
      rules: newRules(RL.RULES || [], t),
      upcoming: upcoming(FY, t),
      spots: SPOTS.slice()
    };
  }

  return { SPOTS: SPOTS, RULE_DAYS: RULE_DAYS, UPCOMING: UPCOMING, MONTHS: MONTHS, dayNum: dayNum, isoOf: isoOf, fmt: fmt, fmtDow: fmtDow, range: range, build: build };
});
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `node --test Artifacts/salmon-rivers/test/week.test.js`
Expected: 10 passing. If `reported` ordering differs, re-read the sort: keepable sites first, then higher `RANK`, then name.

- [ ] **Step 5: Commit**

```bash
git add Artifacts/salmon-rivers/week.js Artifacts/salmon-rivers/test/week.test.js
git commit -m "pages: Week.build composes seasons, reports, rules and milestones for the week"
```

---

### Task 5: `Week.render()`, the Week page, and the five-tab bar

**Files:**
- Modify: `Artifacts/salmon-rivers/week.js` (add `render`)
- Create: `Artifacts/salmon-rivers/week/index.html`
- Modify: `Artifacts/salmon-rivers/index.html`, `spots/index.html`, `year/index.html`, `counts/index.html` (tab bar `<nav>` only)
- Test: `Artifacts/salmon-rivers/test/week.test.js` (render tests), `Artifacts/salmon-rivers/test/tabs.test.js`

**Interfaces:**
- Consumes: `Week.build` result (Task 4).
- Produces: `Week.render(result, doc) -> Element` (a `<div class="week">` holding five `<section>`s with ids `open`, `reported`, `rules`, `upcoming`, `spots`); the page reserves `<section id="tides">` between `reported` and `rules` for Task 7; `test/tabs.test.js` exports `tabsHtml(depth, current)`.

- [ ] **Step 1: Write the failing render tests (append to `week.test.js`)**

```js
const { JSDOM } = (() => { try { return require('jsdom'); } catch (e) { return { JSDOM: null }; } })();
// jsdom is not a dependency of this repo. render() only uses document.createElement/createTextNode/appendChild/setAttribute,
// so a 40-line fake document is enough and keeps the suite dependency-free.
function fakeDoc() {
  function El(tag) { this.tagName = tag; this.children = []; this.attrs = {}; this.text = ''; }
  El.prototype.appendChild = function (c) { this.children.push(c); return c; };
  El.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };
  Object.defineProperty(El.prototype, 'textContent', { get() { return this.text + this.children.map(c => c.textContent).join(''); }, set(v) { this.text = String(v); this.children = []; } });
  Object.defineProperty(El.prototype, 'className', { get() { return this.attrs['class'] || ''; }, set(v) { this.attrs['class'] = v; } });
  Object.defineProperty(El.prototype, 'id', { get() { return this.attrs.id || ''; }, set(v) { this.attrs.id = v; } });
  Object.defineProperty(El.prototype, 'href', { set(v) { this.attrs.href = v; }, get() { return this.attrs.href; } });
  El.prototype.querySelectorAll = function (sel) {
    const out = [], m = /^([a-z]+)?(?:\.([\w-]+))?$/.exec(sel);
    (function walk(n) { n.children.forEach(c => { if ((!m[1] || c.tagName === m[1]) && (!m[2] || (c.className || '').split(' ').includes(m[2]))) out.push(c); walk(c); }); })(this);
    return out;
  };
  El.prototype.querySelector = function (sel) { return this.querySelectorAll(sel)[0] || null; };
  return { createElement: t => new El(t), createTextNode: t => ({ tagName: '#text', children: [], textContent: String(t) }) };
}

test('render: five sections, empty ones say Nothing this week', () => {
  const el = Week.render(Week.build(FY0, R0, RL0, '2026-10-26'), fakeDoc());
  const ids = el.querySelectorAll('section').map(s => s.id);
  assert.deepEqual(ids, ['open', 'reported', 'rules', 'upcoming', 'spots']);
  assert.ok(el.querySelector('section').textContent.includes('Nothing this week'));
  assert.ok(el.querySelectorAll('section')[4].textContent.includes('Three Friends Fishing Hole'));
});

test('render: ends-soon chip, rating badge token, rule link', () => {
  const FY = { updated: '', milestones: [], seasons: [ season('skagit-coho', '2026-10-01', '2026-10-31', { name: 'Skagit coho' }) ] };
  const R = Object.assign({}, R0, { SITES: [{ id: 'g', name: 'G River', sub: 's', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-26', d: 'y' } } }] });
  const RL = { CHECKED: '2026-10-20', RULES: [{ rivers: ['Hoh River'], published: '2026-10-16', d: 'closing', url: 'https://wdfw.wa.gov/x' }] };
  const el = Week.render(Week.build(FY, R, RL, '2026-10-26'), fakeDoc());
  assert.ok(el.querySelector('.soon'), 'ends-soon chip rendered');
  assert.equal(el.querySelector('.soon').textContent, 'ends Oct 31 · 5 days');
  const badge = el.querySelector('.badge');
  assert.equal(badge.attrs.style, '--c:var(--good)');
  assert.equal(badge.textContent, 'Good');
  const rule = el.querySelectorAll('a').find(a => a.attrs.href === 'https://wdfw.wa.gov/x');
  assert.equal(rule.textContent, 'Read the rule');
  assert.ok(el.querySelectorAll('a').some(a => a.attrs.href === '../index.html?mode=reports&river=g'));
});
```

- [ ] **Step 2: Run to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/week.test.js`
Expected: FAIL, `Week.render is not a function`.

- [ ] **Step 3: Add `render` to `week.js`** (inside the factory, before the `return`; add `render: render` to the returned object)

```js
  /* ---- render: a plain DOM builder. doc is window.document on the page and a fake in tests. ---- */
  function render(res, doc) {
    function el(tag, cls, text) { var e = doc.createElement(tag); if (cls) e.className = cls; if (text !== undefined && text !== null) e.textContent = text; return e; }
    function link(href, text, ext) { var a = el('a', null, text); a.setAttribute('href', href); if (ext) { a.setAttribute('target', '_blank'); a.setAttribute('rel', 'noopener'); } return a; }
    function section(id, caption, lede) {
      var s = el('section', 'group'); s.id = id; s.setAttribute('aria-labelledby', 'cap-' + id);
      var h = el('h2', 'cap', caption); h.id = 'cap-' + id; s.appendChild(h);
      if (lede) s.appendChild(el('p', 'lede-s', lede));
      var panel = el('div', 'panel'); s.appendChild(panel);
      var ul = el('ul', 'list'); panel.appendChild(ul);
      return { s: s, ul: ul };
    }
    function empty(ul) { var li = el('li', 'row empty'); li.appendChild(el('span', 'v', 'Nothing this week')); ul.appendChild(li); }
    function days(n, past) { return n === 0 ? (past ? 'today' : 'today') : n === 1 ? '1 day' : n + ' days'; }
    var root = el('div', 'week');

    var o = section('open', 'Open now');
    if (!res.open.length) empty(o.ul);
    res.open.forEach(function (s) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(el('span', 'nm', s.name));
      if (s.where) k.appendChild(el('span', 'sub', s.where));
      var when = el('span', s.soon ? 'chip soon' : 'dt', 'ends ' + fmt(s.end) + ' · ' + days(s.daysLeft));
      k.appendChild(when);
      if (s.note) v.appendChild(el('p', 'note', s.note));
      if (s.sources.length) {
        var src = el('p', 'src');
        s.sources.forEach(function (x, i) { if (i) src.appendChild(doc.createTextNode(' · ')); src.appendChild(x.url ? link(x.url, x.label, true) : el('span', null, x.label)); if (x.checked) src.appendChild(doc.createTextNode(' (checked ' + fmt(x.checked) + ')')); });
        v.appendChild(src);
      }
      li.appendChild(k); li.appendChild(v); o.ul.appendChild(li);
    });
    root.appendChild(o.s);

    var r = section('reported', 'Reported this week', 'Catch reports, not season dates. Badges use the map’s own words.');
    if (!res.reported.length) empty(r.ul);
    res.reported.forEach(function (site) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(link(site.href, site.name));
      if (site.sub) k.appendChild(el('span', 'sub', site.sub));
      site.species.forEach(function (sp) {
        var line = el('p', 'rep');
        var b = el('span', 'badge', sp.label); b.setAttribute('style', '--c:var(--' + sp.r + ')');
        line.appendChild(b); line.appendChild(doc.createTextNode(' ' + sp.name + ' · ' + sp.age + ' — ' + sp.d));
        if (sp.src && sp.src.url) { line.appendChild(doc.createTextNode(' ')); line.appendChild(link(sp.src.url, sp.src.label, true)); }
        v.appendChild(line);
      });
      li.appendChild(k); li.appendChild(v); r.ul.appendChild(li);
    });
    root.appendChild(r.s);

    var u = section('rules', 'New rules', 'WDFW’s own wording, published in the last ' + RULE_DAYS + ' days.');
    if (!res.rules.length) empty(u.ul);
    res.rules.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(el('span', 'nm', x.rivers.join(', ')));
      k.appendChild(el('span', 'sub', 'WDFW · published ' + fmt(x.published)));
      v.appendChild(el('p', 'note', x.d));
      v.appendChild(link(x.url, 'Read the rule', true));
      li.appendChild(k); li.appendChild(v); u.ul.appendChild(li);
    });
    root.appendChild(u.s);

    var c = section('upcoming', 'Coming up');
    if (!res.upcoming.length) empty(c.ul);
    res.upcoming.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(el('span', 'nm', x.label));
      k.appendChild(el('span', 'dt', (x.kind === 'season' ? 'opens ' : '') + fmt(x.date) + ' · in ' + days(x.daysUntil)));
      if (x.detail) v.appendChild(el('p', 'note', x.detail));
      li.appendChild(k); li.appendChild(v); c.ul.appendChild(li);
    });
    root.appendChild(c.s);

    var p = section('spots', 'Spots');
    res.spots.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k');
      k.appendChild(link(x.href, x.name)); k.appendChild(el('span', 'sub', x.sub));
      li.appendChild(k); p.ul.appendChild(li);
    });
    root.appendChild(p.s);
    return root;
  }
```

- [ ] **Step 4: Run the render tests**

Run: `node --test Artifacts/salmon-rivers/test/week.test.js`
Expected: 12 passing.

- [ ] **Step 5: Write `test/tabs.test.js`** — the single source of truth for the tab bar

```js
// Artifacts/salmon-rivers/test/tabs.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');

const TABS = [['week', 'Week'], ['', 'Map'], ['year', 'Year'], ['spots', 'Spots'], ['counts', 'Counts']];
/* depth 0 = index.html at the artifact root; depth 1 = a subpage folder. current = the folder key of the page ('' for Map). */
function tabsHtml(depth, current) {
  const up = depth ? '../' : '';
  return '<nav class="apptabs" aria-label="Washington Fishing Map"><div class="apptabs-track">' + TABS.map(([key, label]) => {
    const href = key === current ? 'index.html' : up + (key ? key + '/' : '') + 'index.html';
    return '<a href="' + href + '"' + (key === current ? ' aria-current="page"' : '') + '>' + label + '</a>';
  }).join('') + '</div></nav>';
}
module.exports = { tabsHtml, TABS };

const PAGES = [['index.html', 0, ''], ['week/index.html', 1, 'week'], ['year/index.html', 1, 'year'], ['spots/index.html', 1, 'spots'], ['counts/index.html', 1, 'counts']];
for (const [file, depth, current] of PAGES) {
  test('tab bar on ' + file + ' is the shared five-tab bar', () => {
    const html = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    const m = /<nav class="apptabs"[\s\S]*?<\/nav>/.exec(html);
    assert.ok(m, 'has a tab bar');
    assert.equal(m[0], tabsHtml(depth, current));
    assert.equal((html.match(/<nav class="apptabs"/g) || []).length, 1, 'exactly one tab bar');
  });
}
```

- [ ] **Step 6: Run it to see the four existing pages fail (they have four tabs) and the Week page is missing**

Run: `node --test Artifacts/salmon-rivers/test/tabs.test.js`
Expected: 5 failing.

- [ ] **Step 7: Replace the `<nav class="apptabs">…</nav>` in the four existing pages**

Each page has exactly one such element; replace it with the output of `tabsHtml` for that page. Quickest and least error-prone:

```bash
cd Artifacts/salmon-rivers && node -e '
const fs=require("fs"); const {tabsHtml}=require("./test/tabs.test.js");
for (const [f,d,c] of [["index.html",0,""],["year/index.html",1,"year"],["spots/index.html",1,"spots"],["counts/index.html",1,"counts"]]) {
  const s=fs.readFileSync(f,"utf8"); const out=s.replace(/<nav class="apptabs"[\s\S]*?<\/nav>/, tabsHtml(d,c)); if (out===s) throw new Error("no nav in "+f); fs.writeFileSync(f,out); }'
```

(Requiring the test file runs its tests once as a side effect; that is harmless here.)

- [ ] **Step 8: Write `week/index.html`**

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>This Week</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
/* Layout: the Spots page's grouped-panel column in Artifact Kit tokens; rating colours from WA Fish Map; the shared app tab bar on top. */
:root {
  --bg: #F2F2F7; --surface: #FFFFFF; --ink: #1D1D1F; --soft: #636366; --hair: #D1D1D6;
  --fill: rgba(118,118,128,0.12); --accent: #0058B9; --warn: #C73300; --warn-wash: #FCECD3;
  --prime: #FF3B30; --good: #FF9500; --fair: #FFCC00; --slow: #007AFF; --unrated: #8E8E93;
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro", system-ui, sans-serif;
  --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro", system-ui, sans-serif;
  --mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #000000; --surface: #1C1C1E; --ink: #F5F5F7; --soft: #98989D; --hair: #38383A;
    --fill: rgba(118,118,128,0.24); --accent: #5DABFF; --warn: #FFB340; --warn-wash: #513914;
    --prime: #FF453A; --good: #FF9F0A; --fair: #FFD60A; --slow: #0A84FF; --unrated: #98989D; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #000000; --surface: #1C1C1E; --ink: #F5F5F7; --soft: #98989D; --hair: #38383A;
  --fill: rgba(118,118,128,0.24); --accent: #5DABFF; --warn: #FFB340; --warn-wash: #513914;
  --prime: #FF453A; --good: #FF9F0A; --fair: #FFD60A; --slow: #0A84FF; --unrated: #98989D; color-scheme: dark;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: var(--font); }
.wrap { max-width: 640px; margin: 0 auto; display: flex; flex-direction: column; gap: 20px; padding-block: 20px 32px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
header { display: flex; flex-direction: column; gap: 6px; padding-top: 8px; }
.kicker { font: 600 12px/16px var(--font); letter-spacing: 0.04em; text-transform: uppercase; color: var(--soft); }
h1 { margin: 0; font: 700 34px/41px var(--font-display); letter-spacing: -0.02em; text-wrap: balance; }
.lede { margin: 0; font: 400 15px/22px var(--font); color: var(--soft); max-width: 60ch; }
.week { display: flex; flex-direction: column; gap: 20px; }
.group { display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.cap { margin: 0; padding-left: 4px; font: 600 12px/16px var(--font); letter-spacing: 0.04em; text-transform: uppercase; color: var(--soft); }
.lede-s { margin: -4px 0 0; padding-left: 4px; font: 400 13px/18px var(--font); color: var(--soft); }
.panel { background: var(--surface); border-radius: 14px; min-width: 0; }
.list { margin: 0; padding: 0; list-style: none; }
.row { display: grid; grid-template-columns: 150px minmax(0, 1fr); gap: 4px 12px; padding: 12px 16px; }
.row + .row { border-top: 0.5px solid var(--hair); }
.row.empty { grid-template-columns: 1fr; }
.k { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.nm, .k > a { font: 600 15px/20px var(--font); color: var(--ink); text-decoration: none; }
.k > a { color: var(--accent); }
.sub, .dt { font: 400 13px/18px var(--font); color: var(--soft); }
.v { font: 400 15px/20px var(--font); color: var(--soft); min-width: 0; }
.v p { margin: 0; }
.v p + p { margin-top: 6px; }
.note { color: var(--ink); font-size: 14px; line-height: 19px; }
.src { font: 400 13px/18px var(--font); }
.src a, .v a { color: var(--accent); }
.rep { font-size: 14px; line-height: 20px; }
.badge { display: inline-flex; align-items: center; padding: 1px 8px; border-radius: 999px; font: 600 12px/16px var(--font);
  background: color-mix(in srgb, var(--c) 20%, transparent); border: 1px solid var(--c); color: var(--ink); white-space: nowrap; vertical-align: 1px; }
.chip { display: inline-block; align-self: flex-start; margin-top: 2px; padding: 2px 8px; border-radius: 6px; font: 600 12px/16px var(--font); }
.chip.soon { background: var(--warn-wash); color: var(--warn); }
/* tides table (filled by tides.js) */
.tides-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.tides-head select { min-height: 44px; max-width: 60%; border: 0.5px solid var(--hair); border-radius: 10px; background: var(--surface); color: var(--ink); font: 600 14px/20px var(--font); padding: 0 10px; }
table.tides { width: 100%; border-collapse: collapse; font: 400 14px/20px var(--font); font-variant-numeric: tabular-nums; }
table.tides th, table.tides td { padding: 10px 16px; text-align: left; vertical-align: top; }
table.tides tr + tr th, table.tides tr + tr td { border-top: 0.5px solid var(--hair); }
table.tides th { font-weight: 600; white-space: nowrap; width: 110px; }
table.tides tr.today th { color: var(--accent); }
table.tides .ex { display: inline-block; margin-right: 12px; white-space: nowrap; }
table.tides .ex.next { font-weight: 700; color: var(--ink); }
table.tides .ex.L { color: var(--soft); }
table.tides tr.today .ex.L { color: var(--soft); }
.fine { margin: 0; padding: 0 4px; font: 400 13px/18px var(--font); color: var(--soft); }
.foot { margin: 0; padding: 0 4px; font: 400 13px/20px var(--font); color: var(--soft); }
.foot a { color: var(--accent); }
@media (max-width: 480px) { .row { grid-template-columns: 1fr; gap: 4px; } h1 { font-size: 30px; line-height: 36px; } table.tides th { width: auto; } }
</style>
<style>
/* App tab bar: Week | Map | Year | Spots | Counts. An App Kit SegmentedControl on a glass bar. The block is the same on every page; test/tabs.test.js asserts it. */
.apptabs{--tab-glass:rgba(255,255,255,.55);--tab-glass-solid:rgba(255,255,255,.92);--tab-hair:#D1D1D6;--tab-track:#E5E5EA;--tab-seg:#FFFFFF;--tab-seg-shadow:0 1px 2px rgba(0,0,0,.12);--tab-ink:#1D1D1F;--tab-ink-soft:#636366;--tab-accent:#007AFF;--tab-font:-apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro",system-ui,sans-serif}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]) .apptabs{--tab-glass:rgba(44,44,46,.55);--tab-glass-solid:rgba(44,44,46,.92);--tab-hair:#38383A;--tab-track:#2C2C2E;--tab-seg:#636366;--tab-seg-shadow:0 1px 2px rgba(0,0,0,.5);--tab-ink:#F5F5F7;--tab-ink-soft:#98989D;--tab-accent:#0A84FF}}
:root[data-theme=dark] .apptabs{--tab-glass:rgba(44,44,46,.55);--tab-glass-solid:rgba(44,44,46,.92);--tab-hair:#38383A;--tab-track:#2C2C2E;--tab-seg:#636366;--tab-seg-shadow:0 1px 2px rgba(0,0,0,.5);--tab-ink:#F5F5F7;--tab-ink-soft:#98989D;--tab-accent:#0A84FF}
html{scroll-padding-top:calc(env(safe-area-inset-top,0px) + 56px)}
.apptabs{position:sticky;top:env(safe-area-inset-top,0px);z-index:1000;box-sizing:border-box;padding:6px max(16px,env(safe-area-inset-right,0px)) 6px max(16px,env(safe-area-inset-left,0px))}
.apptabs::before{content:"";position:absolute;z-index:-1;left:0;right:0;bottom:0;top:calc(-1 * env(safe-area-inset-top,0px));background:var(--tab-glass);-webkit-backdrop-filter:saturate(180%) blur(16px);backdrop-filter:saturate(180%) blur(16px);box-shadow:0 .5px 0 var(--tab-hair)}
@supports not ((backdrop-filter:blur(1px)) or (-webkit-backdrop-filter:blur(1px))){.apptabs::before{background:var(--tab-glass-solid)}}
.apptabs-track{display:flex;box-sizing:border-box;max-width:420px;height:44px;margin:0 auto;padding:0 3px;border-radius:10px;background:var(--tab-track)}
.apptabs a{position:relative;z-index:0;flex:1 1 0;min-width:0;display:flex;align-items:center;justify-content:center;height:44px;padding:0 4px;color:var(--tab-ink-soft);font:600 15px/20px var(--tab-font);text-decoration:none;white-space:nowrap;outline:none;-webkit-tap-highlight-color:transparent;-webkit-user-select:none;user-select:none;transition:color 150ms ease-out,opacity 150ms ease-out}
.apptabs a::before{content:"";position:absolute;z-index:-1;inset:3px 0;border-radius:7px;transition:background-color 150ms ease-out}
.apptabs a[aria-current=page]{color:var(--tab-ink)}
.apptabs a[aria-current=page]::before{background:var(--tab-seg);box-shadow:var(--tab-seg-shadow)}
@media (hover:hover){.apptabs a:not([aria-current=page]):hover{color:var(--tab-ink)}}
.apptabs a:not([aria-current=page]):active{opacity:.55}
.apptabs a:focus-visible{z-index:1}
.apptabs a:focus-visible::before{outline:2px solid var(--tab-accent);outline-offset:2px}
@media (max-width:389px){.apptabs a{font-size:14px}}
@media (prefers-reduced-motion:reduce){.apptabs a,.apptabs a::before{transition:none}}
</style>
</head><body>
<nav class="apptabs" aria-label="Washington Fishing Map"><div class="apptabs-track"><a href="index.html" aria-current="page">Week</a><a href="../index.html">Map</a><a href="../year/index.html">Year</a><a href="../spots/index.html">Spots</a><a href="../counts/index.html">Counts</a></div></nav>
<div class="wrap">
  <header>
    <div class="kicker" id="range">This week</div>
    <h1>This week</h1>
    <p class="lede">Guidance, not regulation. Confirm seasons, limits and closures on WDFW before you go.</p>
  </header>
  <div id="week" class="week"></div>
  <p class="foot" id="foot">Seasons from Washington Fishing Year. Reports and rules are dated and sourced on each row. Read <a href="https://wdfw.wa.gov/fishing/regulations/emergency-rules" target="_blank" rel="noopener">WDFW emergency rules</a> and the <a href="https://wdfw.wa.gov/fishing/regulations" target="_blank" rel="noopener">WDFW fishing regulations</a> the morning you go.</p>
</div>
<script src="../year/data.js"></script>
<script src="../reports.js"></script>
<script src="../rules.js"></script>
<script src="../week.js"></script>
<script src="../tides.js"></script>
<script>
(function () {
  'use strict';
  function localToday() { var d = new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
  var ov = /[?&]today=(\d{4}-\d{2}-\d{2})/.exec(location.search);
  var TODAY = ov ? ov[1] : localToday();
  var res = Week.build(window.FY, window.Reports, window.Rules, TODAY);
  var root = Week.render(res, document);
  document.getElementById('range').textContent = Week.fmtDow(res.range.start) + ' – ' + Week.fmtDow(res.range.end);
  document.getElementById('week').appendChild(root);
  document.getElementById('foot').insertAdjacentText('afterbegin', 'Seasons updated ' + Week.fmt(window.FY.updated) + '. ');
  // Tides go between Reported this week and New rules (tides.js, Task 7). The section is created here so the page shape is stable even before the request answers.
  if (window.Tides && Tides.mount) Tides.mount(root, document.getElementById('reported'), res.range, TODAY, document);
})();
</script>
</body></html>
```

- [ ] **Step 9: Run the tab test and the whole suite**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: all pass, including five tab-bar tests.

- [ ] **Step 10: Look at the page**

Serve the folder (`python3 -m http.server 8787` in `Artifacts/salmon-rivers`), open `http://localhost:8787/week/index.html?today=2026-10-26` at 390 px and 1024 px, light and dark. Expected: five sections, Skagit coho under Open now with an orange-washed "ends Oct 31 · 5 days" chip, Reported this week listing Cowlitz and Kalama (asOf 2026-10-17 is 9 days old — so with `today=2026-10-26` Reported shows "Nothing this week"; try `?today=2026-10-20` to see rows), New rules showing the Hoh/Quillayute and Skagit notices, Coming up with "Check Skykomish and Snoqualmie", Spots with Three Friends. No console errors except `Tides is not defined` is NOT acceptable: the page guards with `window.Tides &&`, so there must be none. `tides.js` does not exist yet, so the browser logs a 404 for it — expected until Task 6.

- [ ] **Step 11: Commit**

```bash
git add Artifacts/salmon-rivers/week.js Artifacts/salmon-rivers/week/index.html Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/year/index.html Artifacts/salmon-rivers/spots/index.html Artifacts/salmon-rivers/counts/index.html Artifacts/salmon-rivers/test
git commit -m "pages: This week page, Week.render, and the five-tab bar on every page"
```

---

### Task 6: `tides.js` — stations, URL, parser, loader

**Files:**
- Create: `Artifacts/salmon-rivers/tides.js`
- Create: `Artifacts/salmon-rivers/test/fixtures/noaa-seattle.json`
- Test: `Artifacts/salmon-rivers/test/tides.test.js`

**Interfaces:**
- Produces: `Tides.STATIONS`, `Tides.DEFAULT = '9447130'`, `Tides.nearest(lat, lon)`, `Tides.byId(id)`, `Tides.url(station, range)`, `Tides.parse(json, range)`, `Tides.load(station, range, fetchFn)`, `Tides.fmtTime('03:12') -> '3:12 am'`. `range` is `Week.range()`'s shape (`{ start, end, days }`).

- [ ] **Step 1: Save a real NOAA response as the fixture**

```bash
mkdir -p Artifacts/salmon-rivers/test/fixtures
curl -s 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&datum=MLLW&interval=hilo&units=english&time_zone=lst_ldt&format=json&station=9447130&begin_date=20261026&end_date=20261101' \
  -o Artifacts/salmon-rivers/test/fixtures/noaa-seattle.json
node -e 'const j=require("./Artifacts/salmon-rivers/test/fixtures/noaa-seattle.json");console.log(j.predictions.length, j.predictions[0])'
```

Expected: about 26–28 predictions, the first like `{ t: '2026-10-26 0H:MM', v: '…', type: 'H' | 'L' }`. If the shell cannot reach NOAA, fetch it from the Mac and copy the file in. The tests below read counts from the fixture rather than hard-coding them, except the first day, which the test asserts has at least two extremes.

- [ ] **Step 2: Write the failing tests**

```js
// Artifacts/salmon-rivers/test/tides.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Tides = require('../tides.js');
const Week = require('../week.js');
const fixture = require('./fixtures/noaa-seattle.json');
const range = Week.range('2026-10-26'); // Mon Oct 26 – Sun Nov 1, matches the fixture's dates

test('stations: eleven Washington stations with the default present', () => {
  assert.equal(Tides.STATIONS.length, 11);
  assert.ok(Tides.byId(Tides.DEFAULT));
  assert.equal(Tides.byId('nope'), null);
  Tides.STATIONS.forEach(s => { assert.match(s.id, /^\d{7}$/); assert.ok(s.lat > 45 && s.lat < 49.1 && s.lon < -122 && s.lon > -125.5, s.name); });
});

test('nearest: Ballard -> Seattle, Grays Harbor -> Westport', () => {
  assert.equal(Tides.nearest(47.668, -122.386).id, '9447130');
  assert.equal(Tides.nearest(46.93, -124.05).id, '9441102');
});

test('url: documented CO-OPS query for the week', () => {
  const u = Tides.url(Tides.byId('9447130'), range);
  assert.ok(u.startsWith('https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?'));
  for (const kv of ['product=predictions', 'datum=MLLW', 'interval=hilo', 'units=english', 'time_zone=lst_ldt', 'format=json', 'station=9447130', 'begin_date=20261026', 'end_date=20261101']) assert.ok(u.includes(kv), kv);
});

test('parse: one entry per day of the range, extremes in NOAA order, heights as numbers, outside days dropped', () => {
  const days = Tides.parse(fixture, range);
  assert.deepEqual(days.map(d => d.date), range.days);
  assert.ok(days[0].extremes.length >= 2);
  assert.equal(typeof days[0].extremes[0].v, 'number');
  assert.match(days[0].extremes[0].t, /^\d{2}:\d{2}$/);
  assert.ok(['H', 'L'].includes(days[0].extremes[0].type));
  const total = days.reduce((n, d) => n + d.extremes.length, 0);
  const inRange = fixture.predictions.filter(p => p.t.slice(0, 10) >= range.start && p.t.slice(0, 10) <= range.end).length;
  assert.equal(total, inRange);
  const shifted = Tides.parse(fixture, Week.range('2026-11-02'));
  assert.equal(shifted.reduce((n, d) => n + d.extremes.length, 0), fixture.predictions.filter(p => p.t.slice(0, 10) >= '2026-11-02').length);
});

test('load: resolves parsed days; rejects on HTTP error, bad JSON and a NOAA error object', async () => {
  const ok = () => Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) });
  assert.equal((await Tides.load(Tides.byId('9447130'), range, ok)).length, 7);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: false, status: 503, json: () => Promise.resolve({}) })), /503/);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: true, json: () => Promise.reject(new Error('bad json')) })), /bad json/);
  await assert.rejects(Tides.load(Tides.byId('9447130'), range, () => Promise.resolve({ ok: true, json: () => Promise.resolve({ error: { message: 'No data was found' } }) })), /No data was found/);
});

test('fmtTime', () => {
  assert.equal(Tides.fmtTime('03:12'), '3:12 am'); assert.equal(Tides.fmtTime('13:40'), '1:40 pm');
  assert.equal(Tides.fmtTime('00:05'), '12:05 am'); assert.equal(Tides.fmtTime('12:00'), '12:00 pm');
});
```

- [ ] **Step 3: Run to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/tides.test.js`
Expected: FAIL, `Cannot find module '../tides.js'`.

- [ ] **Step 4: Write `tides.js`** (replace the names and coordinates with the ones Task 1 printed; the ids below are the planned set)

```js
// Artifacts/salmon-rivers/tides.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Tides = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* NOAA CO-OPS tide predictions for the Week page. Predictions, not observations; MLLW; station local time as NOAA returns it,
     never converted. The only network call on the site. Heights are never turned into a rating or a "good time" word. */
  var BASE = 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter';
  /* Names and coordinates verified against NOAA's station metadata on 2026-10-26 (see STATUS.md). */
  var STATIONS = [
    { id: '9447130', name: 'Seattle', lat: 47.6026, lon: -122.3393 },
    { id: '9446484', name: 'Tacoma', lat: 47.2667, lon: -122.4133 },
    { id: '9447659', name: 'Everett', lat: 47.9800, lon: -122.2200 },
    { id: '9444900', name: 'Port Townsend', lat: 48.1117, lon: -122.7583 },
    { id: '9449880', name: 'Friday Harbor', lat: 48.5450, lon: -123.0117 },
    { id: '9449424', name: 'Cherry Point', lat: 48.8633, lon: -122.7583 },
    { id: '9444090', name: 'Port Angeles', lat: 48.1250, lon: -123.4400 },
    { id: '9443090', name: 'Neah Bay', lat: 48.3700, lon: -124.6017 },
    { id: '9442396', name: 'La Push', lat: 47.9133, lon: -124.6367 },
    { id: '9441102', name: 'Westport', lat: 46.9043, lon: -124.1051 },
    { id: '9440910', name: 'Toke Point', lat: 46.7075, lon: -123.9667 }
  ];
  var DEFAULT = '9447130';

  function byId(id) { for (var i = 0; i < STATIONS.length; i++) if (STATIONS[i].id === id) return STATIONS[i]; return null; }
  function nearest(lat, lon) {
    var best = null, bd = Infinity, R = 3959, toR = Math.PI / 180;
    STATIONS.forEach(function (s) {
      var dLat = (s.lat - lat) * toR, dLon = (s.lon - lon) * toR;
      var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat * toR) * Math.cos(s.lat * toR) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
      var d = 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      if (d < bd) { bd = d; best = s; }
    });
    return best;
  }
  function ymd(iso) { return iso.replace(/-/g, ''); }
  function url(station, range) {
    return BASE + '?product=predictions&datum=MLLW&interval=hilo&units=english&time_zone=lst_ldt&format=json' +
      '&station=' + encodeURIComponent(station.id) + '&begin_date=' + ymd(range.start) + '&end_date=' + ymd(range.end);
  }
  function parse(json, range) {
    var by = {};
    range.days.forEach(function (d) { by[d] = []; });
    ((json && json.predictions) || []).forEach(function (p) {
      var date = String(p.t).slice(0, 10);
      if (!by[date]) return;
      by[date].push({ t: String(p.t).slice(11, 16), type: p.type === 'H' ? 'H' : 'L', v: parseFloat(p.v) });
    });
    return range.days.map(function (d) { return { date: d, extremes: by[d] }; });
  }
  function load(station, range, fetchFn) {
    return fetchFn(url(station, range)).then(function (r) {
      if (!r.ok) throw new Error('NOAA HTTP ' + r.status);
      return r.json();
    }).then(function (j) {
      if (j && j.error) throw new Error('NOAA: ' + (j.error.message || 'error'));
      return parse(j, range);
    });
  }
  function fmtTime(hhmm) {
    var h = parseInt(hhmm.slice(0, 2), 10), m = hhmm.slice(3, 5), ap = h < 12 ? 'am' : 'pm';
    h = h % 12; if (h === 0) h = 12;
    return h + ':' + m + ' ' + ap;
  }

  return { STATIONS: STATIONS, DEFAULT: DEFAULT, byId: byId, nearest: nearest, url: url, parse: parse, load: load, fmtTime: fmtTime };
});
```

- [ ] **Step 5: Run the tests**

Run: `node --test Artifacts/salmon-rivers/test/tides.test.js`
Expected: 6 passing. If `nearest` picks the wrong station, the coordinates in `STATIONS` are wrong — fix them from Task 1's output, not the test.

- [ ] **Step 6: Commit**

```bash
git add Artifacts/salmon-rivers/tides.js Artifacts/salmon-rivers/test/tides.test.js Artifacts/salmon-rivers/test/fixtures/noaa-seattle.json
git commit -m "pages: tides.js builds, fetches and parses NOAA predictions for the week"
```

---

### Task 7: Tide table on the Week page (`Tides.render`, `Tides.mount`)

**Files:**
- Modify: `Artifacts/salmon-rivers/tides.js` (add `render`, `mount`, `STORE_KEY`, `ME_KEY`)
- Test: `Artifacts/salmon-rivers/test/tides.test.js` (render tests)

**Interfaces:**
- Consumes: `Week.fmtDow` (Task 4), the `fakeDoc()` helper from `week.test.js` (copy it into `tides.test.js`; the fake needs `insertBefore`, `value`, `addEventListener`, `options` for this task — the version below has them).
- Produces: `Tides.render(days, now, doc) -> Element` (`<table class="tides">`), `Tides.mount(root, afterSection, range, today, doc)` (builds `<section id="tides">`, inserts it after `afterSection`, loads and re-renders on station change), `Tides.STORE_KEY = 'wafish.tideStation'`, `Tides.ME_KEY = 'wafish.me'`, `Tides.nextIndex(days, now)`.

- [ ] **Step 1: Write the failing render tests (append to `tides.test.js`)**

```js
function fakeDoc() {
  function El(tag) { this.tagName = tag; this.children = []; this.attrs = {}; this.text = ''; this.listeners = {}; this.value = ''; this.parentNode = null; }
  El.prototype.appendChild = function (c) { this.children.push(c); c.parentNode = this; return c; };
  El.prototype.insertBefore = function (c, ref) { var i = this.children.indexOf(ref); if (i < 0) i = this.children.length; this.children.splice(i, 0, c); c.parentNode = this; return c; };
  El.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };
  El.prototype.addEventListener = function (k, f) { (this.listeners[k] = this.listeners[k] || []).push(f); };
  El.prototype.fire = function (k) { (this.listeners[k] || []).forEach(f => f({ target: this })); };
  Object.defineProperty(El.prototype, 'textContent', { get() { return this.text + this.children.map(c => c.textContent).join(''); }, set(v) { this.text = String(v); this.children = []; } });
  Object.defineProperty(El.prototype, 'className', { get() { return this.attrs['class'] || ''; }, set(v) { this.attrs['class'] = v; } });
  Object.defineProperty(El.prototype, 'id', { get() { return this.attrs.id || ''; }, set(v) { this.attrs.id = v; } });
  Object.defineProperty(El.prototype, 'nextSibling', { get() { if (!this.parentNode) return null; const i = this.parentNode.children.indexOf(this); return this.parentNode.children[i + 1] || null; } });
  Object.defineProperty(El.prototype, 'options', { get() { return this.children; } });
  El.prototype.querySelectorAll = function (sel) {
    const out = [], m = /^([a-z]+)?(?:\.([\w-]+))?(?:#([\w-]+))?$/.exec(sel);
    (function walk(n) { n.children.forEach(c => { if ((!m[1] || c.tagName === m[1]) && (!m[2] || (c.className || '').split(' ').includes(m[2])) && (!m[3] || c.id === m[3])) out.push(c); walk(c); }); })(this);
    return out;
  };
  El.prototype.querySelector = function (sel) { return this.querySelectorAll(sel)[0] || null; };
  return { createElement: t => new El(t), createTextNode: t => ({ tagName: '#text', children: [], textContent: String(t), parentNode: null }) };
}
const days0 = Tides.parse(fixture, range);

test('nextIndex: the first extreme after now, only one, none when the week is over', () => {
  const first = days0[0].extremes[0], second = days0[0].extremes[1];
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 00:00'), { day: 0, i: 0 });
  assert.deepEqual(Tides.nextIndex(days0, '2026-10-26 ' + first.t), { day: 0, i: 1 });
  assert.equal(Tides.nextIndex(days0, '2026-11-02 00:00'), null);
  assert.ok(second);
});

test('render: seven rows, today marked, exactly one next extreme, am/pm times and feet', () => {
  const t = Tides.render(days0, '2026-10-27 00:00', fakeDoc());
  const rows = t.querySelectorAll('tr');
  assert.equal(rows.length, 7);
  assert.equal(rows.filter(r => r.className.includes('today')).length, 1);
  assert.equal(rows[1].className, 'today');
  assert.equal(t.querySelectorAll('.next').length, 1);
  assert.match(t.querySelectorAll('.ex')[0].textContent, /^[HL] \d{1,2}:\d{2} [ap]m · -?\d+\.\d ft$/);
});

test('render: a day without extremes shows a dash', () => {
  const t = Tides.render([{ date: '2026-10-26', extremes: [] }], '2026-10-26 00:00', fakeDoc());
  assert.equal(t.querySelectorAll('td')[0].textContent, '—');
});

test('mount: section inserted after the given one, default station, stored and nearest choice, failure row', async () => {
  const doc = fakeDoc();
  const root = doc.createElement('div'), a = doc.createElement('section'), b = doc.createElement('section');
  a.id = 'reported'; b.id = 'rules'; root.appendChild(a); root.appendChild(b);
  const store = {};
  const storage = { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); } };
  const calls = [];
  const fetchOk = u => { calls.push(u); return Promise.resolve({ ok: true, json: () => Promise.resolve(fixture) }); };
  await Tides.mount(root, a, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.equal(root.children[1].id, 'tides');
  assert.ok(calls[0].includes('station=9447130'));
  assert.equal(root.children[1].querySelector('select').value, '9447130');
  assert.equal(root.children[1].querySelectorAll('tr').length, 7);
  // a stored choice wins over the default
  store[Tides.STORE_KEY] = '9446484';
  const root2 = doc.createElement('div'), a2 = doc.createElement('section'); root2.appendChild(a2);
  await Tides.mount(root2, a2, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.ok(calls[1].includes('station=9446484'));
  // an unknown stored id falls back; a stored "me" point picks the nearest
  store[Tides.STORE_KEY] = 'bogus'; store[Tides.ME_KEY] = JSON.stringify({ lat: 46.93, lon: -124.05, label: 'x' });
  const root3 = doc.createElement('div'), a3 = doc.createElement('section'); root3.appendChild(a3);
  await Tides.mount(root3, a3, range, '2026-10-26', doc, { fetch: fetchOk, storage, now: '2026-10-26 00:00' });
  assert.ok(calls[2].includes('station=9441102'));
  // failure shows the unavailable row with a NOAA link
  const root4 = doc.createElement('div'), a4 = doc.createElement('section'); root4.appendChild(a4);
  await Tides.mount(root4, a4, range, '2026-10-26', doc, { fetch: () => Promise.reject(new Error('blocked')), storage, now: '2026-10-26 00:00' });
  assert.ok(root4.children[1].textContent.includes('Tide predictions unavailable right now'));
  assert.ok(root4.children[1].querySelectorAll('a').some(x => x.attrs.href.includes('tidesandcurrents.noaa.gov')));
  // changing the picker fetches again and stores the choice
  const sel = root.children[1].querySelector('select'); sel.value = '9444900'; sel.fire('change');
  await new Promise(r => setTimeout(r, 0));
  assert.ok(calls[calls.length - 1].includes('station=9444900'));
  assert.equal(store[Tides.STORE_KEY], '9444900');
});
```

- [ ] **Step 2: Run to see them fail**

Run: `node --test Artifacts/salmon-rivers/test/tides.test.js`
Expected: FAIL, `Tides.nextIndex is not a function`.

- [ ] **Step 3: Add to `tides.js`** (inside the factory, before `return`; export `render, mount, nextIndex, STORE_KEY, ME_KEY`)

```js
  var STORE_KEY = 'wafish.tideStation', ME_KEY = 'wafish.me';
  var DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function dayLabel(iso) { var d = new Date(iso + 'T00:00:00Z'); return DOW[d.getUTCDay()] + ' ' + MON[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  /* now is 'YYYY-MM-DD HH:MM' in the station's local time; NOAA's t strings compare the same way. */
  function nextIndex(days, now) {
    for (var d = 0; d < days.length; d++) for (var i = 0; i < days[d].extremes.length; i++)
      if (days[d].date + ' ' + days[d].extremes[i].t > now) return { day: d, i: i };
    return null;
  }
  function render(days, now, doc) {
    var table = doc.createElement('table'); table.className = 'tides';
    var cap = doc.createElement('caption'); cap.className = 'sr'; cap.textContent = 'High and low tide predictions, one row per day'; table.appendChild(cap);
    var tbody = doc.createElement('tbody'); table.appendChild(tbody);
    var nx = nextIndex(days, now), today = now.slice(0, 10);
    days.forEach(function (d, di) {
      var tr = doc.createElement('tr'); if (d.date === today) tr.className = 'today';
      var th = doc.createElement('th'); th.setAttribute('scope', 'row'); th.textContent = dayLabel(d.date); tr.appendChild(th);
      var td = doc.createElement('td');
      if (!d.extremes.length) td.textContent = '—';
      d.extremes.forEach(function (e, i) {
        var s = doc.createElement('span');
        s.className = 'ex ' + e.type + (nx && nx.day === di && nx.i === i ? ' next' : '');
        s.textContent = e.type + ' ' + fmtTime(e.t) + ' · ' + e.v.toFixed(1) + ' ft';
        td.appendChild(s);
      });
      tr.appendChild(td); tbody.appendChild(tr);
    });
    return table;
  }
  function readStorage(storage, key) { try { return storage ? storage.getItem(key) : null; } catch (e) { return null; } }
  function writeStorage(storage, key, v) { try { if (storage) storage.setItem(key, v); } catch (e) { /* not persisted */ } }
  function localNow() { var d = new Date(); function p(n) { return String(n).padStart(2, '0'); } return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes()); }
  function startingStation(storage) {
    var stored = byId(readStorage(storage, STORE_KEY) || '');
    if (stored) return stored;
    try {
      var me = JSON.parse(readStorage(storage, ME_KEY) || 'null');
      if (me && isFinite(me.lat) && isFinite(me.lon)) return nearest(+me.lat, +me.lon);
    } catch (e) { /* unreadable: default */ }
    return byId(DEFAULT);
  }
  /* mount builds <section id="tides"> after afterSection and fills it. opts: { fetch, storage, now } — the page passes nothing and gets window.fetch, localStorage and the clock. */
  function mount(root, afterSection, range, today, doc, opts) {
    opts = opts || {};
    var fetchFn = opts.fetch || function (u) { return fetch(u); };
    var storage = 'storage' in opts ? opts.storage : (typeof localStorage !== 'undefined' ? localStorage : null);
    var now = opts.now || localNow();
    var sec = doc.createElement('section'); sec.className = 'group'; sec.id = 'tides'; sec.setAttribute('aria-labelledby', 'cap-tides');
    var head = doc.createElement('div'); head.className = 'tides-head';
    var h = doc.createElement('h2'); h.className = 'cap'; h.id = 'cap-tides'; head.appendChild(h);
    var sel = doc.createElement('select'); sel.setAttribute('aria-label', 'Tide station');
    STATIONS.forEach(function (s) { var o = doc.createElement('option'); o.setAttribute('value', s.id); o.value = s.id; o.textContent = s.name; sel.appendChild(o); });
    head.appendChild(sel); sec.appendChild(head);
    var panel = doc.createElement('div'); panel.className = 'panel'; sec.appendChild(panel);
    var fine = doc.createElement('p'); fine.className = 'fine'; fine.textContent = 'NOAA predictions, MLLW, local time. Not observations.'; sec.appendChild(fine);
    root.insertBefore(sec, afterSection.nextSibling);
    var station = startingStation(storage);
    sel.value = station.id;
    function show(node) { panel.textContent = ''; panel.appendChild(node); }
    function pending() { var p = doc.createElement('p'); p.className = 'fine'; p.textContent = '—'; return p; }
    function failed(st) {
      var p = doc.createElement('p'); p.className = 'fine';
      p.textContent = 'Tide predictions unavailable right now. ';
      var a = doc.createElement('a'); a.setAttribute('href', 'https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=' + st.id); a.setAttribute('target', '_blank'); a.setAttribute('rel', 'noopener'); a.textContent = 'See NOAA for ' + st.name;
      p.appendChild(a); return p;
    }
    function go(st) {
      h.textContent = 'Tides · ' + st.name;
      show(pending());
      return load(st, range, fetchFn).then(function (days) { show(render(days, now, doc)); }, function () { show(failed(st)); });
    }
    sel.addEventListener('change', function () {
      var st = byId(sel.value); if (!st) return;
      writeStorage(storage, STORE_KEY, st.id);
      go(st);
    });
    return go(station);
  }
```

Also add to `week/index.html`'s stylesheet (next to `.fine`): `.sr { position: absolute; width: 1px; height: 1px; margin: -1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }`.

- [ ] **Step 4: Run the tests**

Run: `node --test "Artifacts/salmon-rivers/test/*.test.js"`
Expected: all pass (tides: 10).

- [ ] **Step 5: Look at it in the browser**

Serve the folder and open `http://localhost:8787/week/index.html`. Expected: a "Tides · Seattle" section between Reported this week and New rules, seven rows, today's row in accent, the next extreme bold, picker switches station and the choice survives a reload. In the devtools Network panel, block `api.tidesandcurrents.noaa.gov` and reload: the unavailable row with a NOAA link, no console error.

- [ ] **Step 6: Commit**

```bash
git add Artifacts/salmon-rivers/tides.js Artifacts/salmon-rivers/week/index.html Artifacts/salmon-rivers/test/tides.test.js
git commit -m "pages: 7-day NOAA tide table on the Week page with a station picker"
```

---

### Task 8: `check-week.mjs` — the page check over the five pages

**Files:**
- Create: `Artifacts/salmon-rivers/check-week.mjs`

**Interfaces:**
- Produces: `node check-week.mjs [--base <url|dir>] [--today YYYY-MM-DD] [--shots <dir>]`, exit 0 only when every check passes. Task 10 runs it against the published URL; Task 11 uses `--shots`.

- [ ] **Step 1: Write the script**

Mirror how `Artifacts/fishing-year/check.mjs` resolves `playwright-core` (`PLAYWRIGHT_CORE` env or the Playwright MCP's copy) — copy its first ten lines if they differ from the `import` below.

```js
// Artifacts/salmon-rivers/check-week.mjs — page check for the five-tab site. Local: serves this folder; published: pass --base <url>.
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(process.env.PLAYWRIGHT_CORE || 'playwright-core');

const args = Object.fromEntries(process.argv.slice(2).map((a, i, arr) => a.startsWith('--') ? [a.slice(2), arr[i + 1]] : []).filter(x => x.length));
const today = args.today || '2026-10-26';
let base = args.base, server = null;
if (!base) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css' };
  server = createServer(async (req, res) => {
    const p = path.join(here, decodeURIComponent(req.url.split('?')[0]));
    if (!existsSync(p)) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream' }); res.end(await readFile(p));
  }).listen(0);
  base = 'http://127.0.0.1:' + server.address().port;
}
const PAGES = [['Map', '/index.html'], ['Week', '/week/index.html'], ['Year', '/year/index.html'], ['Spots', '/spots/index.html'], ['Counts', '/counts/index.html']];
const fails = [];
const check = (ok, msg) => { if (!ok) fails.push(msg); console.log((ok ? 'ok   ' : 'FAIL ') + msg); };
const browser = await chromium.launch();
const sizes = [[320, 700], [390, 844], [1024, 768]];
for (const scheme of ['light', 'dark']) {
  for (const [w, h] of sizes) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: scheme });
    for (const [name, p] of PAGES) {
      const page = await ctx.newPage();
      const errors = [];
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', e => errors.push(String(e)));
      await page.goto(base + p + '?today=' + today, { waitUntil: 'networkidle' });
      check(errors.length === 0, `${name} ${w}px ${scheme}: no console errors (${errors.join(' | ').slice(0, 200)})`);
      const tabs = await page.$$eval('nav.apptabs a', as => as.map(a => ({ t: a.textContent, h: a.getBoundingClientRect().height, cur: a.getAttribute('aria-current') })));
      check(tabs.map(t => t.t).join('|') === 'Week|Map|Year|Spots|Counts', `${name} ${w}px: five tabs in order`);
      check(tabs.every(t => t.h >= 44), `${name} ${w}px: tabs are 44px targets`);
      check(tabs.filter(t => t.cur === 'page').map(t => t.t)[0] === name, `${name} ${w}px: own tab is current`);
      const sx = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
      check(sx, `${name} ${w}px: no horizontal scroll`);
      if (name === 'Week') {
        const ids = await page.$$eval('section.group', ss => ss.map(s => s.id));
        check(ids.join(',') === 'open,reported,tides,rules,upcoming,spots', `Week ${w}px: sections in order (${ids})`);
        const chip = await page.$('.chip.soon');
        check(!!chip, `Week ${w}px: ends-soon chip present with today=${today}`);
        const tideRows = await page.$$eval('table.tides tr', rs => rs.length).catch(() => 0);
        const unavailable = await page.$eval('#tides', s => s.textContent.includes('unavailable')).catch(() => false);
        check(tideRows === 7 || unavailable, `Week ${w}px: tide table filled (${tideRows} rows) or marked unavailable`);
      }
      if (args.shots) { await mkdir(args.shots, { recursive: true }); await page.screenshot({ path: path.join(args.shots, `${name.toLowerCase()}-${w}-${scheme}.png`), fullPage: true }); }
      await page.close();
    }
    if (w === 390 && scheme === 'light') {
      // deep links on the map
      const page = await ctx.newPage();
      await page.goto(base + '/index.html?mode=spawning&month=11&site=enchantment&today=' + today, { waitUntil: 'networkidle' });
      check(await page.$eval('#modes [data-mode="spawning"]', b => b.getAttribute('aria-checked') === 'true'), 'deep link: spawning mode');
      check(await page.$eval('#sheet', s => s.classList.contains('open')), 'deep link: site sheet open');
      check(await page.$eval('#stitle', t => t.textContent.includes('Enchantment')), 'deep link: Enchantment Park sheet');
      check(await page.$eval('#year button:nth-child(11)', b => b.getAttribute('aria-checked') === 'true').catch(() => false), 'deep link: November selected');
      await page.goto(base + '/index.html?mode=reports&river=cowlitz', { waitUntil: 'networkidle' });
      check(await page.$eval('#stitle', t => t.textContent.includes('Cowlitz')), 'deep link: Cowlitz report sheet');
      await page.click('#sdone');
      check(await page.evaluate(() => location.search) === '', 'deep link: Done clears the query');
      await page.goto(base + '/index.html?mode=spawning&site=nonsense', { waitUntil: 'networkidle' });
      check(await page.$eval('#sheet', s => !s.classList.contains('open')), 'deep link: unknown site ignored');
      // tides blocked -> unavailable row
      const p2 = await ctx.newPage();
      await p2.route('**/api.tidesandcurrents.noaa.gov/**', r => r.abort());
      await p2.goto(base + '/week/index.html?today=' + today, { waitUntil: 'networkidle' });
      check(await p2.$eval('#tides', s => s.textContent.includes('Tide predictions unavailable right now')), 'tides: blocked request shows the unavailable row');
      await page.close(); await p2.close();
    }
    await ctx.close();
  }
}
await browser.close(); if (server) server.close();
console.log(fails.length ? `\n${fails.length} FAILED` : '\nall checks passed');
process.exit(fails.length ? 1 : 0);
```

The selectors `#modes`, `#sheet`, `#stitle`, `#sdone`, `#year` come from the live `index.html`; if the sheet title id differs, read it from the page and fix the script, not the page.

- [ ] **Step 2: Watch it fail first**

Temporarily change the tab test string in the script to `'Week|Map|Year|Spots|Count'` and run `node Artifacts/salmon-rivers/check-week.mjs`. Expected: 30 FAIL lines for the tab order and a non-zero exit. Revert the string.

- [ ] **Step 3: Run it for real**

Run: `cd Artifacts/salmon-rivers && node check-week.mjs`
Expected: `all checks passed`, exit 0. (`Year` and `Counts` are bundles that were not changed beyond the tab bar; a console error there means the tab replacement broke markup — diff the `<nav>` against `tabsHtml`.)

- [ ] **Step 4: Commit**

```bash
git add Artifacts/salmon-rivers/check-week.mjs
git commit -m "pages: check-week.mjs page check for the five-tab site and deep links"
```

---

### Task 9: Docs and the PR

**Files:**
- Modify: `Artifacts/salmon-rivers/README.md`, `Artifacts/salmon-rivers/artifact.json`, `STATUS.md`, `TASKS.md`, `CLAUDE.md` (web pages table row + test command)

- [ ] **Step 1: README** — add a section after the existing modes:

```markdown
## Week (`week/index.html`)

"This week": open seasons (ending soonest first, "ends soon" within 7 days), catch reports from the last 7 days with the map's own badges, WDFW rules published in the last 14 days, the next three dated items, a 7-day NOAA tide table for one station, and the spot guides. Logic is `week.js` (`Week.build`, `Week.render`), tides are `tides.js` (the site's only network call: NOAA CO-OPS predictions, MLLW, station local time, never converted). Every card deep-links into the map with `links.js` parameters: `mode`, `month` (spawning), `species`, `site`, `river`; `today` is read for testing and never written. Nothing here is a new rating: seasons, rules and tides are text and dates. Tests: `test/week.test.js`, `test/tides.test.js`, `test/links.test.js`, `test/tabs.test.js`; page check: `node check-week.mjs [--base <url>]`.
```

- [ ] **Step 2: `artifact.json`** — add to the files list `week/index.html, week.js, links.js, tides.js` and the note: `Refresh by PASSING THIS URL with files={week/index.html, week.js, links.js, tides.js, index.html, spots/index.html, year/index.html, counts/index.html} plus any data file that changed.`

- [ ] **Step 3: `STATUS.md`** — under Confirmed working add one line for the Week page and deep links; under the decision log add a dated entry: spike result (from Task 1), that Typical season has no month control so `month` is spawning-only, that Year has no season anchors so Week links to its top, and the test count after `node --test`.

- [ ] **Step 4: `TASKS.md`** — add:

```markdown
- [ ] Year page: give each season row an `id` (its `seasons.json` id) in the Fishing Year source and rebuild, then switch the Week page's Year links to `../year/index.html#<id>` (`Week.render`, the Open now and Coming up rows).
- [ ] Spot guides as data (`spots.js` + template) — sub-project 4; `Week.SPOTS` is the stopgap list.
- [ ] Live conditions sub-project: USGS flow and NOAA tides inside the map's site sheets (tides.js is reusable).
- [ ] [you] Repoint `Artifacts/fishing-year/artifact.json` and `Artifacts/three-friends-fishing-hole/artifact.json` to the main URL (`year/`, `spots/`): their standalone artifacts were deleted 2026-10-26.
```

- [ ] **Step 5: `CLAUDE.md`** — in the web pages table, change the `salmon-rivers/` row's page column to `Washington Fishing Map — Map (Recent reports, Typical season, Spawning), Week, Year, Spots, Counts` and add `node Artifacts/salmon-rivers/check-week.mjs` to the Web pages test row.

- [ ] **Step 6: Run everything, push, open the PR**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" && (cd Artifacts/salmon-rivers && node check-week.mjs)
git add -A Artifacts/salmon-rivers README.md STATUS.md TASKS.md CLAUDE.md
git commit -m "docs: Week page, deep links, tides; follow-ups filed"
git push -u origin week-page-and-deep-links
gh pr create --base main --title "Week page, deep links and tides on the Washington Fishing Map" --body-file - <<'EOF'
Adds a fifth tab, Week, that joins open seasons, this week's catch reports, new WDFW rules, upcoming dates, a 7-day NOAA tide table and the spot guides; makes the map honour and keep `?mode=&month=&species=&site=&river=` deep links; puts the same five-tab bar on every page.

Spec: docs/superpowers/specs/2026-10-26-week-page-and-deep-links-design.md
Plan: docs/superpowers/plans/2026-10-26-week-page-and-deep-links.md

Tests: `node --test "Artifacts/salmon-rivers/test/*.test.js"` (N passing) and `node check-week.mjs` (all checks passed) — paste the real numbers here.
Not published yet: publishing happens after merge (plan Task 10) by passing the main URL.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01WgShKNu9pyhLjqPmNzUDft
EOF
```

Replace `N passing` with the printed count before submitting. Daniel merges.

---

### Task 10: Publish after merge

**Files:**
- Modify: `Artifacts/salmon-rivers/artifact.json` (version), project doc `pages/fish-pages.md`

- [ ] **Step 1: Read the live page first**

Artifact tool `action: "read"` with the main URL and no `path`. Expected version: `1792491424-046f`. If it is newer, diff the live files against the merged `main` (Task 0 Step 2–3) and merge before publishing.

- [ ] **Step 2: Publish**

Artifact tool `action: "publish"`, `url: https://claude.ai/artifact/9oA145toRsmFcDYurdJbey`, `file_path: Artifacts/salmon-rivers/index.html`, `files: { "week/index.html": "Artifacts/salmon-rivers/week/index.html", "week.js": "Artifacts/salmon-rivers/week.js", "links.js": "Artifacts/salmon-rivers/links.js", "tides.js": "Artifacts/salmon-rivers/tides.js", "spots/index.html": "…/spots/index.html", "year/index.html": "…/year/index.html", "counts/index.html": "…/counts/index.html" }`, `label: "Week page, deep links, tides"`.

- [ ] **Step 3: Check the published site and record the version**

```bash
cd Artifacts/salmon-rivers && node check-week.mjs --base https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
```

Expected: `all checks passed`, and the tide table filled (not the unavailable row — if it is unavailable on the published URL but filled locally, the spike's answer was wrong; fall back to the bundled-data path in Task 1 Step 4). Then write the new version id into `artifact.json` and into the project's `pages/fish-pages.md` ("Live version checked"), commit on a `docs/publish-version` branch and open a one-line PR.

---

### Task 11: Design critique and its top three fixes

**Files:**
- Create: `docs/design/2026-10-26-week-critique.md`, `docs/design/week-captures/` (not committed; .gitignore it)
- Modify: whatever the three findings touch, each as its own commit on branch `week-critique-fixes`

- [ ] **Step 1: Capture the five pages**

```bash
cd Artifacts/salmon-rivers && node check-week.mjs --base https://claude.ai/artifact/9oA145toRsmFcDYurdJbey --shots ../../docs/design/week-captures
```

Expected: 30 PNGs (5 pages × 3 widths × 2 schemes).

- [ ] **Step 2: Run the critique**

Invoke `/design:design-critique` with the 390 px and 1024 px captures of all five pages in both schemes and this brief: *"Five-page fishing guidance site. Judge usability, hierarchy, consistency across the tabs, and readability; the rating ramp and the guidance-not-regulation footer are fixed constraints. Rank findings by user impact."* Write its output to `docs/design/2026-10-26-week-critique.md` with the top three findings marked.

- [ ] **Step 3: Fix finding 1, then 2, then 3 — same loop each time**

For each finding, on branch `week-critique-fixes`:
1. Add one assertion to `check-week.mjs` that captures the finding (a measured size, a contrast ratio via `getComputedStyle`, an element's presence or order) and run it: it must FAIL on the current page.
2. Make the smallest change to the page or module that fixes it; if it changes `Week.render` or `Tides.render` output, add or adjust a unit test too.
3. Run `node --test "Artifacts/salmon-rivers/test/*.test.js"` and `node check-week.mjs`: all pass.
4. Commit: `git commit -m "design: <finding in six words> (critique 2026-10-26 #<n>)"`.

The remaining findings go into `TASKS.md` under a "Design critique 2026-10-26" heading, one line each.

- [ ] **Step 4: PR, merge, republish**

Push, open the PR (`gh pr create --base main --title "Week page: design critique fixes" …` with the attribution footer), Daniel merges, then repeat Task 10 Steps 1–3 for the changed files.

---

## Self-review

**Spec coverage:** Week page sections (Task 4/5), empty-section rows (5), `?today=` (5, 8), Tides section/picker/nearest/storage/failure/spike (1, 6, 7), deep-link keys, apply order, replaceState, `today` carried (2, 3), river id resolution (3), Year links to page top with follow-up (5 render links, 9 TASKS), tab bar identical on five pages with a check (5), 14 px fallback at 389 px (5), guidance rules (render uses text/dates; badges reuse `Reports.LABEL`; advisory wash for soon — 5), Node tests listed in spec §5 (2, 4, 5, 6, 7), page check including blocked tides route and deep links (8), critique top-three loop (11), delivery via branch/PR/read-live/publish (0, 9, 10), blocker on repo access (0). Gap: the spec's `Week.build` result does not include a `tides` key — tides are mounted separately by `Tides.mount` (Task 7); the spec's result shape is otherwise matched.

**Placeholders:** none; the critique task's unknown findings are handled by a fixed procedure rather than invented content.

**Type consistency:** `Week.range(today) -> { start, end, days }` is used by `Tides.url/parse/mount` with that shape; `Tides.mount(root, afterSection, range, today, doc, opts)` matches the page's call in Task 5 Step 8 (five args; `opts` optional); `Links.write(state, history, location)` matches Task 3's `syncLink`; `tabsHtml(depth, current)` is used by Task 5 Step 7 and `tabs.test.js`; section ids `open, reported, tides, rules, upcoming, spots` agree between `Week.render`, `Tides.mount` and `check-week.mjs`.
