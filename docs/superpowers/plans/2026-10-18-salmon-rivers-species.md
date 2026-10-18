# Salmon Rivers Page: Species From the App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the published SW Washington river page report on any species the WA Fish Map app knows, keyed by the app's exact species name, while every rating stays a dated third-party catch report.

**Architecture:** Re-key each river's reports from the two hard-coded fields `coho` and `chinook` to a `reports` object keyed by the exact species string used in `WAFishMap/Resources/fisheries.json`. Generate the species picker from the data, recolour pins gray ("No report") for a river with nothing for the chosen species, and add a Node test that fails if a page species name is not an exact app species name. New species enter only as sourced, dated reports (Task 5); the page never reads `fisheries.json` at runtime and never colours by seasonal timing.

**Tech Stack:** Same as the page: plain HTML/CSS/ES5 JavaScript, no build step, Node `node:test` for logic, the Claude Browser pane for DOM checks, the `Artifact` tool for publishing.

**Spec:** None for the page (see `2026-10-18-salmon-rivers-artifact.md`, whose Tasks 1 to 7 this plan builds on). Product rules: `CLAUDE.md` sections "Not this app" and "Notes are scoped". Picker semantics mirror `docs/superpowers/specs/2026-08-31-species-first-design.md`: recolour, do not hide; exact name match; nil species is "All".

## Decision: what "species we have on wa-fish-map" means for this page

Daniel's ask was "do for species we have on wa-fish-map". Three readings, and the call:

| Option | What it does | Verdict |
| --- | --- | --- |
| (a) Recolour by species and month from `fisheries.json`, like the app | Pins coloured by seasonal timing | **Rejected.** The data does not exist for these waters (below), and it would put "typically peaks in October" next to "caught this week" on one legend. |
| (b) Keep dated catch reports; add species chips; gray where no report is sourced | Same honesty as today, more species | **Chosen.** |
| (c) Both, as separate modes | A timing mode and a reports mode | **Deferred**, not planned. It becomes honest only after the app has rows for these rivers (follow-up below). |

Facts behind that, checked against the repo on 2026-10-18:

1. **`fisheries.json` has no row for any of the six waters.** Its `areas[]` are 16 WDFW marine areas (22 distinct species names, mostly saltwater: crab, squid, halibut, lingcod, razor clams, rockfish). The only Columbia-named row is `Buoy 10 Salmon (Columbia mouth)` in area 1, a different stretch from this page's "Tongue Point to Bonneville Dam". `freshwater.byCounty` covers Chelan, Grant, King, Mason, Okanogan, Pierce, Spokane and Thurston, none of them Cowlitz, Clark, Skamania, Klickitat, Wahkiakum or Lewis counties. `freshwater.byWaterbody` holds four eastern lakes (Walleye only). `rivers.json` knows these rivers as flow lines for USGS gauges, with no species.
2. **The only data that could colour these rivers is the statewide freshwater list** (Rainbow Trout, Largemouth Bass, Cutthroat Trout). Painting every river by a statewide row says nothing about the Cowlitz and breaks the "Notes are scoped" rule: a claim must be true everywhere its key resolves.
3. **Mapping a river to a marine area to borrow its months would be an invented fact.** The app itself refuses it: launches match an area only by polygon or a 150 m shore snap, and inland water stays neutral gray by design.
4. **Different meaning.** The page's colour means "a report this week said so". The app's colour means "this month is typically good". The page's legend, footer and disclaimer promise the first. "Not this app": no season dates presented as authoritative; the rating is not a claim a fishery is open.

What (b) buys, said plainly: **the code in Tasks 1 to 4 does not add a visible species by itself.** It removes the two-species hard-coding, makes the species names match the app exactly, and makes "no report for this species here" an honest, visible state. A new species appears only when Task 5 finds a dated, sourced report for it. Task 6 will not publish if no species was added.

