// Artifacts/salmon-rivers/check-week.mjs — page check for the five-tab site. Local: serves this folder; published: pass --base <url>.
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
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

const args = Object.fromEntries(process.argv.slice(2).map((a, i, arr) => a.startsWith('--') ? [a.slice(2), arr[i + 1]] : []).filter(x => x.length));
const today = args.today || '2026-10-26';
let base = args.base, server = null;
if (!base) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png' };
  server = createServer(async (req, res) => {
    const p = path.join(here, decodeURIComponent(req.url.split('?')[0]));
    if (!existsSync(p)) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream' }); res.end(await readFile(p));
  }).listen(0);
  base = 'http://127.0.0.1:' + server.address().port;
}
const PAGES = [['Map', '/index.html'], ['Week', '/week/index.html'], ['Year', '/year/index.html'], ['Spots', '/spots/index.html'], ['Counts', '/counts/index.html']];
const MINC = 4.5;
const fails = [];
const check = (ok, msg) => { if (!ok) fails.push(msg); console.log((ok ? 'ok   ' : 'FAIL ') + msg); };
const browser = await chromium.launch();
const sizes = [[320, 700], [390, 844], [1024, 768]];
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
      check(tabs.every(t => t.h >= 44), `${name} ${w}px: tabs are 44px targets`);
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
await browser.close(); if (server) server.close();
console.log(fails.length ? `\n${fails.length} FAILED` : '\nall checks passed');
process.exit(fails.length ? 1 : 0);
