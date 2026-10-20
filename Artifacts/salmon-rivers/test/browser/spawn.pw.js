// Spawning mode, the app tab bar and the merged app layout, over HTTP.
// From the repo root: NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/spawn.pw.js
// Builds test/browser/site/ the way the artifact is laid out (build-site.js: index.html wrapped in a publisher skeleton, the Map's
// scripts beside it, year/, spots/ and counts/), serves it on a local port and drives it in Chromium.
const { chromium } = require('playwright');
const http = require('http');
const path = require('path');
const fs = require('fs');

const site = require('./build-site')();
const shots = path.join(__dirname, 'shots');
fs.mkdirSync(shots, { recursive: true });

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml' };
const requests = [];
const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  requests.push(u.pathname);
  let f = path.join(site, decodeURIComponent(u.pathname));
  if (!f.startsWith(site)) { res.writeHead(403); res.end(); return; }
  if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
  if (!fs.existsSync(f)) { res.writeHead(404); res.end('not found'); return; }
  res.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

let fails = 0, passes = 0;
function check(ok, msg) { if (ok) { passes++; console.log('ok   ' + msg); } else { fails++; console.log('FAIL ' + msg); } }

const state = p => p.evaluate(() => ({
  ttl: document.querySelector('#ttl').textContent,
  sub: document.querySelector('#sub').textContent,
  legt: document.querySelector('#legt').textContent,
  legl: document.querySelector('#legl').innerText,
  legf: document.querySelector('#legf').textContent,
  summary: document.querySelector('#summary').textContent,
  spawnShown: !document.querySelector('#spawn').hidden && document.querySelector('#spawn').offsetParent !== null,
  list: document.querySelector('#listbtn').hidden ? null : document.querySelector('#listbtn').textContent,
  checked: [...document.querySelectorAll('#modes button')].filter(b => b.getAttribute('aria-checked') === 'true').map(b => b.dataset.mode).join(),
  month: (document.querySelector('#year [aria-checked="true"]') || {}).textContent || null,
  pins: [...document.querySelectorAll('#over .pin[data-id]')].filter(n => n.style.display !== 'none').length +
    [...document.querySelectorAll('#over .cluster')].filter(c => c.style.display !== 'none').reduce((a, c) => a + c.__members.length, 0),
  overflow: document.documentElement.scrollWidth - innerWidth
}));
// Visible single pins, their colour token and the label drawn for each.
const pinInfo = p => p.evaluate(() => {
  const pins = [...document.querySelectorAll('#over .pin[data-id]')].filter(n => n.style.display !== 'none');
  const labs = [...document.querySelectorAll('#over > text.lab')].filter(t => t.style.display !== 'none' && t.textContent && !t.closest('.lm') && t.parentNode.id === 'over');
  return { n: pins.length, colors: pins.map(n => n.style.getPropertyValue('--rc')), ladders: pins.filter(n => n.classList.contains('ladder')).length, labels: labs.map(t => t.textContent) };
});
const sheet = p => p.evaluate(() => ({ open: document.querySelector('#sheet').classList.contains('open'), title: document.querySelector('#stitle').textContent, body: document.querySelector('#sbody').innerText }));
const WORDS = '(Peak|Active|Starting|Ending|Starting or ending|Quiet|Not listed|Species not listed)';

