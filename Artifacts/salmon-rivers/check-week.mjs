// Artifacts/salmon-rivers/check-week.mjs — page check for the five-tab site. Local: serves this folder; published: pass --base <url>.
import { createServer, request as httpRequest } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
import { createRequire } from 'node:module';
const loadPW = async () => {
  if (process.env.PLAYWRIGHT_CORE) return import(process.env.PLAYWRIGHT_CORE);
  try { return await import('playwright-core'); } catch {}
  try { return createRequire(import.meta.url)('playwright'); } catch {}
  return createRequire('/opt/npm-tools/node_modules/')('playwright');
};
const { chromium } = await loadPW();

const USAGE = 'usage: node check-week.mjs [--base <url>] [--today YYYY-MM-DD] [--shots <dir>]';
const args = {};
{
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i].startsWith('--') ? argv[i].slice(2) : null;
    if (!['base', 'today', 'shots'].includes(k) || argv[i + 1] === undefined || argv[i + 1].startsWith('--')) { console.error((k ? `bad or unknown option: ${argv[i]}` : `unexpected argument: ${argv[i]}`) + '\n' + USAGE); process.exit(2); }
    args[k] = argv[++i];
  }
}
const today = args.today || '2026-10-26';
let base = args.base, server = null;
if (!base) {
  // utf-8 is stated because the publisher's wrapper declares it on the live page; without it a "·" reads as "Â·" and text checks fail.
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png' };
  server = createServer(async (req, res) => {
    try {
      let p = path.resolve(here, '.' + decodeURIComponent(req.url.split('?')[0]));
      if (p !== here && !p.startsWith(here + path.sep)) { res.writeHead(403); res.end(); return; }
      if (existsSync(p) && statSync(p).isDirectory()) p = path.join(p, 'index.html');
      if (!existsSync(p) || statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream' }); res.end(await readFile(p));
    } catch { res.writeHead(400); res.end(); }
  }).listen(0, '127.0.0.1');
  if (!server.listening) await new Promise(r => server.once('listening', r));
  base = 'http://127.0.0.1:' + server.address().port;
}
const PAGES = [['Map', '/index.html'], ['Week', '/week/index.html'], ['Year', '/year/index.html'], ['Spots', '/spots/index.html'], ['Counts', '/counts/index.html']];
const MINC = 4.5;
const fails = [];
const check = (ok, msg) => { if (!ok) fails.push(msg); console.log((ok ? 'ok   ' : 'FAIL ') + msg); };
const browser = await chromium.launch();
try {
const sizes = [[320, 700], [390, 844], [1024, 768]];
if (server) {
  // The local static server: no path may leave this folder, a directory serves its index.html, a missing directory is a 404.
  const raw = p => new Promise((ok, no) => { const r = httpRequest({ host: '127.0.0.1', port: server.address().port, path: p }, res => { res.resume(); ok(res.statusCode); }); r.on('error', no); r.end(); });
  check(await raw('/../package.json') === 403, 'static server: /../ escaping the folder is 403');
  check(await raw('/week/../../x') === 403, 'static server: nested .. escaping the folder is 403');
  check(await raw('/%2e%2e/x') === 403, 'static server: encoded .. escaping the folder is 403');
  check(await raw('/week/') === 200, 'static server: a directory serves its index.html');
  check(await raw('/nope/') === 404, 'static server: a missing directory is 404');
}
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
      // A mouse on a wide window folds the page tabs into the map bar as 36px segments; everything else keeps 44px targets.
      const oneBar = name === 'Map' && w >= 1024;
      check(tabs.every(t => t.h >= (oneBar ? 36 : 44)), `${name} ${w}px: tabs are ${oneBar ? 36 : 44}px targets`);
      if (oneBar) {
        const ob = await page.evaluate(() => { const bar = document.getElementById('bar').getBoundingClientRect(), nav = document.querySelector('nav.apptabs'); return { inBar: nav.parentElement.id === 'bar', barH: Math.round(bar.height), top: Math.round(bar.top), tabsInside: nav.getBoundingClientRect().bottom <= bar.bottom + 1, modes: document.getElementById('modes').parentElement.id, modebtn: getComputedStyle(document.getElementById('modebtn')).display !== 'none', scrolls: document.getElementById('bar').scrollWidth > document.getElementById('bar').clientWidth + 1 }; });
        check(ob.inBar && ob.barH === 44 && ob.top <= 16 && ob.tabsInside, `Map ${w}px ${scheme}: one 44px bar holds the page tabs (in bar ${ob.inBar}, ${ob.barH}px, top ${ob.top}px)`);
        check(ob.modes === 'mpop' && ob.modebtn, `Map ${w}px ${scheme}: the mode switch is the dropdown button (modes in ${ob.modes})`);
        check(!ob.scrolls, `Map ${w}px ${scheme}: the one bar fits without scrolling`);
      }
      check(tabs.filter(t => t.cur === 'page').map(t => t.t)[0] === name, `${name} ${w}px: own tab is current`);
      if (w === 390) {
        const c = await page.evaluate(() => {
          const rgba = v => { const m = v.match(/[\d.]+/g).map(Number); return { r: m[0], g: m[1], b: m[2], a: m.length > 3 ? m[3] : 1 }; };
          const over = (f, b) => ({ r: f.r * f.a + b.r * (1 - f.a), g: f.g * f.a + b.g * (1 - f.a), b: f.b * f.a + b.b * (1 - f.a), a: 1 });
          let page = rgba(getComputedStyle(document.body).backgroundColor);
          if (page.a < 1) page = over(page, rgba(getComputedStyle(document.documentElement).backgroundColor).a ? rgba(getComputedStyle(document.documentElement).backgroundColor) : { r: 255, g: 255, b: 255, a: 1 });
          const lum = c => { const f = x => { x /= 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); }; return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b); };
          const track = document.querySelector('.apptabs-track');
          return [...document.querySelectorAll('nav.apptabs a')].map(a => {
            const bgv = a.getAttribute('aria-current') === 'page' ? getComputedStyle(a, '::before').backgroundColor : getComputedStyle(track).backgroundColor;
            const bg = over(rgba(bgv), page), fg = over(rgba(getComputedStyle(a).color), bg);
            const [hi, lo] = [lum(fg), lum(bg)].sort((x, y) => y - x);
            return (hi + .05) / (lo + .05);
          });
        });
        const low = Math.min(...c);
        check(c.length === 5 && low >= MINC, `${name} ${w}px ${scheme}: tab label contrast >= ${MINC} (lowest ${low.toFixed(2)})`);
      }
      const sx = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
      check(sx, `${name} ${w}px: no horizontal scroll`);
      if (name === 'Week') {
        const ids = await page.$$eval('section.group', ss => ss.map(s => s.id));
        check(ids.join(',') === 'open,reported,rules,upcoming,tides,spots', `Week ${w}px: sections in order (${ids})`);
        if (w === 390) {
          const pos = await page.evaluate(() => ({ r: document.getElementById('rules').getBoundingClientRect().top + scrollY, t: document.getElementById('tides').getBoundingClientRect().top + scrollY }));
          console.log(`     #rules top ${Math.round(pos.r)}px, #tides top ${Math.round(pos.t)}px (${scheme}, today=${today})`);
          check(pos.r < pos.t, `Week 390px ${scheme}: #rules is above #tides (${Math.round(pos.r)} < ${Math.round(pos.t)})`);
          check(pos.r <= 1300, `Week 390px ${scheme}: #rules starts within 1300px (${Math.round(pos.r)})`);
          // Top 2: empty Reported row names the newest report and links to the map
          const rep = await page.evaluate(() => { const li = document.querySelector('#reported li.empty'); return li ? { text: li.textContent, hasLink: !!li.querySelector('a[href*="mode=reports"]'), latest: Week.fmt(Reports.latestReport(Reports.SITES)) } : null; });
          check(!!rep && rep.hasLink, `Week 390px ${scheme}: empty Reported row links to the map's reports mode`);
          check(!!rep && rep.text.includes(rep.latest), `Week 390px ${scheme}: empty Reported row names the newest report (${rep && rep.latest})`);
          // Top 3: next extreme is in the ink colour with strong contrast
          const nx = await page.evaluate(() => {
            const rgba = v => { const m = v.match(/[\d.]+/g).map(Number); return { r: m[0], g: m[1], b: m[2], a: m.length > 3 ? m[3] : 1 }; };
            const lum = c => { const f = x => { x /= 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); }; return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b); };
            const n = document.querySelectorAll('#tides .ex.next');
            if (!n.length) return { n: 0 };
            const th = document.querySelector('#tides tr:not(.today) th');
            let bgEl = n[0], bg = { r: 0, g: 0, b: 0, a: 0 };
            while (bgEl && bg.a === 0) { bg = rgba(getComputedStyle(bgEl).backgroundColor); bgEl = bgEl.parentElement; }
            if (bg.a === 0) bg = rgba(getComputedStyle(document.body).backgroundColor);
            const fg = rgba(getComputedStyle(n[0]).color);
            const [hi, lo] = [lum(fg), lum(bg)].sort((x, y) => y - x);
            return { n: n.length, color: getComputedStyle(n[0]).color, ink: getComputedStyle(th).color, ratio: (hi + .05) / (lo + .05) };
          });
          check(nx.n === 1, `Week 390px ${scheme}: exactly one .ex.next (${nx.n})`);
          check(nx.n === 1 && nx.color === nx.ink, `Week 390px ${scheme}: next extreme uses the ink colour (${nx.color} vs ${nx.ink})`);
          check(nx.n === 1 && nx.ratio >= 12, `Week 390px ${scheme}: next extreme contrast >= 12:1 (${nx.ratio && nx.ratio.toFixed(1)})`);
        }
        const chip = await page.$('.chip.soon');
        check(!!chip, `Week ${w}px: ends-soon chip present with today=${today}`);
        const tides = await page.$$eval('#tides table.tides tbody tr', rs => ({ n: rs.length, ex: rs.every(r => r.querySelector('.ex')) }));
        check(tides.n === 7 && tides.ex, `Week ${w}px: tide table has 7 filled rows, each with an extreme (${tides.n} rows, ex ${tides.ex})`);
        check(await page.$eval('#tides', s => /^NOAA predictions through [A-Z][a-z]{2} \d{1,2}, MLLW, local time\. Not observations\.$/.test(s.querySelector('.fine').textContent)), `Week ${w}px: tides footnote names the bundle end`);
      }
      if (name === 'Week' && w >= 600) {
        // At >=600px each day's td is a two-column grid of fixed width, so extremes line up by column and no extreme wraps onto a second line.
        const g = await page.$$eval('#tides table.tides tbody tr', rs => rs.map(r => { const td = r.querySelector('td'); return { cols: getComputedStyle(td).gridTemplateColumns.split(' ').length, display: getComputedStyle(td).display, lefts: [...td.querySelectorAll('.ex')].map(e => Math.round(e.getBoundingClientRect().left)), wrapped: [...td.querySelectorAll('.ex')].filter(e => e.getClientRects().length > 1 || e.getBoundingClientRect().height > 24 || e.scrollWidth > e.clientWidth + 1).length }; }));
        check(g.every(r => r.display === 'grid' && r.cols === 2), `Week ${w}px ${scheme}: every tide td is a 2-column grid (${g.map(r => r.cols).join(',')})`);
        check(g.every(r => r.wrapped === 0), `Week ${w}px ${scheme}: no tide extreme wraps or overflows its column (${g.map(r => r.wrapped).join(',')})`);
        const aligned = [0, 1].every(k => new Set(g.flatMap(r => r.lefts.filter((_, i) => i % 2 === k))).size <= 1);
        check(aligned, `Week ${w}px ${scheme}: the nth extreme starts at the same x in every row (${g.map(r => r.lefts.join('/')).join(' | ')})`);
      }
      if (name === 'Week') {
        const t = await page.evaluate(() => ({ cap: document.querySelector('#tides .cap').textContent, soon: document.querySelector('.chip.soon').textContent, taste: [...document.querySelectorAll('.chip')].filter(c => /^Taste/.test(c.textContent)).map(c => [c.textContent, c.title]), rules: [...document.querySelectorAll('#rules a')].map(a => [a.textContent, a.getAttribute('aria-label')]) }));
        check(t.cap === 'Tides, next 7 days', `Week ${w}px: tides caption names its window (${t.cap})`);
        check(/^Ends soon · ends [A-Z][a-z]{2} \d{1,2} · \d+ days?$|^Ends soon · ends today$/.test(t.soon), `Week ${w}px: ends-soon chip has the words (${t.soon})`);
        check(t.taste.length > 0 && t.taste.every(([x, ti]) => /^Taste #\d of 5$/.test(x) && /Taste order, richest first/.test(ti)), `Week ${w}px: taste chips read "of 5" with a title (${t.taste[0]})`);
        check(t.rules.length > 0 && t.rules.every(([x, l]) => x === 'Read the rule' && /^Read the WDFW rule for \S/.test(l)), `Week ${w}px: rule links name their rivers (${t.rules[0] && t.rules[0][1]})`);
      }
      if (name === 'Counts') {
        const c = await page.evaluate(() => {
          const d = document.getElementById('filters'), sum = document.getElementById('fsum'), h1 = document.querySelector('h1');
          const grid = document.getElementById('grid'), th = document.querySelector('thead th'), td = document.querySelector('tbody tr td');
          grid.scrollLeft = 150;
          const gl = grid.getBoundingClientRect().left;
          return { open: d.open, sumShown: getComputedStyle(sum).display !== 'none', sumText: sum.textContent, sumH: sum.getBoundingClientRect().height, h1: h1.textContent, hAlign: Math.abs((h1.getBoundingClientRect().left + h1.getBoundingClientRect().right) / 2 - innerWidth / 2) < 40 || innerWidth < 600,
            thPos: getComputedStyle(th).position, tdPos: getComputedStyle(td).position, scrolled: grid.scrollLeft, tdLeft: Math.round(td.getBoundingClientRect().left - gl), fade: getComputedStyle(document.getElementById('gridwrap'), '::after').opacity,
            text: document.querySelector('main').textContent };
        });
        check(c.h1 === 'SW Washington creel counts' && c.hAlign, `Counts ${w}px: h1 in the centred column (${c.h1})`);
        check(!/\(not parsed\)/.test(c.text) && /Unclear species/.test(c.text), `Counts ${w}px: "(not parsed)" is shown as "Unclear species"`);
        if (w <= 480) {
          check(!c.open && c.sumShown && /^Filters · \d+ active$/.test(c.sumText) && c.sumH >= 44, `Counts ${w}px ${scheme}: filters are in a closed details, "${c.sumText}", summary ${Math.round(c.sumH)}px`);
          check(c.scrolled > 0 && c.thPos === 'sticky' && c.tdPos === 'sticky' && c.tdLeft === 0, `Counts ${w}px ${scheme}: River column is sticky (scrolled ${c.scrolled}px, cell at ${c.tdLeft}px from the scroller edge)`);
          check(Number(c.fade) === 1, `Counts ${w}px ${scheme}: right-edge fade shows while the table can scroll (${c.fade})`);
        } else {
          check(c.open && !c.sumShown, `Counts ${w}px: filters are open and the summary is hidden`);
        }
      }
      if (name === 'Map' && w <= 390) {
        const k = await page.evaluate(() => { const b = document.getElementById('legkey'), body = document.getElementById('legbody'); return { h: b.getBoundingClientRect().height, shown: getComputedStyle(b).display !== 'none', body: getComputedStyle(body).display !== 'none', exp: b.getAttribute('aria-expanded'), text: b.textContent, hint: getComputedStyle(document.getElementById('rhint')).display !== 'none' }; });
        check(k.shown && k.text === 'Key' && k.h >= 44 && !k.body && k.exp === 'false', `Map ${w}px ${scheme}: legend is collapsed to a 44px Key button (${Math.round(k.h)}px, body shown ${k.body})`);
        const age = await page.evaluate(() => { const c = document.getElementById('agechip'), r = c.getBoundingClientRect(); return { shown: getComputedStyle(c).display !== 'none' && !c.hidden, text: c.textContent, h: Math.round(r.height), right: Math.round(r.right) }; });
        check(age.shown && /^Dashed pins: reports over a week old \(newest [A-Z][a-z]{2} \d{1,2}\)$/.test(age.text) && age.right <= w, `Map ${w}px ${scheme}: the stale-report line is visible on a phone and fits (${age.text})`);
        await page.click('#legkey');
        const k2 =await page.evaluate(() => ({ body: getComputedStyle(document.getElementById('legbody')).display !== 'none', exp: document.getElementById('legkey').getAttribute('aria-expanded') }));
        check(k2.body && k2.exp === 'true', `Map ${w}px ${scheme}: Key opens the legend`);
        await page.click('#legkey');
        check(await page.evaluate(() => getComputedStyle(document.getElementById('legbody')).display === 'none'), `Map ${w}px ${scheme}: Key closes it again`);
        check(k.hint, `Map ${w}px ${scheme}: the "Tap any river" hint shows before any interaction`);
        await page.click('#zin');
        check(await page.evaluate(() => getComputedStyle(document.getElementById('rhint')).display === 'none'), `Map ${w}px ${scheme}: the hint hides after the first map interaction`);
        await page.reload({ waitUntil: 'networkidle' });
        check(await page.evaluate(() => getComputedStyle(document.getElementById('rhint')).display === 'none'), `Map ${w}px ${scheme}: the hint stays hidden for the session`);
      }
      if (name === 'Map' && w >= 1024) {
        check(await page.evaluate(() => getComputedStyle(document.getElementById('legkey')).display === 'none' && getComputedStyle(document.getElementById('legbody')).display !== 'none'), `Map ${w}px: no Key button, the legend is open`);
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
      for (const bad of ['constructor', '__proto__', 'toString']) {
        const errs = []; const onc = m => { if (m.type() === 'error') errs.push(m.text()); }, onp = e => errs.push(String(e));
        page.on('console', onc); page.on('pageerror', onp);
        await page.goto(base + '/index.html?mode=reports&river=' + bad, { waitUntil: 'networkidle' });
        check(await page.$eval('#sheet', s => !s.classList.contains('open')) && errs.length === 0, `deep link: river=${bad} ignored, no console errors (${errs.join(' | ').slice(0, 120)})`);
        page.off('console', onc); page.off('pageerror', onp);
      }
      // closures above tides with no ?today too
      await page.goto(base + '/week/index.html', { waitUntil: 'networkidle' });
      const pos0 = await page.evaluate(() => ({ r: document.getElementById('rules').getBoundingClientRect().top + scrollY, t: document.getElementById('tides').getBoundingClientRect().top + scrollY }));
      console.log(`     no ?today: #rules top ${Math.round(pos0.r)}px, #tides top ${Math.round(pos0.t)}px`);
      check(pos0.r < pos0.t && pos0.r <= 1300, `Week 390px, no ?today: #rules above #tides and within 1300px (${Math.round(pos0.r)})`);
      // Week footer: disclaimer first, WDFW link
      check(await page.$eval('#foot', f => f.textContent.startsWith('Guidance, not regulation.') && !!f.querySelector('a[href*="wdfw.wa.gov"]')), 'Week footer starts with the disclaimer and links wdfw.wa.gov');
      // no network: the Week page and the map make no request outside this origin
      const outside = []; const pn = await ctx.newPage();
      pn.on('request', r => { if (!r.url().startsWith(base) && !r.url().startsWith('data:') && !r.url().startsWith('blob:')) outside.push(r.url()); });
      await pn.goto(base + '/week/index.html?today=' + today, { waitUntil: 'networkidle' });
      await pn.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
      check(outside.length === 0, `no network: no request leaves the page (${outside.slice(0, 3).join(', ')})`);
      await pn.close();
      // boot failure: year/data.js blocked -> one fallback panel, footer and WDFW links stay, tides still mount
      const pf = await ctx.newPage();
      await pf.route('**/year/data.js', r => r.abort());
      await pf.goto(base + '/week/index.html?today=' + today, { waitUntil: 'networkidle' });
      const fb = await pf.evaluate(() => ({ text: document.getElementById('week').textContent, foot: !!document.querySelector('#foot a[href*="emergency-rules"]') && !!document.querySelector('#foot a[href$="/fishing/regulations"]'), rows: document.querySelectorAll('#tides table.tides tbody tr').length }));
      check(fb.text.includes("This week's summary couldn't be built from the page data.") && fb.foot && fb.rows === 7, `Week: with year/data.js blocked the fallback panel shows, the footer links stay and #tides renders 7 rows (rows ${fb.rows})`);
      await pf.close();
      // ?today=2026-13-01 (not a real date) falls back to the device date with no page error, on the Week page and the map
      for (const u of ['/week/index.html?today=2026-13-01', '/index.html?today=2026-13-01']) {
        const pb = await ctx.newPage(); const errs = []; pb.on('pageerror', e => errs.push(e.message));
        await pb.goto(base + u, { waitUntil: 'networkidle' });
        const shown = await pb.evaluate(() => (document.getElementById('range') || document.body).innerText);
        check(errs.length === 0 && !/2026-13|NaN|Invalid/.test(shown), `${u}: an impossible ?today falls back without errors (${errs[0] || 'none'})`);
        await pb.close();
      }
      // today past the bundle end -> beyond-bundle rows
      const p2 = await ctx.newPage();
      await p2.goto(base + '/week/index.html?today=2027-03-10', { waitUntil: 'networkidle' });
      const bey = await p2.$$eval('#tides table.tides tbody td', tds => tds.map(t => t.textContent));
      check(bey.length === 7 && bey.every(t => /^Beyond the bundled predictions \(through [A-Z][a-z]{2} \d{1,2}\)$/.test(t)), `tides: today past the bundle end shows 7 beyond-bundle rows (${bey[0]})`);
      // map: a Typical season marine site sheet shows Tides today; a freshwater one does not
      const p3 = await ctx.newPage();
      await p3.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
      const tt = await p3.$eval('#sbody', b => { const h = [...b.querySelectorAll('h3')].find(x => x.textContent === 'Tides today'); const sec = h && h.parentElement; return sec ? { text: sec.textContent, n: sec.querySelectorAll('.tideline span').length } : null; });
      check(!!tt && tt.n >= 3 && /Port Angeles station, /.test(tt.text) && /NOAA predictions through [A-Z][a-z]{2} \d{1,2}, MLLW, local time\. Not observations\./.test(tt.text), `map: marine pier sheet shows Tides today with the nearest station and extremes (${tt && tt.text.slice(0, 80)})`);
      await p3.goto(base + '/index.html?mode=typical&site=cow-lake&today=' + today, { waitUntil: 'networkidle' });
      check(await p3.$eval('#sbody', b => b.textContent.length > 50 && ![...b.querySelectorAll('h3')].some(x => x.textContent === 'Tides today')), 'map: a freshwater site sheet has no Tides today');
      await p3.close();
      await page.close(); await p2.close();
    }
    await ctx.close();
  }
}
// A report site beyond geo.js (spec 2026-10-26-puget-river-reports): served by intercepting reports.js, so the real data stays unchanged.
const FIXTURE = "\nif (typeof window !== 'undefined') window.Reports.SITES.push({ id: 'fx-skagit', name: 'Skagit River', sub: 'Fixture', hl: true, tap: 'skagit-river', ll: [48.42, -122.33], added: '2026-10-25', reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-24', d: 'Fixture.', src: { label: 'Fixture', url: 'https://example.org/r' } } } });\n";
for (const [w, h] of [[390, 844], [1280, 800]]) {
  const fctx = await browser.newContext({ viewport: { width: w, height: h } });
  const fp = await fctx.newPage(); const ferr = [];
  fp.on('pageerror', e => ferr.push(String(e)));
  await fp.route('**/reports.js', async route => { const res = await route.fetch(); await route.fulfill({ response: res, body: (await res.text()) + FIXTURE }); });
  await fp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  const f = await fp.evaluate(() => {
    const pin = document.querySelector('#over .pin[data-id="fx-skagit"]'), g = document.querySelector('.hl[data-id="fx-skagit"]'), r = pin && pin.getBoundingClientRect();
    return { pin: !!pin, inView: !!r && r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight, line: !!g, rc: g ? g.style.getPropertyValue('--rc') : '',
      sub: document.getElementById('sub').textContent, aria: document.getElementById('map').getAttribute('aria-label'),
      lab: [...document.querySelectorAll('#over text.lab')].some(t => t.textContent.includes('Skagit · Good')) };
  });
  check(f.pin && f.inView, `map ${w}px fixture: a site beyond geo.js has a pin inside the opening view`);
  check(f.line && f.rc === 'var(--good)', `map ${w}px fixture: its line comes from the tappable river, coloured by its rating (${f.rc})`);
  check(/^Washington · reports through /.test(f.sub) && /^Map of salmon rivers in Washington\./.test(f.aria), `map ${w}px fixture: the region reads Washington (${f.sub})`);
  check(f.lab, `map ${w}px fixture: its pin label reads Skagit · Good`);
  // The fixture site's own sheet: no Columbia-tributary sources, and the Skagit WDFW notice (rules.js) reachable from it.
  await fp.goto(base + '/index.html?mode=reports&river=fx-skagit&today=' + today, { waitUntil: 'networkidle' });
  const sh = await fp.evaluate(() => {
    const b = document.getElementById('sbody'), h = [...b.querySelectorAll('h3')].find(x => x.textContent === 'WDFW notices');
    return { title: document.getElementById('stitle').textContent, gf: [...b.querySelectorAll('a')].filter(a => a.href.includes('theguidesforecast.com')).length,
      notice: !!h && /Gilligan Creek/.test(h.parentElement.textContent) };
  });
  check(sh.title === 'Skagit River' && sh.gf === 0, `map ${w}px fixture: its sheet cites no Guide's Forecast link (${sh.title}, ${sh.gf} links)`);
  check(sh.title === 'Skagit River' && sh.notice, `map ${w}px fixture: its sheet shows the Skagit WDFW notice`);
  check(ferr.length === 0, `map ${w}px fixture: no page errors (${ferr.join(' | ').slice(0, 160)})`);
  await fctx.close();
}
} finally { await browser.close(); if (server) server.close(); }
console.log(fails.length ? `\n${fails.length} FAILED` : '\nall checks passed');
process.exit(fails.length ? 1 : 0);
