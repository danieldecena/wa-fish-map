const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const S = require('../season.js');
const T = require('../typical.js');

const repo = path.join(__dirname, '..', '..', '..');
const swiftTests = fs.readFileSync(path.join(repo, 'WAFishMapTests/FisheryTests.swift'), 'utf8')
  + fs.readFileSync(path.join(repo, 'WAFishMapTests/SeasonRiskTests.swift'), 'utf8');

// Every expectation below is copied from a named Swift test. This guard fails if one of those tests is renamed or removed,
// so the port cannot silently stop being pinned to the app.
const PINNED = [
  'peakMonthIsExcellent', 'goodMonthIsGood', 'shoulderMonthIsFair', 'offSeasonIsPoor', 'decemberJanuaryWrapsAround',
  'areaRatingTakesBestSpecies', 'areaRatingIsPoorWithNoSpecies', 'inSeasonIsSortedBestFirstAndExcludesOffSeason',
  'flaggedMonthCapsPeakToFair', 'unflaggedMonthKeepsFullRating', 'capNeverRaisesAWeakRating',
  'namedSpeciesRatingIsExactMatchOnly', 'breadthRatingAveragesTheTopThreeSpecies', 'breadthRatingKeepsASingleSpeciesSpotAtItsOwnRating',
  'oddRowRatesExcellentInAnOddYearAndPoorInAnEvenYear', 'rowWithoutYearsIsUnaffectedByEitherYear',
  'matchesParentheticalVariants', 'matchingIsCaseInsensitive', 'doesNotMatchUnrelatedSpecies',
  'multipleMatchingRowsUnionMonthsAndJoinReasons', 'rowCanOptOutOfTheTable', 'areaOfOnlyFlaggedSpeciesCapsToFair',
  'unflaggedSpeciesKeepsTheAreaPrime', 'closurePlausibleForANamedSpeciesFollowsItsRiskMonths', 'closurePlausibleForAllNeedsEveryTopSpeciesFlagged',
  'area7PinkSalmonIsNotPrimeInAnEvenYearButIsInAnOddYear'
];
test('every Swift test this port is pinned to still exists', () => {
  for (const n of PINNED) assert.match(swiftTests, new RegExp('func ' + n + '\\('), `Swift test ${n} is gone`);
});

// Build a stamped row the way the app does: stamp(row, riskTable, year).
const row = (species, best, good = [], extra = {}) => ({ species, bestMonths: best, goodMonths: good, ...extra });
const st = (r, table = [], year = 2025) => S.stamp(r, table, year);
const coho = () => st(row('Coho', [9, 10], [8, 11]));

test('peakMonthIsExcellent / goodMonthIsGood / shoulderMonthIsFair / offSeasonIsPoor', () => {
  const c = coho();
  assert.equal(S.speciesRating(c, 9), S.EXCELLENT);
  assert.equal(S.speciesRating(c, 10), S.EXCELLENT);
  assert.equal(S.speciesRating(c, 8), S.GOOD);
  assert.equal(S.speciesRating(c, 11), S.GOOD);
  assert.equal(S.speciesRating(c, 7), S.FAIR);
  assert.equal(S.speciesRating(c, 12), S.FAIR);
  assert.equal(S.speciesRating(c, 3), S.POOR);
});

test('decemberJanuaryWrapsAround', () => {
  const squid = st(row('Squid', [12, 1]));
  assert.equal(S.speciesRating(squid, 11), S.FAIR);
  assert.equal(S.speciesRating(squid, 2), S.FAIR);
  assert.equal(S.circularMonthDistance(12, 1), 1);
  assert.equal(S.circularMonthDistance(1, 12), 1);
});

test('areaRatingTakesBestSpecies and areaRatingIsPoorWithNoSpecies (closure flag uses the max, as the app does)', () => {
  const rows = [st(row('Peaking', [6])), st(row('Merely good', [], [6]))];
  assert.equal(Math.max(...rows.map(r => S.speciesRating(r, 6))), S.EXCELLENT);
  assert.equal(S.breadthRating([], 6), S.POOR);
});