(async () => {
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = 'http://127.0.0.1:' + server.address().port + '/';
  const b = await chromium.launch();
  const errs = [], offsite = [];
  for (const [tag, w, h, scheme] of [['desk', 1440, 900, 'light'], ['phone', 390, 844, 'dark']]) {
    const ctx = await b.newContext({ viewport: { width: w, height: h }, colorScheme: scheme, hasTouch: tag === 'phone' });
    const p = await ctx.newPage();
    p.on('pageerror', e => errs.push(tag + ' ' + p.url() + ': ' + e.message));
    p.on('console', m => { if (m.type() === 'error') errs.push(tag + ' ' + p.url() + ': ' + m.text()); });
    p.on('request', r => { if (!r.url().startsWith(base) && !r.url().startsWith('data:')) offsite.push(r.url()); });
    await p.goto(base + 'index.html?today=2026-10-20'); await p.waitForTimeout(600);
    await p.evaluate(() => { try { localStorage.removeItem('wafish.me'); } catch (e) {} });
    await p.reload(); await p.waitForTimeout(600);

    // ---- tab bar and mode switch ----
    const tb = await p.evaluate(() => {
      const nav = document.querySelector('nav.apptabs'), r = nav.getBoundingClientRect(), bar = document.querySelector('#bar').getBoundingClientRect();
      const cur = nav.querySelector('[aria-current="page"]');
      const seg = getComputedStyle(cur, '::before').backgroundColor;
      const modes = [...document.querySelectorAll('#modes button')].map(x => x.getBoundingClientRect());
      const on = document.querySelector('#modes [aria-checked="true"]');
      return { top: r.top, h: r.height, w: r.width, cur: cur.textContent, links: [...nav.querySelectorAll('a')].map(a => a.getAttribute('href')), barTop: bar.top, seg,
        modeH: modes.map(m => m.height), modeRows: new Set(modes.map(m => Math.round(m.top))).size, modeTrack: getComputedStyle(document.querySelector('#modes')).backgroundColor,
        modeOn: getComputedStyle(on, '::before').backgroundColor, modeOnInk: getComputedStyle(on).color, modeOffInk: getComputedStyle(document.querySelector('#modes [aria-checked="false"]')).color,
        mapTop: document.querySelector('#map').getBoundingClientRect().top, fixed: getComputedStyle(nav).position };
    });
    check(tb.top === 0 && tb.h === 56 && tb.w === w && tb.fixed === 'fixed', tag + ': tab bar fixed full width at the top, 56 px ' + JSON.stringify([tb.top, tb.h, tb.w, tb.fixed]));
    check(tb.cur === 'Map' && tb.links.join() === 'index.html,year/index.html,spots/index.html,counts/index.html', tag + ': Map is current; links ' + tb.links.join());
    check(tb.barTop >= tb.top + tb.h, tag + ': the card starts below the tab bar (' + tb.barTop + ')');
    check(tb.mapTop === 0, tag + ': the map stays full bleed under the tab bar');
    check(tb.seg === (scheme === 'dark' ? 'rgb(99, 99, 102)' : 'rgb(255, 255, 255)'), tag + ': tab bar chosen segment ' + tb.seg);
    check(tb.modeH.every(x => x >= 44) && tb.modeRows === 1, tag + ': three modes on one row, 44 px targets ' + tb.modeH.join(','));
    check(tb.modeTrack === (scheme === 'dark' ? 'rgb(44, 44, 46)' : 'rgb(229, 229, 234)') && tb.modeOn === (scheme === 'dark' ? 'rgb(99, 99, 102)' : 'rgb(255, 255, 255)'), tag + ': App Kit segmented control track ' + tb.modeTrack + ', chosen ' + tb.modeOn);
    check(tb.modeOnInk === (scheme === 'dark' ? 'rgb(245, 245, 247)' : 'rgb(29, 29, 31)') && tb.modeOffInk === (scheme === 'dark' ? 'rgb(152, 152, 157)' : 'rgb(99, 99, 102)'), tag + ': ink vs ink-soft ' + tb.modeOnInk + ' / ' + tb.modeOffInk);
    await p.screenshot({ path: path.join(shots, `sp-${tag}-reports.png`) });
    await p.screenshot({ path: path.join(shots, `sp-${tag}-tabbar.png`), clip: { x: 0, y: 0, width: w, height: 260 } });
    let st = await state(p);
    check(st.checked === 'reports' && st.list === 'Rivers' && !st.spawnShown && st.pins === 8 && st.overflow <= 0, tag + ': Recent reports unchanged: 8 pins, Rivers, no ribbon ' + JSON.stringify([st.checked, st.list, st.pins]));

    // ---- Spawning ----
    await p.click('[data-mode="spawning"]'); await p.waitForTimeout(700);
    st = await state(p);
    check(st.checked === 'spawning' && st.ttl === 'Where salmon spawn' && st.spawnShown && st.list === 'Sites', tag + ': Spawning mode: title, ribbon, Sites ' + JSON.stringify([st.ttl, st.list]));
    check(st.month === 'Oct' && /^\d+ at peak and \d+ active in October\.$/.test(st.summary) && st.legt === 'Spawning, October' && /75 WDFW salmon viewing sites · October/.test(st.sub), tag + ': October by default: ' + st.summary);
    check(['Peak', 'Active', 'Starting or ending', 'Quiet', 'Species not listed', 'Dashed: fish ladder, passing not spawning', 'Count: several sites'].every(x => st.legl.includes(x)) && /Typical timing, not a guarantee and not regulation/.test(st.legf), tag + ': Spawning legend');
    check(st.overflow <= 0, tag + ': no horizontal overflow in Spawning');
    let pi = await pinInfo(p);
    const tokens = pi.colors.map(c => c.replace(/var\(--|\)/g, ''));
    check(pi.n > 5 && tokens.every(t => ['prime', 'good', 'fair', 'slow', 'unrated'].includes(t)), tag + ': ' + pi.n + ' spawning pins in rating tokens');
    check(pi.labels.length > 0 && pi.labels.every(l => new RegExp('( · ' + WORDS + '|^' + WORDS + ')$').test(l)), tag + ': every pin label carries its status word (' + pi.labels.length + ', e.g. ' + pi.labels.slice(0, 3).join(' | ') + ')');
    const clusters = await p.evaluate(() => [...document.querySelectorAll('#over .cluster')].filter(c => c.style.display !== 'none').map(c => ({ neutral: c.classList.contains('neutral'), rc: c.style.getPropertyValue('--rc'), ids: c.getAttribute('data-cluster'), ring: !!c.querySelector('.ring') })));
    check(clusters.every(c => !c.ring), tag + ': no ring groups');
    // A group is coloured only when every member has that status.
    const clusterOk = await p.evaluate(() => {
      const out = [];
      for (const c of document.querySelectorAll('#over .cluster')) {
        if (c.style.display === 'none') continue;
        const toks = c.__members.map(m => m.vw.r);
        const same = toks.every(t => t === toks[0]);
        out.push(same ? (!c.classList.contains('neutral') && c.style.getPropertyValue('--rc') === 'var(--' + toks[0] + ')') : c.classList.contains('neutral'));
      }
      return out;
    });
    check(clusterOk.every(Boolean), tag + ': ' + clusterOk.length + ' groups follow Cluster.look (coloured only when unanimous)');
    await p.screenshot({ path: path.join(shots, `sp-${tag}-spawning.png`) });

    // Ribbon: tap a month.
    const beforeColors = (await pinInfo(p)).colors.join();
    await p.click('#year button:nth-child(4)'); await p.waitForTimeout(250);
    st = await state(p);
    check(st.month === 'Apr' && / in April\.$/.test(st.summary) && st.legt === 'Spawning, April', tag + ': tapping Apr selects April: ' + st.summary);
    check((await pinInfo(p)).colors.join() !== beforeColors, tag + ': pin colours change with the month');
    // Ribbon: drag to scrub from Jan to Dec.
    const rb = await p.evaluate(() => { const r = document.querySelector('#year').getBoundingClientRect(); return { x: r.left, y: r.top + r.height / 2, w: r.width }; });
    const seen = [];
    await p.mouse.move(rb.x + rb.w / 24, rb.y); await p.mouse.down();
    for (let k = 1; k <= 12; k++) { await p.mouse.move(rb.x + rb.w * (k - 0.5) / 12, rb.y, { steps: 3 }); seen.push((await state(p)).month); }
    await p.mouse.up(); await p.waitForTimeout(150);
    st = await state(p);
    check(st.month === 'Dec' && / in December\.$/.test(st.summary) && new Set(seen).size >= 10, tag + ': scrubbing sweeps the months (' + seen.join(' ') + ')');
    check(!(await sheet(p)).open && (await p.evaluate(() => document.querySelector('#map').classList.contains('drag'))) === false, tag + ': the scrub did not pan the map or open anything');
    // Ribbon: arrow keys.
    await p.focus('#year [aria-checked="true"]'); await p.keyboard.press('ArrowRight'); await p.waitForTimeout(120);
    st = await state(p);
    const focused = await p.evaluate(() => document.activeElement.getAttribute('aria-checked'));
    check(st.month === 'Jan' && focused === 'true', tag + ': ArrowRight wraps December to January and keeps focus on the chosen month');
    await p.keyboard.press('ArrowLeft'); await p.keyboard.press('ArrowLeft'); await p.waitForTimeout(120);
    check((await state(p)).month === 'Nov', tag + ': ArrowLeft steps back');
    const barH = await p.evaluate(() => document.querySelector('#year .stack').getBoundingClientRect().height);
    check(tag === 'phone' ? barH <= 22 : barH <= 30, tag + ': ribbon bars ' + barH + ' px');
    await p.screenshot({ path: path.join(shots, `sp-${tag}-november.png`) });

    // Species: the one dropdown, All + the five families.
    await p.click('#spbtn'); await p.waitForTimeout(120);
    const chips = await p.evaluate(() => [...document.querySelectorAll('#sppanel button')].map(x => x.textContent));
    check(chips.join('|') === 'All species|Chinook Salmon|Coho Salmon|Chum Salmon|Pink Salmon|Sockeye Salmon', tag + ': species list ' + chips.join('|'));
    await p.click('#sppanel [data-species="Pink Salmon"]'); await p.waitForTimeout(200);
    st = await state(p);
    check(/^Pink salmon return in odd years\. None are expected in 2026; the next run is 2027\.$/.test(st.summary), tag + ': pink in an even year: ' + st.summary);
    // Sites that list no species stay on the map in gray (WDFW does not say whether pink run there); every pink site is quiet.
    const pink = (await pinInfo(p)).colors;
    check(pink.includes('var(--slow)') && pink.every(c => c === 'var(--slow)' || c === 'var(--unrated)'), tag + ': every pink site is quiet in 2026 (' + [...new Set(pink)].join() + ')');
    await p.click('#spbtn'); await p.click('#sppanel [data-species="Coho Salmon"]'); await p.waitForTimeout(200);
    st = await state(p);
    check(/, of \d+ Coho Salmon sites\.$/.test(st.summary) && (await p.evaluate(() => document.querySelector('#spbtn').textContent)) === 'Species: Coho Salmon', tag + ': Coho: ' + st.summary);
    await p.click('#spbtn'); await p.click('#sppanel [data-species=""]'); await p.waitForTimeout(200);

    // Sites list and a spawning sheet (a fish ladder).
    await p.click('#listbtn'); await p.waitForTimeout(450);
    let sh = await sheet(p);
    check(sh.open && sh.title === 'Sites in November' && /Peak \d+/.test(sh.body) && /WDFW Salmon Viewing list/.test(sh.body), tag + ': Sites list, grouped by status');
    await p.click('#sbody .lrow[data-id="ballard"]'); await p.waitForTimeout(500);
    sh = await sheet(p);
    check(sh.open && sh.title === 'Ballard Locks Fish Ladder' && /Fish ladder · Lake Washington Ship Canal · King County/.test(sh.body), tag + ': ladder sheet header');
    check(/In November/.test(sh.body) && /Through the year/.test(sh.body) && /don’t spawn here/.test(sh.body) && /Before you go/.test(sh.body) && /off the gravel/.test(sh.body) && /Typical timing, not a guarantee and not regulation/.test(sh.body) && /Species and months come from the site’s own visitor information\./.test(sh.body), tag + ': sheet sections');
    const cal = await p.evaluate(() => {
      const t = document.querySelector('#sbody table.cal');
      return { cols: t.querySelectorAll('thead th').length, rows: t.querySelectorAll('tbody tr').length, cur: t.querySelectorAll('td.cur').length, curHead: t.querySelector('thead th.cur').textContent, filled: t.querySelectorAll('td.b, td.g, td.f').length,
        links: [...document.querySelectorAll('#sbody a')].map(a => [a.textContent, a.getAttribute('href'), a.target]) };
    });
    check(cal.cols === 13 && cal.rows === 3 && cal.cur === 3 && cal.curHead === 'N' && cal.filled > 0, tag + ': 12-month grid with the chosen month outlined ' + JSON.stringify([cal.cols, cal.rows, cal.cur, cal.curHead, cal.filled]));
    const dir = cal.links.find(l => l[0] === 'Directions'), info = cal.links.find(l => l[0] === 'Site info'), wdfw = cal.links.find(l => l[0] === 'WDFW Salmon Viewing list');
    check(dir && dir[1] === 'https://maps.apple.com/?q=Ballard%20Locks%20Fish%20Ladder&sll=47.6656,-122.3975' && info && /^https:\/\//.test(info[1]) && wdfw && wdfw[1] === 'https://wdfw.wa.gov/places-to-go/salmon-viewing', tag + ': Directions, Site info and WDFW links ' + (dir || [])[1]);
    await p.screenshot({ path: path.join(shots, `sp-${tag}-sheet-ballard.png`) });
    await p.evaluate(() => document.querySelector('#sbody').scrollTop = 99999); await p.waitForTimeout(150);
    await p.screenshot({ path: path.join(shots, `sp-${tag}-sheet-ballard-bottom.png`) });
    if (tag === 'desk') {
      // The ribbon stays usable with the inspector open and refills it.
      await p.click('#year button:nth-child(7)'); await p.waitForTimeout(250);
      sh = await sheet(p);
      check(/In July/.test(sh.body) && sh.title === 'Ballard Locks Fish Ladder', tag + ': changing the month refills the open sheet');
      await p.screenshot({ path: path.join(shots, `sp-${tag}-sheet-july.png`) });
    }
    await p.click('#sdone'); await p.waitForTimeout(300);

    // A creek with a run label, reached through its pin.
    await p.evaluate(() => { const n = [...document.querySelectorAll('#over .pin[data-id]')].find(x => x.style.display !== 'none' && x.getAttribute('data-id')); n.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); });
    await p.waitForTimeout(500);
    sh = await sheet(p);
    check(sh.open && /Before you go/.test(sh.body), tag + ': a pin opens its spawning sheet (' + sh.title + ')');
    await p.keyboard.press('Escape'); await p.waitForTimeout(300);
    check(!(await sheet(p)).open, tag + ': Escape closes the spawning sheet');

    // My location: distances and Nearest first.
    await p.click('#mebtn'); await p.click('#mepanel [data-town="0"]'); await p.waitForTimeout(250);
    await p.click('#listbtn'); await p.waitForTimeout(400);
    check(await p.evaluate(() => document.querySelector('#sbody [data-sort="best"]').getAttribute('aria-checked') === 'true'), tag + ': Sites list defaults to status order');
    await p.click('#sbody [data-sort="near"]'); await p.waitForTimeout(200);
    const rows = await p.evaluate(() => [...document.querySelectorAll('#sbody .lrow .dt')].map(x => x.textContent));
    const miles = rows.map(r => { const m = /· (under 1|[\d,]+) mi$/.exec(r); return m ? (m[1] === 'under 1' ? 0 : +m[1].replace(',', '')) : NaN; });
    check(rows.length === 75 && miles.every(Number.isFinite) && miles.every((m, i) => i === 0 || m >= miles[i - 1]), tag + ': Nearest first: 75 rows, ascending (' + miles.slice(0, 6).join(',') + '…)');
    check(/Nearest first 75/.test((await sheet(p)).body) && /nearest first by straight-line distance from Seattle/.test((await sheet(p)).body), tag + ': Nearest first heading and lede');
    await p.screenshot({ path: path.join(shots, `sp-${tag}-nearest.png`) });
    await p.click('#sbody .lrow'); await p.waitForTimeout(450);
    check(/About [\d,]+ mi from you|Less than 1 mi from you/.test((await sheet(p)).body), tag + ': spawning sheet shows distance');
    await p.click('#sdone'); await p.waitForTimeout(300);
    await p.click('#mebtn'); await p.click('#mepanel [data-me="clear"]'); await p.keyboard.press('Escape'); await p.waitForTimeout(150);

    // Rivers are not tappable in Spawning.
    check(await p.evaluate(() => getComputedStyle(document.querySelector('#rtap')).display === 'none' && document.querySelector('#rhint').hidden), tag + ': #rtap and the river hint are Recent reports only');

    // Typical season: no list button, no ribbon. Back to Recent reports.
    await p.click('[data-mode="typical"]'); await p.waitForTimeout(700);
    st = await state(p);
    check(st.checked === 'typical' && st.list === null && !st.spawnShown && st.ttl === 'Typical season' && !/Spawning/.test(st.legt) && !st.legl.includes('Dashed: fish ladder'), tag + ': Typical season keeps its own chrome');
    await p.click('[data-mode="reports"]'); await p.waitForTimeout(700);
    st = await state(p);
    check(st.checked === 'reports' && st.list === 'Rivers' && !st.spawnShown && st.ttl === 'Salmon this month' && st.legt === 'Recent catch reports' && st.pins === 8, tag + ': back to Recent reports');
    // The footer's Year link stays inside the app.
    await p.click('#listbtn'); await p.waitForTimeout(400);
    const ylink = await p.evaluate(() => { const a = [...document.querySelectorAll('#sbody a')].find(x => /Washington Fishing Year/.test(x.textContent)); return a && [a.getAttribute('href'), a.target]; });
    check(ylink && ylink[0] === 'year/index.html' && ylink[1] === '', tag + ': footer Year link ' + JSON.stringify(ylink));
    await p.click('#sdone'); await p.waitForTimeout(300);

    // ?mode=spawning opens Spawning.
    await p.goto(base + 'index.html?mode=spawning&today=2026-10-20'); await p.waitForTimeout(700);
    st = await state(p);
    check(st.checked === 'spawning' && st.spawnShown && st.month === 'Oct' && st.pins > 5, tag + ': ?mode=spawning opens Spawning');
    await p.screenshot({ path: path.join(shots, `sp-${tag}-modelink.png`) });

    // Tab bar: Map → Year → Spots → Counts → Map.
    const hops = [['Year', 'year/index.html'], ['Spots', 'spots/index.html'], ['Counts', 'counts/index.html'], ['Map', 'index.html']];
    for (const [label, want] of hops) {
      await p.click('nav.apptabs a:text-is("' + label + '")'); await p.waitForLoadState('load'); await p.waitForTimeout(500);
      const u = new URL(p.url());
      const info = await p.evaluate(() => ({ cur: (document.querySelector('nav.apptabs [aria-current="page"]') || {}).textContent, overflow: document.documentElement.scrollWidth - innerWidth, seg: getComputedStyle(document.querySelector('nav.apptabs [aria-current="page"]'), '::before').backgroundColor }));
      check(u.pathname === '/' + want && info.cur === label && info.overflow <= 0 && info.seg === tb.seg, tag + ': tab ' + label + ' → ' + u.pathname + ' (current ' + info.cur + ', overflow ' + info.overflow + ', segment ' + info.seg + ')');
      if (label !== 'Map') await p.screenshot({ path: path.join(shots, `sp-${tag}-tab-${label.toLowerCase()}.png`) });
    }
    // The Year page's own link back to the Map.
    await p.goto(base + 'year/index.html'); await p.waitForTimeout(600);
    const back = await p.evaluate(() => { const a = [...document.querySelectorAll('a')].find(x => x.textContent === 'Washington Fishing Map'); return a ? [a.getAttribute('href'), a.target] : null; });
    check(back && back[0] === '../index.html' && back[1] === '', tag + ': Year page links to ../index.html in the same tab ' + JSON.stringify(back));
    await ctx.close();
  }
  check(errs.length === 0, 'no page errors ' + errs.join(' | '));
  const external = requests.filter(r => !/^\/(index\.html|year\/|spots\/|counts\/|[a-z-]+\.js|favicon\.ico)/.test(r));
  check(external.length === 0, 'only local files requested ' + external.join(','));
  check(offsite.length === 0, 'no requests leave the app ' + offsite.join(','));
  console.log(`\n${passes} passed, ${fails} failed`);
  await b.close();
  server.close();
  process.exit(fails ? 1 : 0);
})();
