const test = require('node:test');
const assert = require('node:assert/strict');
const R = require('../reports.js');

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
  assert.equal(R.latestReport(R.SITES), '2026-10-17');
  assert.equal(R.latestReport([{ id: 'x', name: 'X', reports: { 'Coho Salmon': { r: 'fair', asOf: null, d: '' } } }]), null);
});

test('staleNotice appears only when the newest report is older than 7 days', () => {
  assert.equal(R.staleNotice(R.SITES, '2026-10-24'), null); // 7 days
  assert.match(R.staleNotice(R.SITES, '2026-10-26'), /9 days old \(Oct 17\)/);
  assert.equal(R.staleNotice([{ id: 'x', name: 'X' }], TODAY), null); // nothing dated, nothing to claim
});

test('rankSites: retainable first, fresh before stale, then rating, then name', () => {
  const ids = f => R.rankSites(R.SITES, F[f], TODAY).map(e => e.site.id);
  assert.deepEqual(ids('all'), ['cowlitz', 'columbia', 'drano', 'klickitat', 'lewis', 'wind']);
  assert.deepEqual(ids('chinook'), ['drano', 'klickitat', 'lewis', 'wind', 'cowlitz', 'columbia']);
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