test('inSeasonIsSortedBestFirstAndExcludesOffSeason', () => {
  const rows = [st(row('Good', [], [6])), st(row('Peak', [6])), st(row('Off', [1]))];
  assert.deepEqual(S.inSeason(rows, 6).map(r => r.species), ['Peak', 'Good']);
});

test('flaggedMonthCapsPeakToFair, unflaggedMonthKeepsFullRating, capNeverRaisesAWeakRating', () => {
  const table = (months) => [{ match: 'Coho', months, reason: 'Quota-driven' }];
  assert.equal(S.speciesRating(st(row('Coho', [9, 10], [8, 11]), table([9])), 9), S.FAIR);
  assert.equal(S.speciesRating(st(row('Coho', [9, 10], [8, 11]), table([9])), 10), S.EXCELLENT);
  assert.equal(S.speciesRating(st(row('Coho', [9, 10], [8, 11]), table([3])), 3), S.POOR);
  assert.equal(S.speciesRating(coho(), 9), S.EXCELLENT, 'unstamped species is unaffected');
});

test('namedSpeciesRatingIsExactMatchOnly', () => {
  const rows = [st(row('Chinook Salmon', [8])), st(row('Chinook Salmon (ocean)', [6])), st(row('Coho', [], [8]))];
  // All is the breadth rating: Prime, Slow, Good average to Good.
  assert.equal(S.areaRating(rows, 8, null), S.GOOD);
  assert.equal(S.areaRating(rows, 8, 'Chinook Salmon'), S.EXCELLENT);
  assert.equal(S.areaRating(rows, 8, 'Chinook Salmon (ocean)'), S.POOR);
  assert.equal(S.areaRating(rows, 8, 'Coho'), S.GOOD);
  assert.equal(S.areaRating(rows, 8, 'Lingcod'), null);
});

test('breadthRatingAveragesTheTopThreeSpecies', () => {
  const rows = ['A', 'B', 'C'].map(n => st(row(n, [9]))).concat([st(row('D', [3]))]);
  assert.equal(S.breadthRating(rows, 9), S.EXCELLENT);
  // One peak among slow species is no longer Prime, as max would say.
  assert.equal(Math.max(...rows.map(r => S.speciesRating(r, 3))), S.EXCELLENT);
  assert.equal(S.breadthRating(rows, 3), S.FAIR);
});

test('breadthRatingKeepsASingleSpeciesSpotAtItsOwnRating', () => {
  assert.equal(S.breadthRating([st(row('Kokanee', [6]))], 6), S.EXCELLENT);
  assert.equal(S.breadthRating([], 6), S.POOR);
});

test('odd/even year rows: oddRowRatesExcellentInAnOddYearAndPoorInAnEvenYear, rowWithoutYearsIsUnaffectedByEitherYear', () => {
  const pink = row('Pink Salmon', [8, 9], [7], { years: 'odd' });
  assert.equal(S.speciesRating(st(pink, [], 2025), 8), S.EXCELLENT);
  assert.equal(S.speciesRating(st(pink, [], 2026), 8), S.POOR);
  const c = row('Coho', [9, 10]);
  assert.equal(S.speciesRating(st(c, [], 2025), 9), S.EXCELLENT);
  assert.equal(S.speciesRating(st(c, [], 2026), 9), S.EXCELLENT);
});

test('season-risk matching: parenthetical variants, case-insensitive, unrelated species', () => {
  const chinook = { match: 'Chinook', months: [1, 2, 3], reason: 'r' };
  for (const n of ['Chinook Salmon', 'Chinook Salmon (ocean)', 'Chinook Salmon (Tulalip)', 'Resident Chinook (Blackmouth)', 'CHINOOK SALMON', 'chinook salmon']) {
    assert.ok(S.riskMatches(chinook, n), n);
  }
  for (const n of ['Coho Salmon', 'Rainbow Trout']) assert.ok(!S.riskMatches(chinook, n), n);
});

