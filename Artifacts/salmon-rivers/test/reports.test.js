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