**Exact-name calls made here (Daniel can overrule):**
- The page's current "Coho" becomes `Coho Salmon` and "Chinook" becomes `Chinook Salmon`, the unqualified app names. The app also has `Fall Chinook`, `Chinook Salmon (ocean)`, `Chinook Salmon (summer hatchery)`, `Chinook Salmon (Tulalip)`, `Resident Chinook (Blackmouth)` and `Buoy 10 Salmon (Columbia mouth)`. Per the species-first spec these are different species strings. The page's existing Chinook reports do not say "fall", so they are not relabelled.
- Picker buttons show the exact name (`Coho Salmon`, not `Coho`) so the label can never drift from the matching key. "All salmon" becomes "All species" (the app's wording; the maximum across whatever has a report).

## Global Constraints

Every task's requirements include these. They extend the constraints of `2026-10-18-salmon-rivers-artifact.md`, which still apply in full.

- Guidance, not regulation: every river sheet keeps the "Before you go" advisory, the WDFW rules link (`https://wdfw.wa.gov/fishing/regulations`) and the footer line "Recent catch reports, not season dates. Not for navigation or safety decisions."
- Never invent a fact or a date. A rating comes from the source's own words. A report whose source gives no date has `asOf: null` and shows "Date not given".
- Species keys are exact, case-sensitive strings from `WAFishMap/Resources/fisheries.json` (areas, `freshwater.species`, `freshwater.byCounty`, `freshwater.byWaterbody`). Matching is exact; `Chinook Salmon` is not `Chinook Salmon (ocean)`.
- The page (`index.html`, `reports.js`) never reads `fisheries.json` and never contains `bestMonths` or `goodMonths`. Only a test reads that file, to check names.
- Recolour, do not hide: a river with no report for the chosen species stays on the map in `--unrated` gray and says "No report".
- Pure logic never reads the clock; `reports.js` functions take `today` as `YYYY-MM-DD`. `STALE_DAYS = 7`.
- No emoji and no em dashes in UI copy, code or comments.
- Rating colours and tokens stay as defined on `:root`; no new hues, no new tokens.
- A passing check must be able to fail: each new guard test is seen going red once (Tasks 1 and 2 say how).
- Commits: new commits only, never amend, never `--no-verify`, imperative subject, a body that says why, `git add` with explicit paths, end with `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Publishing replaces a live page Daniel owns: get a clear yes in chat first (Task 6).

## Preconditions

This plan edits the files that `2026-10-18-salmon-rivers-artifact.md` creates. Execute it only after that plan's Task 7 is done (published, `artifact.json` has `currentVersion`). Task 1 Step 1 checks this.

## File Structure

| File | Change |
| --- | --- |
| `Artifacts/salmon-rivers/reports.js` | Add `SPECIES`; re-key `SITES[i]` from `coho`/`chinook` to `reports`; `viewOf`/`rankSites` take an exact species name or `null`; remove `SP_NAME`; add `pinLabel`, `reportRows`, `missingNote`. |
| `Artifacts/salmon-rivers/index.html` | Picker generated from `Reports.SPECIES`; `filter` becomes `species`; sheet rows and aria-labels use the exact name; no-report note; per-report source links. |
| `Artifacts/salmon-rivers/test/species-vocab.test.js` | New. Reads `fisheries.json`; fails on any non-exact page species name; fails if the page carries timing fields. |
| `Artifacts/salmon-rivers/test/reports.test.js` | Updated for the new shape; new tests for unknown species, missing report, sources. |
| `Artifacts/salmon-rivers/artifact.json` | `what` and `currentVersion` updated at publish. |

## What data would need sourcing (read before Task 5)

Nothing in the repo supplies a catch report for any species other than coho and chinook on these six waters. To add a species the page needs, per river and species: **a dated statement from a named source that the species was being caught on that river, in words that support a rating.**

Candidate names from the app's own vocabulary that could plausibly apply to river or lake water. These are candidates only; whether a source reports them for these six waters is unknown and must not be assumed:

- Salmon: `Chum Salmon`, `Pink Salmon`, `Fall Chinook`
- Trout: `Sea-run Cutthroat`, `Cutthroat Trout`, `Rainbow Trout`
- Warmwater: `Walleye`, `Largemouth Bass` (Drano Lake and the lower Columbia are the only waters here where a source might mention these; unknown)

Out of reach on purpose: the app has no row for steelhead, sturgeon, shad or sockeye, so "species we have" excludes them. If Daniel wants them on the page, the app's `fisheries.json` has to carry them first (a separate app task).

Sources the page already uses, so the likely places to look first: The Guide's Forecast (`https://www.theguidesforecast.com/sw-washington-fishing-reports/`), NW Sportsman (`nwsportsmanmag.com` weekly SW WA / Lower Columbia report), and WDFW's own pages where they give a dated statement. Quality bar: the source names the river, names the species, carries a date, and says how fishing was in words (excellent, good, fair). Counts alone are not a rating.

## Out of scope

- A seasonal-timing mode (option (c)). Follow-up if wanted: add `freshwater.byWaterbody` rows to the app for these rivers, keyed by exact river name from `rivers.json`, true end to end per "Notes are scoped" (the Spokane precedent shows that is not always possible), verified against WDFW. Only then plan a "Typical timing" mode here.
- New rivers or regions, runtime fetching, deep links (same reasons as the earlier plan).
- A "slow" or "poor" rating. The page only has Excellent, Good and Fair, so a source reporting poor fishing is simply not added. That biases the page toward good news; it is an existing limitation, noted in Task 5, not changed here.

---

### Task 1: Guard that page species names are exact app names

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js` (add `SPECIES`, export it)
- Create: `Artifacts/salmon-rivers/test/species-vocab.test.js`

**Interfaces:**
- Produces: `Reports.SPECIES: string[]`, the display order of every species the page has reports for, each an exact `fisheries.json` species name. Initially `['Coho Salmon', 'Chinook Salmon']`.

- [ ] **Step 1: Check the preconditions**

```bash
git log --oneline -1 -- Artifacts/salmon-rivers/reports.js
ls Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/artifact.json
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
grep -c currentVersion Artifacts/salmon-rivers/artifact.json
```

Expected: a commit line, all three paths listed, `# fail 0`, and `1`. If any is missing, the earlier plan is not finished: stop and tell Daniel.

- [ ] **Step 2: Write the failing test**

`Artifacts/salmon-rivers/test/species-vocab.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const R = require('../reports.js');

const repo = path.join(__dirname, '..', '..', '..');
const fisheries = JSON.parse(fs.readFileSync(path.join(repo, 'WAFishMap/Resources/fisheries.json'), 'utf8'));

// Every species string the app can show: marine areas, statewide freshwater,
// county overrides and per-waterbody rows.
function appSpeciesNames(f) {
  const names = new Set();
  f.areas.forEach(a => a.species.forEach(s => names.add(s.species)));
  f.freshwater.species.forEach(s => names.add(s.species));
  Object.values(f.freshwater.byCounty).forEach(rows => rows.forEach(s => names.add(s.species)));
  Object.values(f.freshwater.byWaterbody).forEach(rows => rows.forEach(s => names.add(s.species)));
  return names;
}
const APP = appSpeciesNames(fisheries);

test('control: the extractor really read the app vocabulary', () => {
  // If a key were misspelled the set would be empty and every membership test below would be meaningless.
  assert.ok(APP.size >= 25, `only ${APP.size} names`);
  for (const n of ['Coho Salmon', 'Chinook Salmon', 'Chinook Salmon (ocean)', 'Walleye', 'Rainbow Trout', 'Yellow Perch']) {
    assert.ok(APP.has(n), `missing ${n}`);
  }
});

test('matching is exact: near-misses are not app species', () => {
  for (const n of ['Coho', 'coho salmon', 'Chinook', 'Chinook Salmon ', 'Salmon']) {
    assert.ok(!APP.has(n), `"${n}" should not match`);
  }
});

test('every species the page can show is an exact app species name', () => {
  assert.ok(Array.isArray(R.SPECIES) && R.SPECIES.length >= 2);
  for (const n of R.SPECIES) assert.ok(APP.has(n), `"${n}" is not an exact species name in fisheries.json`);
  assert.equal(new Set(R.SPECIES).size, R.SPECIES.length, 'duplicate species');
});

test('the page never carries the app seasonal-timing data', () => {
  const dir = path.join(__dirname, '..');
  for (const f of ['reports.js', 'index.html']) {
    const text = fs.readFileSync(path.join(dir, f), 'utf8');
    assert.doesNotMatch(text, /bestMonths|goodMonths|fisheries\.json/, `${f} references seasonal timing`);
  }
});
```

- [ ] **Step 3: Run it to see it fail**

```bash
node --test "Artifacts/salmon-rivers/test/species-vocab.test.js"
```

Expected: FAIL in "every species the page can show..." with `R.SPECIES` undefined (the assertion on `Array.isArray`). The control, near-miss and timing tests pass.

- [ ] **Step 4: Add `SPECIES`**

In `reports.js`, after the `STALE_DAYS` line add:

```js
  /* Display order of every species with at least one report. Each is an exact species name from the app's fisheries.json. */
  var SPECIES = ['Coho Salmon', 'Chinook Salmon'];
```

and add `SPECIES: SPECIES,` to the returned object next to `STALE_DAYS`.

- [ ] **Step 5: Run it to see it pass, then watch it fail for the right reason**

```bash
node --test "Artifacts/salmon-rivers/test/species-vocab.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`. Now prove the guard can fail: change `'Coho Salmon'` in `SPECIES` to `'Coho'`, rerun.

Expected: FAIL with `"Coho" is not an exact species name in fisheries.json`. Change it back and rerun to see `# fail 0` again.

- [ ] **Step 6: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/species-vocab.test.js
git commit -m "Test that salmon page species names match the app exactly

The species-first spec makes matching exact, and the page names its
species 'Coho' and 'Chinook'. Add the list the page will key reports by
and a test that reads fisheries.json, so a near-miss name fails the
build instead of silently matching nothing.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Key reports by exact species name (no visible change)

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js`, `Artifacts/salmon-rivers/test/reports.test.js`, `Artifacts/salmon-rivers/index.html`

**Interfaces:**
- Consumes: `Reports.SPECIES` (Task 1).
- Produces:
  - `SITES[i].reports: { [speciesName]: { r: 'prime'|'good'|'fair', asOf: 'YYYY-MM-DD'|null, d: string, release?: true, src?: { label: string, url: string } } }`
  - `viewOf(site, species, today)`: `species` is an exact name or `null` (all). Returns `{ r, release, k, fresh, asOf }` where `k` is the species name or `null`. Throws `Error('unknown species: <s>')` if `species` is non-null and not in `SPECIES`.
  - `rankSites(sites, species, today)`, same `species` argument.
  - `SP_NAME` is removed.

- [ ] **Step 1: Rewrite the tests for the new shape (they fail first)**

In `test/reports.test.js`, replace the top helpers and the tests listed below. Keep the baseline `expect` table exactly as it is: it is the proof that nothing visible changed.

```js
const F = { all: null, coho: 'Coho Salmon', chinook: 'Chinook Salmon' };
const back = k => (k === null ? null : Object.keys(F).find(n => F[n] === k));
const site = id => R.SITES.find(s => s.id === id);
const pick = (id, filter, today = TODAY) => {
  const v = R.viewOf(site(id), F[filter], today);
  return { r: v.r, k: back(v.k), release: v.release };
};
const two = (coho, chinook) => ({ id: 'x', name: 'X', reports: { 'Coho Salmon': coho, 'Chinook Salmon': chinook } });
```

(`pick` replaces the old helper; the first test, "viewOf keeps the colours the published page showed", stays unchanged and now runs through it.) Replace these tests:

```js
test('a fresh lower rating beats a stale higher one', () => {
  const s = two({ r: 'prime', asOf: '2026-10-01', d: '' }, { r: 'fair', asOf: '2026-10-17', d: '' });
  const v = R.viewOf(s, null, TODAY);
  assert.equal(v.k, 'Chinook Salmon');
  assert.equal(v.fresh, true);
});

test('when everything is stale the best rating still shows', () => {
  const v = R.viewOf(site('cowlitz'), null, '2026-11-30');
  assert.equal(v.r, 'prime');
  assert.equal(v.k, 'Coho Salmon');
  assert.equal(v.fresh, false);
});

test('release-only still loses to a retainable species even if the release one is fresher', () => {
  const s = two({ r: 'fair', asOf: '2026-10-01', d: '' }, { r: 'prime', release: true, asOf: '2026-10-17', d: '' });
  assert.equal(R.viewOf(s, null, TODAY).k, 'Coho Salmon');
});

test('a site with no reports yields the unrated view', () => {
  const v = R.viewOf({ id: 'x', name: 'X' }, null, TODAY);
  assert.deepEqual({ r: v.r, k: v.k, release: v.release, fresh: v.fresh }, { r: 'unrated', k: null, release: false, fresh: false });
});

test('a chosen species the river has no report for is unrated, not hidden and not borrowed from another species', () => {
  const lone = { id: 'x', name: 'X', reports: { 'Coho Salmon': { r: 'prime', asOf: '2026-10-17', d: '' } } };
  const v = R.viewOf(lone, 'Chinook Salmon', TODAY);
  assert.deepEqual({ r: v.r, k: v.k }, { r: 'unrated', k: null });
  assert.equal(R.viewOf(lone, 'Coho Salmon', TODAY).r, 'prime');
});

test('an unknown or near-miss species name throws instead of quietly matching nothing', () => {
  assert.throws(() => R.viewOf(site('wind'), 'Coho', TODAY), /unknown species: Coho/);
  assert.throws(() => R.viewOf(site('wind'), 'coho salmon', TODAY), /unknown species/);
  assert.throws(() => R.rankSites(R.SITES, 'Chinook', TODAY), /unknown species/);
});

test('latestReport is the newest dated report and ignores undated ones', () => {
  assert.equal(R.latestReport(R.SITES), '2026-10-17');
  assert.equal(R.latestReport([{ id: 'x', name: 'X', reports: { 'Coho Salmon': { r: 'fair', asOf: null, d: '' } } }]), null);
});

test('rankSites: retainable first, fresh before stale, then rating, then name', () => {
  const ids = f => R.rankSites(R.SITES, F[f], TODAY).map(e => e.site.id);
  assert.deepEqual(ids('all'), ['cowlitz', 'columbia', 'drano', 'klickitat', 'lewis', 'wind']);
  assert.deepEqual(ids('chinook'), ['drano', 'klickitat', 'lewis', 'wind', 'cowlitz', 'columbia']);
});

test('report data: ids unique, species exact, ratings valid, dates real, no dates in prose', () => {
  const ids = new Set();
  const used = new Set();
  for (const s of R.SITES) {
    assert.ok(!ids.has(s.id), `duplicate ${s.id}`); ids.add(s.id);
    assert.ok(s.reports && Object.keys(s.reports).length > 0, `${s.id} has no reports`);
    for (const [name, sp] of Object.entries(s.reports)) {
      assert.ok(R.SPECIES.includes(name), `${s.id}: "${name}" is not in Reports.SPECIES`);
      used.add(name);
      assert.ok(['prime', 'good', 'fair'].includes(sp.r), `${s.id}/${name} rating`);
      if (sp.asOf !== null) R.ageDays(sp.asOf, TODAY);
      assert.doesNotMatch(sp.d, /\b(Oct|Nov|Dec)\s+\d{1,2}\b/, `${s.id}/${name} prose still names a date`);
    }
  }
  assert.equal(ids.size, 6);
  for (const n of R.SPECIES) assert.ok(used.has(n), `${n} is in SPECIES but no river has a report for it`);
});
```

The freshness, date-format, `staleNotice` and `ratingWord` tests have no species argument and stay as they are. If earlier-plan Tasks 3 to 6 added other tests that build sites with `coho:`/`chinook:` keys, convert them with the same `two(...)` helper.

- [ ] **Step 2: Run to see it fail**

```bash
node --test "Artifacts/salmon-rivers/test/reports.test.js"
```

Expected: FAIL in most tests (`site.reports` is undefined, `viewOf` ignores the species name).

- [ ] **Step 3: Convert the data in `reports.js` mechanically**

The site entries are one object per species per line. Re-key them with a one-time script rather than retyping data (do not commit the script). From the repo root:

```bash
node -e '
const fs = require("fs");
const p = "Artifacts/salmon-rivers/reports.js";
let t = fs.readFileSync(p, "utf8");
const before = (t.match(/coho: \{/g) || []).length + (t.match(/chinook: \{/g) || []).length;
t = t.replace(/coho: \{/g, "reports: { \x27Coho Salmon\x27: {")
     .replace(/chinook: \{([^}]*)\}/g, "\x27Chinook Salmon\x27: {$1} }");
fs.writeFileSync(p, t);
console.log("converted", before, "species objects");
'
```

Expected output: `converted 12 species objects`. Then view the result with `sed -n '/var SITES/,/^  \];/p' Artifacts/salmon-rivers/reports.js`: each site must now read `reports: { 'Coho Salmon': {...}, 'Chinook Salmon': {...} }` with the site's other fields (`extra: 'nws'` on Lewis) still outside `reports`. Fix by hand if a brace is off. The data text (ratings, dates, prose) must not change: `git diff --stat` shows only `reports.js`, and the diff touches only the key syntax.

- [ ] **Step 4: Change the functions in `reports.js`**

Delete the line `var SP_NAME = { coho: 'Coho', chinook: 'Chinook' };` and `SP_NAME: SP_NAME,` from the export. Add before `viewOf`:

```js
  function reportsOf(site) { return site.reports || {}; }
```

Replace `viewOf`:

```js
  function viewOf(site, species, today) {
    if (species !== null && SPECIES.indexOf(species) < 0) throw new Error('unknown species: ' + species);
    var have = reportsOf(site);
    var best = null;
    (species === null ? SPECIES : [species]).forEach(function (k) {
      var sp = have[k];
      if (!sp) return;
      var c = { r: sp.r, release: !!sp.release, k: k, asOf: sp.asOf === undefined ? null : sp.asOf, fresh: freshness(sp.asOf, today) === 'fresh' };
      if (better(c, best)) best = c;
    });
    return best || { r: 'unrated', release: false, k: null, asOf: null, fresh: false };
  }
```

Replace the loop body in `latestReport`:

```js
    sites.forEach(function (s) {
      var have = reportsOf(s);
      Object.keys(have).forEach(function (k) {
        var a = have[k].asOf;
        if (a && (latest === null || a > latest)) latest = a;
      });
    });
```

Rename the second parameter of `rankSites` from `filter` to `species` and pass it through: `viewOf(s, species, today)`.

- [ ] **Step 5: Run to see it pass**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`. Then prove the two guards can fail: in `reports.js` rename one key to `'Coho'` and rerun; expected FAIL in "report data" with `"Coho" is not in Reports.SPECIES` and in the species-vocab test. Revert.

- [ ] **Step 6: Adapt `index.html` with no visible change**

Make exactly these substitutions (find each with the grep in Step 7):

1. `var filter = 'all';` becomes `var species = null;`
2. The wrapper `function viewOf(s) { return Reports.viewOf(s, filter, TODAY); }` becomes `function viewOf(s) { return Reports.viewOf(s, species, TODAY); }`
3. Any `Reports.rankSites(SITES, filter, TODAY)` (the Rivers list) becomes `Reports.rankSites(SITES, species, TODAY)`.
4. `var RANK = Reports.RANK, LABEL = Reports.LABEL, SP_NAME = Reports.SP_NAME;` becomes `var RANK = Reports.RANK, LABEL = Reports.LABEL;`
5. The three picker buttons become (markup only; Task 3 generates them):
   ```html
   <button type="button" role="radio" aria-checked="true" data-species="">All salmon</button>
   <button type="button" role="radio" aria-checked="false" data-species="Coho Salmon">Coho</button>
   <button type="button" role="radio" aria-checked="false" data-species="Chinook Salmon">Chinook</button>
   ```
6. In the picker click handler, `filter = b.getAttribute('data-f');` becomes `species = b.getAttribute('data-species') || null;`
7. In `applyStyles`, `(vw.k ? ' for ' + SP_NAME[vw.k].toLowerCase() : '')` becomes `(vw.k ? ' for ' + vw.k.toLowerCase() : '')`
8. In `fillSheet`: `['coho', 'chinook'].map(function (k) {` becomes `Reports.SPECIES.filter(function (k) { return !!s.reports[k]; }).map(function (k) {`; `var sp = s[k];` becomes `var sp = s.reports[k];`; every `SP_NAME[k]` becomes `esc(k)`; `SP_NAME[vw.k]` becomes `esc(vw.k)`.

Visible text is unchanged in this task except the sheet species names and aria-labels now read "Coho Salmon" / "Chinook Salmon".

- [ ] **Step 7: Prove nothing else changed**

```bash
grep -n -E "SP_NAME|'coho'|'chinook'|data-f|[^-]filter\b" Artifacts/salmon-rivers/index.html
```

Expected: no output (CSS `backdrop-filter` is excluded by the pattern; if a line shows, it is a missed substitution). Start `salmon-rivers` with `preview_start`, load `http://127.0.0.1:4173/?today=2026-10-18`, and run:

```js
(async () => {
  const map = { all: '', coho: 'Coho Salmon', chinook: 'Chinook Salmon' };
  const out = {};
  for (const f of Object.keys(map)) {
    document.querySelector(`.seg button[data-species="${map[f]}"]`).click();
    out[f] = [...document.querySelectorAll('.pin')]
      .map(p => p.dataset.id + ':' + p.style.getPropertyValue('--rc') + ':' + p.classList.contains('closed')).sort();
  }
  document.querySelector('.seg button[data-species=""]').click();
  return JSON.stringify(out);
})()
```

Expected: equals `JSON.stringify(JSON.parse(<contents of test/baseline-pins.json>))`. Also: open the Cowlitz sheet, rows read "Coho Salmon" and "Chinook Salmon" with their dates and badges as before; `read_console_messages` with `onlyErrors` is empty.

- [ ] **Step 8: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/index.html
git commit -m "Key salmon page reports by the app's exact species name

Reports were hard-coded to two fields, so a third species meant editing
logic everywhere. Reports now live in a map keyed by the same strings the
app's species picker uses, an unknown name throws instead of matching
nothing, and pin colours on 2026-10-18 are identical to the unmodified page.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Generate the species picker and word the missing-report state

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js` (add `pinLabel`), `Artifacts/salmon-rivers/test/reports.test.js`, `Artifacts/salmon-rivers/index.html`

**Interfaces:**
- Consumes: `Reports.SPECIES`, `viewOf` (Task 2), `LABEL`.
- Produces: `pinLabel(site, vw, species) -> string` (screen-reader name of a pin); picker buttons generated into `.seg` with `data-species` attributes (`""` for All).

- [ ] **Step 1: Write the failing tests**

Append to `test/reports.test.js`:

```js
test('pinLabel: rating and species, release caveat, and the no-report case in words', () => {
  const v = (id, sp) => R.viewOf(site(id), sp, TODAY);
  assert.equal(R.pinLabel(site('cowlitz'), v('cowlitz', null), null), 'Cowlitz River, excellent reports for coho salmon');
  assert.equal(R.pinLabel(site('cowlitz'), v('cowlitz', 'Chinook Salmon'), 'Chinook Salmon'), 'Cowlitz River, fair reports for chinook salmon, release only');
  const lone = { id: 'x', name: 'X River', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-17', d: '' } } };
  assert.equal(R.pinLabel(lone, R.viewOf(lone, 'Chinook Salmon', TODAY), 'Chinook Salmon'), 'X River, no report for Chinook Salmon');
  assert.equal(R.pinLabel({ id: 'y', name: 'Y River' }, R.viewOf({ id: 'y', name: 'Y River' }, null, TODAY), null), 'Y River, no report');
});
```

- [ ] **Step 2: Run to see it fail**

```bash
node --test "Artifacts/salmon-rivers/test/reports.test.js"
```

Expected: FAIL with `R.pinLabel is not a function`.

- [ ] **Step 3: Implement `pinLabel`**

In `reports.js` before the return, and add `pinLabel: pinLabel,` to the export:

```js
  function pinLabel(site, vw, species) {
    if (vw.k === null) return site.name + ', no report' + (species ? ' for ' + species : '');
    return site.name + ', ' + LABEL[vw.r].toLowerCase() + ' reports for ' + vw.k.toLowerCase() + (vw.release ? ', release only' : '');
  }
```

- [ ] **Step 4: Run to see it pass**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`.

- [ ] **Step 5: Generate the picker and use `pinLabel`**

Delete the three static buttons from the `.seg` markup so it is empty:

```html
<div class="seg" role="radiogroup" aria-label="Species"></div>
```

Immediately before the line `document.querySelectorAll('.seg button').forEach(function (b) {` (the click wiring), insert:

```js
  var seg = document.querySelector('.seg');
  [null].concat(Reports.SPECIES).forEach(function (name) {
    var b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('role', 'radio');
    b.setAttribute('aria-checked', name === species ? 'true' : 'false');
    b.setAttribute('data-species', name || '');
    b.textContent = name || 'All species';
    seg.appendChild(b);
  });
```

In `applyStyles`, replace the whole `pn.g.setAttribute('aria-label', ...)` statement with:

```js
      pn.g.setAttribute('aria-label', Reports.pinLabel(s, vw, species));
```

`.seg` already has `display: flex; flex-wrap: wrap`, so extra species wrap onto more rows; the `pads()` measurement already reads the bar height at init. If a later task adds an `aria-label` elsewhere that mentions `SP_NAME`, Task 2 Step 7's grep catches it.

- [ ] **Step 6: Verify in the page**

Load `http://127.0.0.1:4173/?today=2026-10-18` and run in the console:

```js
[...document.querySelectorAll('.seg button')].map(b => b.dataset.species + '|' + b.textContent + '|' + b.getAttribute('aria-checked'))
```

Expected: `["|All species|true","Coho Salmon|Coho Salmon|false","Chinook Salmon|Chinook Salmon|false"]`.

Rerun the Task 2 Step 7 pin-colour snippet unchanged: expected still equal to `baseline-pins.json` (the buttons were regenerated with the same `data-species` values).

Exercise the missing-report path, which no live river triggers today:

```js
delete Reports.SITES.find(s => s.id === 'wind').reports['Chinook Salmon'];
document.querySelector('.seg button[data-species="Chinook Salmon"]').click();
const wind = document.querySelector('.pin[data-id="wind"]');
[wind.style.getPropertyValue('--rc'), wind.getAttribute('aria-label')]
```

Expected: first value contains `unrated`, second is `Wind River, no report for Chinook Salmon`. If `--rc` is not an `unrated` colour, read `function colorVar` and make `colorVar('unrated')` return `'var(--unrated)'` (the token already exists on `:root`, `#8e8e93` light, so no new colour). Reload the page afterwards (the delete only lived in memory). Screenshot at the `mobile` preset (375 px) and confirm the three buttons sit on one or two rows, the map is not covered by the bar, and each button is at least 44 px tall (`b.getBoundingClientRect().height`).

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/index.html
git commit -m "Build the salmon page species picker from the data

Picker buttons now come from the species list, labelled with the app's
exact names ('All species' for the combined view), so adding a species is
a data change. A river with no report for the chosen species stays on the
map in gray and its pin reads 'no report for <species>' to screen readers.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Sheet explains a missing report and attributes each new report

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js` (add `reportRows`, `missingNote`), `Artifacts/salmon-rivers/test/reports.test.js`, `Artifacts/salmon-rivers/index.html` (`fillSheet`)

**Interfaces:**
- Consumes: `SPECIES`, `SITES[i].reports[name].src` (optional `{ label, url }`).
- Produces: `reportRows(site) -> [{ name, sp }]` in `SPECIES` order, only species the site has; `missingNote(site, species) -> string|null`.

Why per-report `src`: the sheet's footer links are page-level (The Guide's Forecast Oct 17 and Oct 15, NW Sportsman Oct 13 for Lewis). They cannot say which report came from which article, and a new species will come from a different article. The twelve existing reports are not re-attributed (that would be a guess); they keep the page-level links. Every report added from now on must carry its own `src`.

- [ ] **Step 1: Write the failing tests**

Append to `test/reports.test.js`:

```js
test('reportRows lists only the species a site has, in SPECIES order', () => {
  const lone = { id: 'x', name: 'X', reports: { 'Chinook Salmon': { r: 'fair', asOf: null, d: 'a' } } };
  assert.deepEqual(R.reportRows(lone).map(r => r.name), ['Chinook Salmon']);
  assert.deepEqual(R.reportRows(site('wind')).map(r => r.name), ['Coho Salmon', 'Chinook Salmon']);
  assert.deepEqual(R.reportRows({ id: 'y', name: 'Y' }), []);
});

test('missingNote speaks only when a chosen species has no report on that water', () => {
  const lone = { id: 'x', name: 'X', reports: { 'Coho Salmon': { r: 'good', asOf: null, d: '' } } };
  assert.equal(R.missingNote(lone, null), null);
  assert.equal(R.missingNote(lone, 'Coho Salmon'), null);
  assert.match(R.missingNote(lone, 'Chinook Salmon'), /^No report for Chinook Salmon on this water\. Confirm what is open and what you may keep on WDFW before you fish\.$/);
});

// The twelve reports that predate per-report sources. They are covered by the page-level
// source links and must not gain a guessed attribution. This list only ever shrinks.
const LEGACY = new Set(['cowlitz', 'columbia', 'lewis', 'wind', 'klickitat', 'drano']
  .flatMap(id => ['Coho Salmon', 'Chinook Salmon'].map(n => id + '/' + n)));

test('every report added after the species change names its source', () => {
  for (const s of R.SITES) {
    for (const [name, sp] of Object.entries(s.reports)) {
      if (LEGACY.has(s.id + '/' + name)) continue;
      assert.ok(sp.src && sp.src.label && /^https:\/\//.test(sp.src.url), `${s.id}/${name} needs src {label, url}`);
    }
  }
});

test('control: the legacy list matches reality, so the source check is not vacuous', () => {
  const actual = R.SITES.flatMap(s => Object.keys(s.reports).map(n => s.id + '/' + n));
  for (const key of LEGACY) assert.ok(actual.includes(key), `${key} is listed as legacy but is not in SITES`);
});
```

- [ ] **Step 2: Run to see it fail**

```bash
node --test "Artifacts/salmon-rivers/test/reports.test.js"
```

Expected: FAIL with `R.reportRows is not a function` and `R.missingNote is not a function`. The two source tests pass already (every current report is legacy).

- [ ] **Step 3: Implement**

In `reports.js` before the return, adding `reportRows: reportRows, missingNote: missingNote,` to the export:

```js
  function reportRows(site) {
    var have = reportsOf(site);
    return SPECIES.filter(function (k) { return !!have[k]; }).map(function (k) { return { name: k, sp: have[k] }; });
  }
  function missingNote(site, species) {
    if (species === null || reportsOf(site)[species]) return null;
    return 'No report for ' + species + ' on this water. Confirm what is open and what you may keep on WDFW before you fish.';
  }
```

- [ ] **Step 4: Run to see it pass, then watch the source check go red**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`. Prove the source rule bites: temporarily change `const LEGACY = new Set(...)` to `const LEGACY = new Set()`. Expected FAIL: `cowlitz/Coho Salmon needs src {label, url}`. Revert.

- [ ] **Step 5: Use them in `fillSheet`**

Replace the Task 2 row-building line `Reports.SPECIES.filter(function (k) { return !!s.reports[k]; }).map(function (k) {` and its body with `Reports.reportRows(s).map(function (r) { var k = r.name, sp = r.sp; ... })`, keeping the row template (including the date chip) as it is, so the beginning reads:

```js
    var rows = Reports.reportRows(s).map(function (r) {
      var k = r.name, sp = r.sp;
```

(delete the old `var sp = s.reports[k];` line). After the `rows` assignment add:

```js
    var missing = Reports.missingNote(s, species);
    var extraSrc = [];
    Reports.reportRows(s).forEach(function (r) {
      var q = r.sp.src;
      if (q && extraSrc.every(function (e) { return e.url !== q.url; })) extraSrc.push(q);
    });
```

In the sheet HTML, change the "What's biting" section to:

```js
      '<section><h3>What’s biting</h3>' + (missing ? '<p class="miss">' + esc(missing) + '</p>' : '') + '<div class="rows">' + rows + '</div></section>' +
```

and append the per-report links to `src`, after the `(s.extra === 'nws' ? ... : '')` expression:

```js
      + extraSrc.map(function (e) { return '<a href="' + esc(e.url) + '" target="_blank" rel="noopener">' + esc(e.label) + '</a>'; }).join('');
```

CSS, next to the `.row` rules:

```css
.miss { margin: 0 0 8px; font-size: 13px; line-height: 18px; color: var(--ink2); }
```

(`--ink2` is the secondary text token already used by `.chip.old`; check with `grep -n -- '--ink2' Artifacts/salmon-rivers/index.html` and use the secondary-text token that exists if the name differs.)

- [ ] **Step 6: Verify in the page**

At `http://127.0.0.1:4173/?today=2026-10-18`: open the Wind sheet with All species selected; no `.miss` element (`document.querySelector('#sbody .miss') === null`), two rows, the footer still has the WDFW link, the "Before you go" section and the "Recent catch reports, not season dates" line. Then, in the console, remove Wind's Chinook report as in Task 3 Step 6 and select Chinook Salmon: the sheet shows `No report for Chinook Salmon on this water. Confirm what is open and what you may keep on WDFW before you fish.` above one row (Coho), and the WDFW link and advisory are still present. Reload to restore the data.

- [ ] **Step 7: Commit**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/test/reports.test.js Artifacts/salmon-rivers/index.html
git commit -m "Say so on the sheet when a river has no report for a species

Selecting a species a river has no report for left a gray pin and a sheet
that never mentioned it. The sheet now says there is no report and points
to WDFW. New reports must carry their own source link (a test enforces
it); the twelve existing reports keep the page-level links rather than
getting a guessed attribution.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Add sourced reports for a species (repeat per species; data work)

This task is a procedure, run once per species Daniel wants. It may legitimately end with nothing added: if no source reports a species on these waters, say so and stop. Do not fill the page with guesses to make it look covered.

**Files:**
- Modify: `Artifacts/salmon-rivers/reports.js` (`SPECIES`, `SITES[i].reports`)
- Modify (first non-salmon species only): `Artifacts/salmon-rivers/index.html` (`<title>`, `.title` text), `Artifacts/salmon-rivers/artifact.json`

**Interfaces:**
- Consumes: the guard tests from Tasks 1, 2 and 4, which now enforce exact names, valid ratings, real dates and a `src` on every new report.
- Produces: new `SPECIES` entries and `reports` entries.

- [ ] **Step 1: Pick the species and confirm it is an app name**

Ask Daniel which of the candidate names under "What data would need sourcing" to try first if the request does not already say. Confirm the exact string exists:

```bash
jq -r '[.areas[].species[].species, .freshwater.species[].species, (.freshwater.byCounty[][] | .species), (.freshwater.byWaterbody[][] | .species)] | unique | .[]' WAFishMap/Resources/fisheries.json | grep -x -F -e "<exact name>"
```

Expected: the name printed back. No output means it is not an app species; do not add it.

- [ ] **Step 2: Search sources, one river at a time**

For each of the six waters (Cowlitz River, Lower Columbia River, Lewis River, Wind River, Klickitat River, Drano Lake), look in the sources listed above for the newest report that (a) names the water, (b) names the species, (c) carries a date, (d) describes fishing quality in words. Use the built-in browser or `firecrawl_search`; read the source page itself, not a search snippet. Keep, for each hit: the URL, the page's name, the date the report is about, and the sentence supporting the rating.

Rating rule, from the source's own words only:
- "excellent", "limited out", "hot" in the source's own phrasing becomes `prime`
- "good" or "very good" becomes `good`
- "fair", "some fish", "a few" becomes `fair`
- counts only, no quality statement, or poor/slow/closed: do not add the report (the page has no lower rating; mention this to Daniel in the hand-off)
- never compute a rating from a count, and never carry a rating from one species to another

The date rule: `asOf` is the date the report describes, as the source states it. If the source prints only a publication date, use that. If it prints none, `asOf: null` (the page then shows "Date not given"). Never infer a date.

- [ ] **Step 3: Write the entries**

Add the species to `SPECIES` (position = picker order), then add a key to each water's `reports`. Form of one entry (each angle-bracket field is filled from the source, not from this plan):

```js
'<exact app species name>': { r: '<prime|good|fair>', asOf: '<YYYY-MM-DD or null>',
  d: '<one sentence of the source's claim, numbers as published, no date in the prose>',
  src: { label: '<Publication, Mon D>', url: 'https://<the page you read>' } }
```

Add `release: true` only if the source says the species must be released. Keep `d` to what the source says: no embellishment, no "peak" or "run is on" language the source did not use.

- [ ] **Step 4: Run the guards**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`. These tests fail, in order of likelihood, for: a name not exactly in `fisheries.json`; a species in `SPECIES` with no river report (or a river key not in `SPECIES`); a rating outside `prime|good|fair`; an impossible date; a month-day left in `d`; a missing `src`.

- [ ] **Step 5: Check the page**

At `http://127.0.0.1:4173/?today=<the newest asOf you added>`:
- The picker has a new button with the exact name; selecting it recolours: rivers with a report take its colour, others turn gray with "No report" semantics (aria-label `<River>, no report for <name>`).
- Open a sheet that has the new report: its row, date chip, and the source link in the footer. Open a sheet that does not: the no-report note, the WDFW link and "Before you go" are present.
- The count: `document.querySelectorAll('.seg button').length === Reports.SPECIES.length + 1`.
- Light and dark, desktop and `mobile` preset; no console errors.

- [ ] **Step 6: If this is the first species whose name does not contain "Salmon", retitle**

The page says "Salmon this month" and the tab says "SW Washington Salmon Rivers". Change `<title>` to `SW Washington Fishing Reports`, the `.title` text to `Fishing this month`, and the `artifact.json` `title` and `what` fields to match (say the page now covers the species listed in `SPECIES`). Re-grep: `grep -n -i "salmon" Artifacts/salmon-rivers/index.html` and read each hit; leave ones that are about salmon specifically (the Guide's Forecast link text, species names).

- [ ] **Step 7: Commit (one species per commit)**

```bash
git add Artifacts/salmon-rivers/reports.js Artifacts/salmon-rivers/index.html Artifacts/salmon-rivers/artifact.json
git commit -m "Add <species> catch reports to the rivers page

<which waters have a report and which sources; which waters have none>.
Ratings are the sources' own wording; rivers without a report stay gray.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

(Omit `index.html` and `artifact.json` from `git add` when Step 6 did not apply.)

---

### Task 6: Publish

**Files:**
- Modify: `Artifacts/salmon-rivers/artifact.json`

- [ ] **Step 1: Gate on there being something new**

```bash
node -e 'global.window={};const R=require("./Artifacts/salmon-rivers/reports.js");console.log(R.SPECIES.join(" | "))'
```

Expected: more than `Coho Salmon | Chinook Salmon`. If it is still just those two, there is no visible gain over the live page; do not publish. Tell Daniel that Tasks 1 to 4 are in the repo and what Task 5 still needs (the sourcing note above). Stop here.

- [ ] **Step 2: Run the whole check**

```bash
node --test "Artifacts/salmon-rivers/test/*.test.js" 2>&1 | grep -E '^# (pass|fail)'
```

Expected: `# fail 0`. Walk Task 3 Step 6 and Task 4 Step 6 once more on the final files at desktop and `mobile`, light and dark. Check the footer on every sheet: WDFW link, "Before you go", the disclaimer line.

- [ ] **Step 3: Get Daniel's yes**

This replaces a live page. Say in two or three lines: which species were added and from which sources, that rivers without a report show gray and say so, that the page still shows dated catch reports only (no seasonal timing), and that rollback is republishing the previous version (`artifact.json` `currentVersion`, or `baseline.html`). Wait for a clear yes in chat.

- [ ] **Step 4: Confirm nobody edited the live page, then publish**

```
Artifact action=read url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
```

If its version differs from `artifact.json` `currentVersion`, someone edited it: show Daniel the difference before going on. Otherwise publish (no `icon` on an update):

```
Artifact
  file_path=Artifacts/salmon-rivers/index.html
  url=https://claude.ai/artifact/9oA145toRsmFcDYurdJbey
  files={ "geo.js": "Artifacts/salmon-rivers/geo.js", "reports.js": "Artifacts/salmon-rivers/reports.js" }
  label="Species picker from the app's species"
```

If refused because the live page changed, merge onto the newer content it hands back; never use `force`.

- [ ] **Step 5: Verify live**

Open the live URL. Expected: the new picker buttons, a gray river with "No report" semantics when a species with partial coverage is chosen, no console errors, WDFW link on a sheet.

- [ ] **Step 6: Record and commit**

Set `currentVersion` in `artifact.json` to the version id the publish reported and make `what` list the species the page covers.

```bash
git add Artifacts/salmon-rivers/artifact.json
git commit -m "Record the published version with the species picker

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-review

- **Brief coverage:** decision with recommendation and evidence (top section); guidance-not-regulation, WDFW link and disclaimer on every sheet (Global Constraints, Task 4 and 6 checks); exact species-name matching (Task 1 test, Task 2 throw, near-miss controls); never invent facts or dates (Task 5 rules, `asOf: null`, no-report state); data sourcing note (its own section and Task 5); no change to the page itself in this deliverable (this is a plan file only).
- **Placeholders:** the only angle-bracket fields are in Task 5's data form and commit message, deliberately filled from sources at execution, and in Task 6's version id; no code step contains TODO or "similar to".
- **Names:** `SPECIES`, `reports`, `viewOf(site, species, today)`, `rankSites(sites, species, today)`, `pinLabel`, `reportRows`, `missingNote`, `data-species`, `species` (page variable) are used identically across tasks. `SP_NAME` is removed in Task 2 and not referenced later.
- **Known risk:** Task 2 Step 3's regex assumes each species object is one line with no `}` inside strings, as in the earlier plan's data. Step 3's printed count (12) and the follow-up read of the result catch a mismatch before any test depends on it. Edits to `index.html` use the line shapes of the pre-Task-3-of-earlier-plan page quoted in that plan; Task 2 Step 7's grep is the backstop for any occurrence a later task of that plan added.
