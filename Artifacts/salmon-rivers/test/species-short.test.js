'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const S = require('../species-short.js');
const dir = path.join(__dirname, '..');

const names = [...new Set((fs.readFileSync(path.join(dir, 'typical.js'), 'utf8').match(/"species":"([^"]+)"/g) || []).map(x => x.slice(11, -1)))];

test('species-short: the species list was read (a check that cannot fail is not a check)', () => {
  assert.ok(names.length >= 20, `only ${names.length} species found in typical.js`);
  assert.ok(names.some(n => n.length > S.MAX), 'no species over the limit: the test below would pass for any table');
});

test('species-short: every species over the limit has a short form no longer than the limit', () => {
  for (const n of names.filter(n => n.length > S.MAX)) {
    const s = S.short(n);
    assert.notStrictEqual(s, n, `"${n}" is longer than ${S.MAX} characters and has no short form`);
    assert.ok(s.length <= S.MAX, `"${s}" (short form of "${n}") is longer than ${S.MAX}`);
  }
});

test('species-short: short forms are unique and every key is a real species name', () => {
  const vals = Object.values(S.SHORT);
  assert.strictEqual(new Set(vals).size, vals.length);
  for (const k of Object.keys(S.SHORT)) assert.ok(names.includes(k), `"${k}" is not a species in typical.js`);
});

test('species-short: a name without an entry comes back unchanged', () => {
  assert.strictEqual(S.short('Coho Salmon'), 'Coho Salmon');
  assert.strictEqual(S.short('constructor'), 'constructor');
});
