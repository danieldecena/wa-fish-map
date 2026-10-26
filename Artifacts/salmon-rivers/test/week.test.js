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
  assert.equal(Week.build(FY, R0, RL0, '2026-11-01').open.map(s => s.id).join(), 'later,future');
  assert.equal(Week.build(FY, R0, RL0, '2026-10-24').open.find(s => s.id === 'a').soon, true);   // 7 days exactly
  assert.equal(Week.build(FY, R0, RL0, '2026-10-23').open.find(s => s.id === 'a').soon, false);  // 8 days
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

test('build: latestReport is the newest asOf across sites, null when there are none', () => {
  assert.equal(Week.build(FY0, R0, RL0, '2026-10-26').latestReport, null);
  const R1 = Object.assign({}, R0, { SITES: [{ id: 'a', name: 'A', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-10' } } }, { id: 'b', name: 'B', reports: { 'Coho Salmon': { r: 'fair', asOf: '2026-10-17' } } }], latestReport: Reports.latestReport });
  assert.equal(Week.build(FY0, R1, RL0, '2026-10-26').latestReport, '2026-10-17');
});

test('render: empty Reported row names the newest report and links to the map; with no reports at all it says Nothing this week', () => {
  const R1 = Object.assign({}, R0, { SITES: [{ id: 'b', name: 'B', reports: { 'Coho Salmon': { r: 'fair', asOf: '2026-10-17' } } }], latestReport: Reports.latestReport });
  const res = Week.build(FY0, R1, RL0, '2026-10-26');
  assert.deepEqual(res.reported, []);
  const rep = Week.render(res, fakeDoc()).querySelectorAll('section')[1];
  assert.ok(rep.textContent.includes('No reports from the last 7 days. Newest: ' + Week.fmt('2026-10-17') + '.'));
  const a = rep.querySelector('a');
  assert.equal(a.attrs.href, '../index.html?mode=reports');
  assert.equal(a.textContent, 'See all reports on the map');
  const none = Week.render(Week.build(FY0, R0, RL0, '2026-10-26'), fakeDoc()).querySelectorAll('section')[1];
  assert.ok(none.textContent.includes('Nothing this week')); assert.equal(none.querySelector('a'), null);
});

test('render: five sections, empty ones say Nothing this week', () => {
  const el = Week.render(Week.build(FY0, R0, RL0, '2026-10-26'), fakeDoc());
  const ids = el.querySelectorAll('section').map(s => s.id);
  assert.deepEqual(ids, ['open', 'reported', 'rules', 'upcoming', 'spots']);
  assert.ok(el.querySelector('section').textContent.includes('Nothing this week'));
  assert.ok(el.querySelectorAll('section')[4].textContent.includes('Three Friends Fishing Hole'));
});

test('render: open-now and coming-up seasons link to their Year row; milestones and unrelated rows stay plain text', () => {
  const FY = { updated: '', seasons: [ season('skagit-coho', '2026-10-01', '2026-10-31', { name: 'Skagit coho' }), season('chum', '2026-11-01', '2026-11-30', { name: 'Chum' }) ],
    milestones: [ { date: '2026-10-28', label: 'Rule change', note: 'n' } ] };
  const el = Week.render(Week.build(FY, R0, RL0, '2026-10-26'), fakeDoc());
  const [open, , , upcoming] = el.querySelectorAll('section');
  const hrefs = sec => sec.querySelectorAll('a').map(a => a.attrs.href + '|' + a.textContent);
  assert.ok(hrefs(open).includes('../year/index.html#skagit-coho|Skagit coho'));
  assert.ok(hrefs(upcoming).includes('../year/index.html#chum|Chum'));
  assert.ok(!hrefs(upcoming).some(h => h.endsWith('|Rule change')), 'a milestone has no Year row to open');
  assert.ok(upcoming.querySelectorAll('.nm').some(n => n.textContent === 'Rule change'));
});

test('render: ends-soon chip, rating badge token, rule link', () => {
  const FY = { updated: '', milestones: [], seasons: [ season('skagit-coho', '2026-10-01', '2026-10-31', { name: 'Skagit coho' }) ] };
  const R = Object.assign({}, R0, { SITES: [{ id: 'g', name: 'G River', sub: 's', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-26', d: 'y' } } }] });
  const RL = { CHECKED: '2026-10-20', RULES: [{ rivers: ['Hoh River'], published: '2026-10-16', d: 'closing', url: 'https://wdfw.wa.gov/x' }] };
  const el = Week.render(Week.build(FY, R, RL, '2026-10-26'), fakeDoc());
  assert.ok(el.querySelector('.soon'), 'ends-soon chip rendered');
  assert.equal(el.querySelector('.soon').textContent, 'Ends soon · ends Oct 31 · 5 days');
  const badge = el.querySelector('.badge');
  assert.equal(badge.attrs.style, '--c:var(--good)');
  assert.equal(badge.textContent, 'Good');
  const rule = el.querySelectorAll('a').find(a => a.attrs.href === 'https://wdfw.wa.gov/x');
  assert.equal(rule.textContent, 'Read the rule');
  assert.equal(rule.attrs['aria-label'], 'Read the WDFW rule for Hoh River');
  assert.ok(el.querySelectorAll('a').some(a => a.attrs.href === '../index.html?mode=reports&river=g'));
});

test('render: season ending today says "ends today"; flavor label; rules Checked date', () => {
  const FY = { updated: '', milestones: [], seasons: [ season('e', '2026-10-01', '2026-10-26', { name: 'Ends' }) ] };
  const RL = { CHECKED: '2026-10-20', RULES: [] };
  const res = Week.build(FY, R0, RL, '2026-10-26');
  assert.equal(res.rulesChecked, '2026-10-20');
  const el = Week.render(res, fakeDoc());
  const chips = el.querySelectorAll('.chip').map(c => c.textContent);
  assert.ok(chips.includes('Ends soon · ends today'), 'ends today chip: ' + chips);
  assert.ok(chips.includes('Taste #2 of 5'), 'flavor label: ' + chips);
  assert.equal(el.querySelectorAll('.chip').find(c => c.textContent === 'Taste #2 of 5').attrs.title, 'Taste order, richest first (Washington Fishing Year)');
  assert.ok(el.querySelectorAll('section')[2].textContent.includes('Checked Oct 20.'));
  const noCk = Week.render(Week.build(FY, R0, { RULES: [] }, '2026-10-26'), fakeDoc());
  assert.ok(!noCk.querySelectorAll('section')[2].textContent.includes('Checked'));
});

// ---- boundaries and hardening ----

test('boundaries: season starting today is open and not upcoming; ending today is open; milestone dated today is not upcoming; rule published today counts', () => {
  const FY = { updated: '', seasons: [ season('starts', '2026-10-26', '2026-11-30'), season('ends', '2026-10-01', '2026-10-26'), season('tomorrow', '2026-10-27', '2026-11-30') ],
    milestones: [ { date: '2026-10-26', label: 'today-m', note: '' }, { date: '2026-10-27', label: 'next-m', note: '' } ] };
  const RL = { RULES: [ { rivers: ['T'], published: '2026-10-26', d: 'today', url: 'u' }, { rivers: ['F'], published: '2026-10-27', d: 'future', url: 'u' }, { rivers: ['E'], published: '2026-10-12', d: 'edge', url: 'u' } ] };
  const r = Week.build(FY, R0, RL, '2026-10-26');
  assert.deepEqual(r.open.map(s => s.id), ['ends', 'starts']);
  assert.deepEqual(r.upcoming.map(u => u.label), ['next-m', 'tomorrow']);
  assert.deepEqual(r.rules.map(x => x.d), ['today', 'edge'], 'a rule dated after today is not shown yet');
});

test('tie-breaks: same end date sorts by name; same upcoming date sorts by label', () => {
  const FY = { updated: '', milestones: [ { date: '2026-11-02', label: 'b-ms', note: '' } ], seasons: [
    season('x', '2026-10-01', '2026-11-10', { name: 'Zeta' }), season('y', '2026-10-01', '2026-11-10', { name: 'Alpha' }),
    season('f', '2026-11-02', '2026-12-01', { name: 'a-season' }) ] };
  const r = Week.build(FY, R0, RL0, '2026-10-26');
  assert.deepEqual(r.open.map(s => s.name), ['Alpha', 'Zeta']);
  assert.deepEqual(r.upcoming.map(u => u.label), ['a-season', 'b-ms']);
});

test('upcoming: a year file without seasons does not throw', () => {
  assert.deepEqual(Week.build({ updated: '', milestones: [{ date: '2026-11-02', label: 'm' }] }, R0, RL0, '2026-10-26').upcoming.map(u => u.label), ['m']);
  assert.deepEqual(Week.build({ updated: '' }, R0, RL0, '2026-10-26').upcoming, []);
});

test('reported: published == today is fresh; a report dated after today is not; the 7th day back is fresh and the 8th is not', () => {
  const site = (id, asOf) => ({ id, name: id, sub: '', reports: { 'Coho Salmon': { r: 'good', asOf, d: 'x' } } });
  const R = Object.assign({}, R0, { SITES: [ site('today', '2026-10-26'), site('future', '2026-10-27'), site('d7', '2026-10-19'), site('d8', '2026-10-18') ] });
  assert.deepEqual(Week.build(FY0, R, RL0, '2026-10-26').reported.map(s => s.id).sort(), ['d7', 'today']);
});

test('reported: an unknown rating reads "No report" and never "undefined"; release-only suffix is added', () => {
  const R = Object.assign({}, R0, { SITES: [ { id: 'q', name: 'Q', sub: '', reports: { 'Coho Salmon': { r: 'mystery', asOf: '2026-10-26', d: 'x' }, 'Chinook Salmon': { r: 'unrated', release: true, asOf: '2026-10-26', d: 'y' } } } ] });
  const res = Week.build(FY0, R, RL0, '2026-10-26');
  const labels = res.reported[0].species.map(s => s.label);
  assert.ok(labels.includes('No report'), labels.join());
  assert.ok(labels.includes('No report, release only'), labels.join());
  assert.ok(!labels.some(l => /undefined/.test(l)));
  const badges = Week.render(res, fakeDoc()).querySelectorAll('.badge');
  assert.ok(badges.every(b => /^--c:var\(--(prime|good|fair|slow|unrated)\)$/.test(b.attrs.style)), badges.map(b => b.attrs.style).join());
});

test('render: release-only label shows in the badge text', () => {
  const R = Object.assign({}, R0, { SITES: [ { id: 'r', name: 'R', sub: '', reports: { 'Coho Salmon': { r: 'prime', release: true, asOf: '2026-10-26', d: 'z' } } } ] });
  const el = Week.render(Week.build(FY0, R, RL0, '2026-10-26'), fakeDoc());
  assert.equal(el.querySelector('.badge').textContent, 'Excellent, release only');
});

test('render: Spots with an empty list says Nothing this week', () => {
  const res = Week.build(FY0, R0, RL0, '2026-10-26'); res.spots = [];
  const spots = Week.render(res, fakeDoc()).querySelectorAll('section')[4];
  assert.equal(spots.id, 'spots');
  assert.ok(spots.textContent.includes('Nothing this week'));
});

test('render: ends-soon chip says "Ends soon" in words; a season not ending soon has a plain date line', () => {
  const FY = { updated: '', milestones: [], seasons: [ season('a', '2026-10-01', '2026-10-31'), season('b', '2026-10-01', '2026-12-31') ] };
  const el = Week.render(Week.build(FY, R0, RL0, '2026-10-26'), fakeDoc());
  assert.deepEqual(el.querySelectorAll('.soon').map(c => c.textContent), ['Ends soon · ends Oct 31 · 5 days']);
  assert.ok(el.querySelectorAll('.dt').some(c => c.textContent === 'ends Dec 31 · 66 days'));
});

test('render: rule link names the rivers for screen readers (one aria-label per link)', () => {
  const RL = { RULES: [ { rivers: ['Hoh River', 'Quillayute River'], published: '2026-10-25', d: 'closed', url: 'https://wdfw.wa.gov/a' }, { rivers: ['Skagit River'], published: '2026-10-24', d: 'open', url: 'https://wdfw.wa.gov/b' } ] };
  const links = Week.render(Week.build(FY0, R0, RL, '2026-10-26'), fakeDoc()).querySelectorAll('a').filter(a => a.textContent === 'Read the rule');
  assert.deepEqual(links.map(a => a.attrs['aria-label']), ['Read the WDFW rule for Hoh River, Quillayute River', 'Read the WDFW rule for Skagit River']);
});

test('render: markup in data is text, never elements (textContent only)', () => {
  const evil = '<img src=x onerror=alert(1)>';
  const FY = { updated: '', milestones: [], seasons: [ season('e', '2026-10-01', '2026-11-30', { name: evil, where: evil, note: evil }) ] };
  const RL = { RULES: [ { rivers: [evil], published: '2026-10-25', d: evil, url: 'https://wdfw.wa.gov/a' } ] };
  const R = Object.assign({}, R0, { SITES: [ { id: 'e', name: evil, sub: evil, reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-26', d: evil } } } ] });
  const el = Week.render(Week.build(FY, R, RL, '2026-10-26'), fakeDoc());
  assert.equal(el.querySelectorAll('img').length, 0);
  assert.ok(el.textContent.includes(evil));
  assert.ok(!/innerHTML|insertAdjacentHTML|document\.write/.test(require('node:fs').readFileSync(require('node:path').join(__dirname, '..', 'week.js'), 'utf8')));
});
