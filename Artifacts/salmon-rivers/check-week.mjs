// Artifacts/salmon-rivers/check-week.mjs: page check for the one-map site (the map and its layers). Local: serves this folder; published: pass --base <url>.
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
const PAGES = [['Map', '/index.html', ''], ['Layers', '/index.html', 'layers=seasons,spots,counts&']];
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
    for (const [name, p, q] of PAGES) {
      const page = await ctx.newPage();
      const errors = [];
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', e => errors.push(String(e)));
      await page.goto(base + p + '?' + q + 'today=' + today, { waitUntil: 'networkidle' });
      check(errors.length === 0, `${name} ${w}px ${scheme}: no console errors (${errors.join(' | ').slice(0, 200)})`);
      // A mouse on a wide window gets the compact bar: one 44px row with 36px controls. Everything else keeps 44px targets.
      const bar = await page.evaluate(() => ({ h: Math.round(document.getElementById('bar').getBoundingClientRect().height), min: Math.min(...[...document.querySelectorAll('#bar .listbtn, #bar .nbtn')].filter(b => b.getClientRects().length).map(b => b.getBoundingClientRect().height)), tabs: !!document.querySelector('nav.apptabs') }));
      check(!bar.tabs, `${name} ${w}px: no page tab bar`);
      check(bar.min >= (w >= 1024 ? 36 : 44), `${name} ${w}px: bar controls are ${w >= 1024 ? 36 : 44}px targets (${bar.min}px, bar ${bar.h}px)`);
      const sx = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
      check(sx, `${name} ${w}px: no horizontal scroll`);
      if (name === 'Layers') {
        const lay = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, smonth: !document.getElementById('smonth').hidden, spot: !!document.querySelector('#over .spotpin') && getComputedStyle(document.querySelector('#over .spotpin')).display !== 'none', legend: document.querySelectorAll('#layl li').length }));
        check(lay.btn === 'Layers · 3' && lay.smonth && lay.legend === 3, `Layers ${w}px ${scheme}: three layers on, month slider shown, three legend lines (${lay.btn}, ${lay.legend})`);
      }
      if (name === 'Map' && w <= 390) {
        const k = await page.evaluate(() => { const b = document.getElementById('legkey'), body = document.getElementById('legbody'); return { h: b.getBoundingClientRect().height, shown: getComputedStyle(b).display !== 'none', body: getComputedStyle(body).display !== 'none', exp: b.getAttribute('aria-expanded'), text: b.textContent, hint: getComputedStyle(document.getElementById('rhint')).display !== 'none' }; });
        check(k.shown && k.text === 'Key' && k.h >= 44 && !k.body && k.exp === 'false', `Map ${w}px ${scheme}: legend is collapsed to a 44px Key button (${Math.round(k.h)}px, body shown ${k.body})`);
        const age = await page.evaluate(() => { const c = document.getElementById('agechip'), r = c.getBoundingClientRect(); return { shown: getComputedStyle(c).display !== 'none' && !c.hidden, text: c.textContent, h: Math.round(r.height), right: Math.round(r.right) }; });
        check(age.shown && /^Dashed pins: reports over a week old \(newest [A-Z][a-z]{2} \d{1,2}\)$/.test(age.text) && age.right <= w, `Map ${w}px ${scheme}: the stale-report line is visible on a phone and fits (${age.text})`);
        // The opening view leaves room for that line: it must not cover any pin or pin label.
        const cov = await page.evaluate(() => { const c = document.getElementById('agechip').getBoundingClientRect(); return [...document.querySelectorAll('#over .pin, #over text.lab:not(.city):not(.peak):not(.dam):not(.water):not(.region)')].filter(e => { const b = e.getBoundingClientRect(); return e.getClientRects().length && b.bottom > c.top && b.top < c.bottom && b.right > c.left && b.left < c.right; }).map(e => e.textContent || e.getAttribute('data-id')); });
        check(cov.length === 0, `Map ${w}px ${scheme}: the stale-report line covers no pin or pin label (${cov.join(', ')})`);
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
      // redirects: each retired page lands on its layer
      for (const [u, want] of [['/week/', 'layers=seasons'], ['/year/#chum', 'season=chum'], ['/spots/', 'spot=three-friends'], ['/counts/', 'layers=counts']]) {
        await page.goto(base + u, { waitUntil: 'networkidle' });
        check(page.url().includes(want), `redirect: ${u} lands on ${want} (${page.url()})`);
      }
      // no network: the map with every layer makes no request outside this origin
      const outside = []; const pn = await ctx.newPage();
      pn.on('request', r => { if (!r.url().startsWith(base) && !r.url().startsWith('data:') && !r.url().startsWith('blob:')) outside.push(r.url()); });
      await pn.goto(base + '/index.html?layers=seasons,spots,counts&today=' + today, { waitUntil: 'networkidle' });
      await pn.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
      check(outside.length === 0, `no network: no request leaves the page (${outside.slice(0, 3).join(', ')})`);
      await pn.close();
      // ?today=2026-13-01 (not a real date) falls back to the device date with no page error
      for (const u of ['/index.html?today=2026-13-01']) {
        const pb = await ctx.newPage(); const errs = []; pb.on('pageerror', e => errs.push(e.message));
        await pb.goto(base + u, { waitUntil: 'networkidle' });
        const shown = await pb.evaluate(() => (document.getElementById('range') || document.body).innerText);
        check(errs.length === 0 && !/2026-13|NaN|Invalid/.test(shown), `${u}: an impossible ?today falls back without errors (${errs[0] || 'none'})`);
        await pb.close();
      }
      // map: a Typical season marine site sheet shows Tides today; a freshwater one does not
      const p3 = await ctx.newPage();
      await p3.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
      const tt = await p3.$eval('#sbody', b => { const h = [...b.querySelectorAll('h3')].find(x => x.textContent === 'Tides today'); const sec = h && h.parentElement; return sec ? { text: sec.textContent, n: sec.querySelectorAll('.tideline span').length } : null; });
      check(!!tt && tt.n >= 3 && /Port Angeles station, /.test(tt.text) && /NOAA predictions through [A-Z][a-z]{2} \d{1,2}, MLLW, local time\. Not observations\./.test(tt.text), `map: marine pier sheet shows Tides today with the nearest station and extremes (${tt && tt.text.slice(0, 80)})`);
      await p3.goto(base + '/index.html?mode=typical&site=cow-lake&today=' + today, { waitUntil: 'networkidle' });
      check(await p3.$eval('#sbody', b => b.textContent.length > 50 && ![...b.querySelectorAll('h3')].some(x => x.textContent === 'Tides today')), 'map: a freshwater site sheet has no Tides today');
      await p3.close();
      await page.close();
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
