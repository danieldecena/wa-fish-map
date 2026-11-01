const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const R = require('../reports.js');
const C = require('../counts.js');

const TODAY = '2026-10-18';
const site = id => R.SITES.find(s => s.id === id);
const F = { all: null, coho: 'Coho Salmon', chinook: 'Chinook Salmon' };
const back = k => (k === null ? null : Object.keys(F).find(n => F[n] === k));
const pick = (id, filter, today = TODAY) => {
  const v = R.viewOf(site(id), F[filter], today);
  return { r: v.r, k: back(v.k), release: v.release };
};
const two = (coho, chinook) => ({ id: 'x', name: 'X', reports: { 'Coho Salmon': coho, 'Chinook Salmon': chinook } });

test('viewOf keeps the colours the published page showed on 2026-10-18', () => {
  // Expected values come from the unmodified page (test/baseline-pins.json).
  const expect = {
    cowlitz:   { all: ['prime', 'coho', false],    coho: ['prime', 'coho', false], chinook: ['fair', 'chinook', true] },
    columbia:  { all: ['prime', 'coho', false],    coho: ['prime', 'coho', false], chinook: ['fair', 'chinook', true] },
    lewis:     { all: ['good', 'coho', false],     coho: ['good', 'coho', false],  chinook: ['fair', 'chinook', false] },
    // Wind changed on purpose on 2026-10-31: both species are release only from Nov 1 (pamphlet: release all salmon).
    wind:      { all: ['good', 'coho', true],      coho: ['good', 'coho', true],   chinook: ['fair', 'chinook', true] },
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
  assert.equal(R.latestReport(R.SITES), '2026-10-29');
  assert.equal(R.latestReport([{ id: 'x', name: 'X', reports: { 'Coho Salmon': { r: 'fair', asOf: null, d: '' } } }]), null);
});

test('staleNotice appears only when the newest report is older than 7 days', () => {
  assert.equal(R.staleNotice(R.SITES, '2026-11-05'), null); // 7 days
  assert.match(R.staleNotice(R.SITES, '2026-11-07'), /9 days old \(Oct 29\)/);
  assert.equal(R.staleNotice([{ id: 'x', name: 'X' }], TODAY), null); // nothing dated, nothing to claim
});

test('rankSites: retainable first, fresh before stale, then rating, then name', () => {
  const ids = f => R.rankSites(R.SITES, F[f], TODAY).map(e => e.site.id);
  // Kalama (slow, fresh) ranks below the good rivers; Skagit (fair, 8 days old on TODAY, so stale) comes after every fresh river;
  // Washougal has no report and goes last of the retainable sites. Wind is release only (2026-10-31), so it ranks after every retainable site.
  assert.deepEqual(ids('all'), ['cowlitz', 'columbia', 'drano', 'klickitat', 'lewis', 'kalama', 'skagit', 'washougal', 'wind']);
  assert.deepEqual(ids('chinook'), ['drano', 'klickitat', 'lewis', 'kalama', 'skagit', 'washougal', 'cowlitz', 'columbia', 'wind']);
});

test('ratingWord carries the release-only caveat as text', () => {
  assert.equal(R.ratingWord({ r: 'prime', release: false }), 'Excellent');
  assert.equal(R.ratingWord({ r: 'fair', release: true }), 'Fair, release only');
  assert.equal(R.ratingWord({ r: 'unrated', release: false }), 'No report');
});

test('report data: ids unique, species exact, ratings valid, dates real, no dates in prose', () => {
  const ids = new Set();
  const used = new Set();
  for (const s of R.SITES) {
    assert.ok(!ids.has(s.id), `duplicate ${s.id}`); ids.add(s.id);
    // A site with no reports at all is allowed only when WDFW counts back its sheet (see the counts-only test).
    if (Object.keys(s.reports || {}).length === 0) { assert.ok(C.forWater(s.id), `${s.id} has no reports and no counts`); continue; }
    for (const [name, sp] of Object.entries(s.reports)) {
      assert.ok(R.SPECIES.includes(name), `${s.id}: "${name}" is not in Reports.SPECIES`);
      used.add(name);
      if (sp.r === 'slow') {
        // Slow is only the source's own word, recorded in phrase and linked, never worked out from a number.
        assert.match(sp.phrase || '', /\b(slow|poor)\b/i, `${s.id}/${name} is slow without a recorded source phrase`);
        assert.ok(sp.src && /^https:\/\//.test(sp.src.url), `${s.id}/${name} is slow without a source url`);
      } else {
        assert.ok(['prime', 'good', 'fair'].includes(sp.r), `${s.id}/${name} rating`);
      }
      if (sp.asOf !== null) R.ageDays(sp.asOf, TODAY);
      assert.doesNotMatch(sp.d, /\b(Oct|Nov|Dec)\s+\d{1,2}\b/, `${s.id}/${name} prose still names a date`);
    }
  }
  assert.equal(ids.size, 9);
  for (const n of R.SPECIES) assert.ok(used.has(n), `${n} is in SPECIES but no river has a report for it`);
});

test('pinLabel: rating and species, release caveat, and the no-report case in words', () => {
  const v = (id, sp) => R.viewOf(site(id), sp, TODAY);
  assert.equal(R.pinLabel(site('cowlitz'), v('cowlitz', null), null), 'Cowlitz River, excellent reports for coho salmon');
  assert.equal(R.pinLabel(site('cowlitz'), v('cowlitz', 'Chinook Salmon'), 'Chinook Salmon'), 'Cowlitz River, fair reports for chinook salmon, release only');
  const lone = { id: 'x', name: 'X River', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-17', d: '' } } };
  assert.equal(R.pinLabel(lone, R.viewOf(lone, 'Chinook Salmon', TODAY), 'Chinook Salmon'), 'X River, no report for Chinook Salmon');
  assert.equal(R.pinLabel({ id: 'y', name: 'Y River' }, R.viewOf({ id: 'y', name: 'Y River' }, null, TODAY), null), 'Y River, no report');
});

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

// The reports that predate per-report sources. They are covered by the page-level
// source links and must not gain a guessed attribution. This list only ever shrinks:
// 2026-10-31 dropped Wind and Drano coho (replaced by sourced reports) and the Klickitat
// pair and Drano Chinook (their Oct 15 wording matched The Guide's Forecast word for word).
const LEGACY = new Set(['cowlitz/Coho Salmon', 'cowlitz/Chinook Salmon', 'columbia/Coho Salmon', 'columbia/Chinook Salmon',
  'lewis/Coho Salmon', 'lewis/Chinook Salmon', 'wind/Chinook Salmon']);

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

test('Kalama\'s slow entry carries the source word and a link to the report that said it', () => {
  const k = site('kalama').reports['Coho Salmon'];
  assert.equal(k.r, 'slow');
  assert.match(k.phrase, /\b(slow|poor)\b/i);
  assert.match(k.src.url, /^https:\/\/www\.theguidesforecast\.com\/free\/coho-run-heats-up\/287017\/$/);
  assert.equal(k.asOf, '2026-10-17');
  assert.equal(R.viewOf(site('kalama'), null, TODAY).r, 'slow');
  assert.equal(R.ratingWord({ r: 'slow', release: false }), 'Slow');
});

test('a counts-only site is a No report pin, still listed, and its counts are there to show', () => {
  const w = site('washougal');
  assert.deepEqual(w.reports, {});
  for (const sp of [null, 'Coho Salmon', 'Chinook Salmon', 'Fall Chinook']) {
    const v = R.viewOf(w, sp, TODAY);
    assert.deepEqual({ r: v.r, k: v.k, release: v.release, fresh: v.fresh }, { r: 'unrated', k: null, release: false, fresh: false }, String(sp));
  }
  assert.equal(R.pinLabel(w, R.viewOf(w, null, TODAY), null), 'Washougal River, no report');
  assert.deepEqual(R.reportRows(w), []);
  assert.ok(R.rankSites(R.SITES, null, TODAY).some(e => e.site.id === 'washougal'), 'listed in Rivers');
  const c = C.forWater('washougal');
  assert.ok(c && c.noCatch && c.rows.length === 0, 'its WDFW counts are in counts.js');
});

test('no rating is ever derived from counts: reports.js has no code path to them, and a site with only counts is unrated', () => {
  // Strip comments and quoted text (report prose may say the word creel); what is left is code.
  const code = fs.readFileSync(path.join(__dirname, '..', 'reports.js'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/'(?:[^'\\\n]|\\.)*'/g, "''");
  assert.doesNotMatch(code, /counts|creel|noCatch|weekStart|weekEnd|forWater|require\s*\(/i);
  for (const s of R.SITES) {
    if (C.forWater(s.id) && Object.keys(s.reports).length === 0) assert.equal(R.viewOf(s, null, TODAY).r, 'unrated', s.id);
  }
});

test('the Recent reports legend lists Slow exactly when some site in Recent reports has a Slow rating', () => {
  const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  const anySlow = R.SITES.some(s => Object.values(s.reports).some(sp => sp.r === 'slow'));
  const slowItem = '<li style="--c:var(--slow)"><i></i>Slow</li>';
  const staticLegend = html.slice(html.indexOf('<ul id="legl">'), html.indexOf('</ul>', html.indexOf('<ul id="legl">')));
  const recentJs = html.split('\n').find(l => l.includes('Faded: release only') && l.includes('Excellent'));
  assert.ok(recentJs, 'control: found the Recent reports legend string in the script');
  assert.equal(staticLegend.includes(slowItem), anySlow, 'static legend');
  assert.equal(recentJs.includes(slowItem), anySlow, 'legend set when switching back to Recent reports');
});

// ---- new report sites (entries with `added`): docs/superpowers/specs/2026-10-26-puget-river-reports-design.md ----
const loadGlobal = (file, name) => { const w = {}; new Function('window', fs.readFileSync(path.join(__dirname, '..', file), 'utf8'))(w); return w[name]; };
const GEO = loadGlobal('geo.js', 'GEO');
const TAP = loadGlobal('rivers-tap.js', 'RIVERTAP');
const TAP_IDS = new Set(TAP.rivers.map(r => r.id));

test('rivers-tap.js and geo.js share one projection', () => {
  // index.html draws a tappable river's path in geo.js viewport coordinates; no generator keeps the two files in step.
  assert.deepEqual(TAP.proj, GEO.proj);
});

const ENTRY_DAYS = 21;
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
    [withSp({ asOf: '2026-10-03' }), /22 days old/],
    [withSp({ asOf: '2026-10-26' }), /-1 days old/],
    [withSp({ r: 'slow' }), /slow needs/],
  ];
  for (const [s, re] of cases) assert.match(newSiteProblems(s).join('\n'), re);
});

test('every new report site follows the rules (entries without `added` are the original eight)', () => {
  assert.deepEqual(R.SITES.filter(s => s.added).flatMap(newSiteProblems), []);
  assert.equal(R.SITES.filter(s => !s.added).length, 8, 'control: the original eight carry no added date');
});

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
