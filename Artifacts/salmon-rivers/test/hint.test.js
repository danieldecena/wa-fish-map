const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const S = require('../season.js');
const T = require('../typical.js');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const rep = (r, n) => Array(n).fill(r);

test('the hint needs more than 80 percent of the rated sites to agree', () => {
  assert.equal(S.SAME_SHARE, 0.8);
  assert.equal(S.mostlySame(rep('good', 81).concat(rep('fair', 19))), true);
  assert.equal(S.mostlySame(rep('good', 80).concat(rep('fair', 20))), false, 'exactly 80 percent is not more than 80 percent');
  assert.equal(S.mostlySame(rep('good', 50).concat(rep('fair', 50))), false);
  assert.equal(S.mostlySame(rep('slow', 100)), true);
});

test('unrated sites are not ratings: they neither make nor break the agreement', () => {
  assert.equal(S.mostlySame(rep('good', 5).concat(rep('unrated', 500))), false, 'five rated sites among 500 unrated is too few to say most');
  assert.equal(S.mostlySame(rep('good', 18).concat(rep('fair', 2), rep('unrated', 500))), true, 'unrated sites do not dilute the share');
  assert.equal(S.mostlySame(rep('unrated', 100)), false, 'nothing rated, nothing to agree on');
  assert.equal(S.agreement(rep('unrated', 3)), null);
  assert.deepEqual(S.agreement(['good', 'good', 'fair', 'unrated']), { r: 'good', share: 2 / 3, n: 3 });
});

test('too few rated sites is not "most"', () => {
  assert.equal(S.SAME_MIN, 10);
  assert.equal(S.mostlySame(rep('good', 9)), false);
  assert.equal(S.mostlySame(rep('good', 10)), true);
});

test('computed from the data: October All species fires, July All species does not', () => {
  const share = (month, species) => {
    const prep = S.prepare(T, 2026);
    return T.sites.map(s => S.siteView(prep, s, month, species).r);
  };
  const oct = S.agreement(share(10, null));
  assert.ok(oct.n > 500, `${oct.n} rated sites`);
  assert.equal(S.mostlySame(share(10, null)), true, `October: ${oct.r} ${(oct.share * 100).toFixed(0)}%`);
  const jul = S.agreement(share(7, null));
  assert.equal(S.mostlySame(share(7, null)), false, `July: ${jul.r} ${(jul.share * 100).toFixed(0)}%`);
  // The bundled data decides it: nothing about October or "good" is written into the page.
  assert.doesNotMatch(html, /mostlySame\([^)]*(10|'good')/);
});

test('the sentence is defined once, shown only in Typical season and All species, and never stored as visible', () => {
  const line = 'Most sites rate the same this month. Pick a species to see differences.';
  assert.equal(html.split(line).length - 1, 1, 'the sentence appears once, verbatim');
  assert.match(html, /<div class="hint" id="hint" hidden><\/div>/, 'hidden until the data says so');
  assert.match(html, /var showHint = typ && species === null && Season\.mostlySame\(pts\.map\(function \(q\) \{ return q\.vw\.r; \}\)\);/);
  assert.match(html, /if \(hintEl\.hidden === showHint\) hintEl\.hidden = !showHint;/);
});