test('multipleMatchingRowsUnionMonthsAndJoinReasons', () => {
  const table = [
    { match: 'Chinook Salmon (ocean)', months: [6, 7, 8], reason: 'Ocean quota' },
    { match: 'Chinook Salmon', months: [7, 8, 9], reason: 'Summer quota' }
  ];
  const r = S.resolveRisk(row('Chinook Salmon (ocean)', [7]), table);
  assert.deepEqual(r.riskMonths, [6, 7, 8, 9]);
  assert.equal(r.riskReason, 'Ocean quota; Summer quota');
});

test('rowCanOptOutOfTheTable and unflaggedSpeciesKeepsTheAreaPrime / areaOfOnlyFlaggedSpeciesCapsToFair', () => {
  const table = [{ match: 'Chinook', months: [1, 2], reason: 'Quota-driven' }];
  const optOut = st(row('Chinook Salmon', [1], [], { seasonRisk: 'none' }), table);
  assert.deepEqual(optOut.riskMonths, []);
  assert.equal(S.breadthRating([optOut], 1), S.EXCELLENT);
  const mixed = [st(row('Chinook Salmon', [1]), table), st(row('Rainbow Trout', [1]), table)];
  assert.equal(S.areaRating(mixed, 1, 'Rainbow Trout'), S.EXCELLENT);
  assert.equal(S.breadthRating([st(row('Chinook Salmon', [1]), [{ match: 'Chinook', months: [1], reason: 'r' }])], 1), S.FAIR);
});

test('closurePlausible: a named species follows its risk months; All needs every top species flagged', () => {
  const table = [{ match: 'Chinook', months: [1, 2], reason: 'Quota-driven' }];
  const rows = [st(row('Chinook Salmon', [1]), table), st(row('Rainbow Trout', [1]), table)];
  assert.equal(S.closurePlausible(rows, 1, 'Chinook Salmon'), true);
  assert.equal(S.closurePlausible(rows, 3, 'Chinook Salmon'), false);
  assert.equal(S.closurePlausible(rows, 1, 'Rainbow Trout'), false);
  assert.equal(S.closurePlausible(rows, 1, 'Not Listed'), false);
  // Unflagged trout is Prime in January, so the spot is not in doubt.
  assert.equal(S.closurePlausible(rows, 1, null), false);
  assert.equal(S.closurePlausible([rows[0]], 1, null), true);
});

// ---- the shipped data, through the same port ----

const area = (id) => T.guides.find(g => g.kind === 'marine' && g.area === id);
test('area7PinkSalmonIsNotPrimeInAnEvenYearButIsInAnOddYear (shipped data)', () => {
  const g7 = area('7');
  assert.ok(g7, 'area 7 guide present');
  const rowsFor = (year) => S.prepare(T, year).guides[T.guides.indexOf(g7)].rows;
  assert.equal(S.areaRating(rowsFor(2026), 8, 'Pink Salmon'), S.POOR);
  assert.equal(S.areaRating(rowsFor(2025), 8, 'Pink Salmon'), S.EXCELLENT);
});

test('a site with no guidance is unrated gray, and a species the guide does not list is gray too', () => {
  const prep = S.prepare(T, 2026);
  const gray = T.sites.find(s => s.guide === null);
  assert.deepEqual(S.siteView(prep, gray, 10, null), { r: 'unrated', rating: null, closure: false });
  const pier = T.sites.find(s => s.kind === 'pier');
  assert.equal(S.siteView(prep, pier, 10, 'Rainbow Trout').r, 'unrated');
  assert.notEqual(S.siteView(prep, pier, 10, null).r, 'unrated');
});

test('colour tokens are exactly the page four plus gray', () => {
  assert.deepEqual(S.TOKEN, ['slow', 'fair', 'good', 'prime']);
  assert.deepEqual(Object.keys(S.LABEL).sort(), ['fair', 'good', 'prime', 'slow', 'unrated']);
});
