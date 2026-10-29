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
  const WRAPPER = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}html{scroll-padding-top:env(safe-area-inset-top,0px)}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}img{max-width:100%}[hidden]:not([hidden=until-found i]){display:none!important}</style></head><body>\n';
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png' };
  server = createServer(async (req, res) => {
    try {
      let p = path.resolve(here, '.' + decodeURIComponent(req.url.split('?')[0]));
      if (p !== here && !p.startsWith(here + path.sep)) { res.writeHead(403); res.end(); return; }
      if (existsSync(p) && statSync(p).isDirectory()) p = path.join(p, 'index.html');
      if (!existsSync(p) || statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
      // The publisher wraps only the page itself (not week/ and the other files) in this skeleton, copied from live 1793083287-e7f9.
      // Without it the page runs in quirks mode and [hidden] loses to a class's display, so .metip and .sppanel showed on load here and never live.
      const body = p === path.join(here, 'index.html') ? Buffer.concat([Buffer.from(WRAPPER), await readFile(p)]) : await readFile(p);
      res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream' }); res.end(body);
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
const sizes = [[320, 700], [360, 780], [390, 844], [1024, 768]];
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
        const lay = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, smonth: !document.getElementById('smonth').hidden, spot: !!document.querySelector('#guides .spotpin') && getComputedStyle(document.querySelector('#guides .spotpin')).display !== 'none', legend: document.querySelectorAll('#layl li').length }));
        check(lay.btn === 'Layers · 3' && lay.smonth && lay.legend === 3, `Layers ${w}px ${scheme}: three layers on, month slider shown, three legend lines (${lay.btn}, ${lay.legend})`);
      }
      if (name === 'Map') {
        const dl = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, legend: document.querySelectorAll('#layl li').length, on: [...document.querySelectorAll('#laypop [data-layer][aria-checked=true]')].length }));
        check(dl.on === 6 && dl.legend === 6, `Map ${w}px ${scheme}: a bare link opens with all six layers on (${dl.btn}, ${dl.on} on, ${dl.legend} legend lines)`);
      }
      if (name === 'Map' && w <= 390) {
        const k = await page.evaluate(() => { const b = document.getElementById('keybtn'); return { h: b.getBoundingClientRect().height, shown: getComputedStyle(b).display !== 'none', body: !document.getElementById('keypop').hidden, exp: b.getAttribute('aria-expanded'), text: b.textContent, hint: getComputedStyle(document.getElementById('rhint')).display !== 'none' }; });
        check(k.shown && k.text === 'Key' && k.h >= 44 && !k.body && k.exp === 'false', `Map ${w}px ${scheme}: the key is closed behind a 44px Key button in the bar (${Math.round(k.h)}px, body shown ${k.body})`);
        const age = await page.evaluate(() => { const c = document.getElementById('agechip'), r = c.getBoundingClientRect(); return { shown: getComputedStyle(c).display !== 'none' && !c.hidden, text: c.textContent, h: Math.round(r.height), right: Math.round(r.right) }; });
        check(age.shown && /^Dashed pins: reports over a week old \(newest [A-Z][a-z]{2} \d{1,2}\)$/.test(age.text) && age.right <= w, `Map ${w}px ${scheme}: the stale-report line is visible on a phone and fits (${age.text})`);
        // The opening view leaves room for that line: it must not cover any pin or pin label.
        const cov = await page.evaluate(() => { const c = document.getElementById('agechip').getBoundingClientRect(); return [...document.querySelectorAll('#over .pin, #guides .pin, #over text.lab:not(.city):not(.peak):not(.dam):not(.water):not(.region), #guides text.lab')].filter(e => { const b = e.getBoundingClientRect(); return e.getClientRects().length && b.bottom > c.top && b.top < c.bottom && b.right > c.left && b.left < c.right; }).map(e => e.textContent || e.getAttribute('data-id')); });
        check(cov.length === 0, `Map ${w}px ${scheme}: the stale-report line covers no pin or pin label (${cov.join(', ')})`);
        await page.click('#keybtn');
        const k2 =await page.evaluate(() => ({ body: !document.getElementById('keypop').hidden, exp: document.getElementById('keybtn').getAttribute('aria-expanded') }));
        check(k2.body && k2.exp === 'true', `Map ${w}px ${scheme}: Key opens the legend`);
        await page.click('#keybtn');
        check(await page.evaluate(() => document.getElementById('keypop').hidden), `Map ${w}px ${scheme}: Key closes it again`);
        if (w >= 360) {
          // The page promises a fit from 360 px up; below that the bar scrolls and the month names are allowed to crowd.
          // With every layer on (the default) the card is already open and has no fold button.
          const folded = await page.isVisible('#mfold');
          if (folded) await page.click('#mfold');
          const ov = await page.evaluate(() => { const rs = [...document.querySelectorAll('#smonth .months button')].filter(b => b.getClientRects().length).map(b => { const g = document.createRange(); g.selectNodeContents(b); const q = g.getBoundingClientRect(); return [b.textContent.trim(), q.left, q.right]; }); return { n: rs.length, hits: rs.slice(1).filter((r, i) => rs[i][2] > r[1] - 1).map((r, i) => r[0]) }; });
          check(ov.n === 12 && ov.hits.length === 0, `Map ${w}px ${scheme}: the twelve month names keep a 1px gap (${ov.n} shown; touching: ${ov.hits.join(', ')})`);
          if (folded) await page.click('#mfold');
        }
        check(k.hint, `Map ${w}px ${scheme}: the "Tap any river" hint shows before any interaction`);
        await page.click('#zin');
        check(await page.evaluate(() => getComputedStyle(document.getElementById('rhint')).display === 'none'), `Map ${w}px ${scheme}: the hint hides after the first map interaction`);
        await page.reload({ waitUntil: 'networkidle' });
        check(await page.evaluate(() => getComputedStyle(document.getElementById('rhint')).display === 'none'), `Map ${w}px ${scheme}: the hint stays hidden for the session`);
      }
      if (name === 'Map' && w >= 1024) {
        check(await page.evaluate(() => { const b = document.getElementById('keybtn'); return getComputedStyle(b).display !== 'none' && getComputedStyle(b.querySelector('.kl')).width !== '1px' && document.getElementById('keypop').hidden; }), `Map ${w}px: the bar shows a labelled Key button and the key starts closed`);
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
      // map: a Typical season marine site sheet shows Tides; a freshwater one does not
      const p3 = await ctx.newPage();
      await p3.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
      const tt = await p3.$eval('#sbody', b => { const h = [...b.querySelectorAll('h3')].find(x => x.textContent === 'Tides'); const sec = h && h.parentElement; return sec ? { text: sec.textContent, n: sec.querySelectorAll('.tideline span').length } : null; });
      check(!!tt && tt.n >= 3 && /Port Angeles station, /.test(tt.text) && /from NOAA’s tide constants for the station: heights above MLLW, Washington time\. Predictions, not observations\./.test(tt.text), `map: marine pier sheet shows Tides with the nearest station and extremes (${tt && tt.text.slice(0, 80)})`);
      await p3.goto(base + '/index.html?mode=typical&site=cow-lake&today=' + today, { waitUntil: 'networkidle' });
      check(await p3.$eval('#sbody', b => b.textContent.length > 50 && ![...b.querySelectorAll('h3')].some(x => x.textContent === 'Tides')), 'map: a freshwater site sheet has no Tides');
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
// Opening view (critique 2026-10-27): on laptop windows every report pin, or the cluster holding it, is on screen below the bar, on load
// and after Reset view. The zoom floor once sat above the fitted scale at 1280x800 and pushed four Columbia rivers off the bottom.
// Phones: the summary chips that run past the card's edge are faded there, and the fade goes once the row is scrolled to its end.
for (const [w, h] of [[1024, 768], [1280, 800], [1440, 900], [390, 844]]) {
  const octx = await browser.newContext({ viewport: { width: w, height: h } });
  const op = await octx.newPage();
  await op.goto(base + '/index.html?mode=reports&today=' + today, { waitUntil: 'networkidle' });
  const seen = () => op.evaluate(() => {
    const top = document.getElementById('bar').getBoundingClientRect().bottom;
    const pins = [...document.querySelectorAll('#over .pin[aria-label]')].map(e => ({ n: e.getAttribute('aria-label').split(',')[0], r: e.getBoundingClientRect() })).filter(q => q.r.width);
    return { n: pins.length, out: pins.filter(q => { const x = q.r.left + q.r.width / 2, y = q.r.top + q.r.height / 2; return x < 0 || x > innerWidth || y < top || y > innerHeight; }).map(q => q.n) };
  });
  const a = await seen();
  await op.click('#zfit'); await op.waitForTimeout(600);
  const b = await seen();
  check(a.n > 0 && !a.out.length && !b.out.length, `open ${w}x${h}: every report pin is on screen, on load and after Reset view (off: ${a.out.concat(b.out).join(', ')})`);
  if (w < 760) {
    const fd = await op.evaluate(() => {
      const d = document.querySelector('#sml .dsum'); if (!d || !d.clientWidth) return null;
      const r = { scrolls: d.scrollWidth > d.clientWidth + 1, start: d.classList.contains('fadeend') };
      d.scrollLeft = d.scrollWidth; d.dispatchEvent(new Event('scroll'));
      r.end = d.classList.contains('fadeend'); return r;
    });
    check(!!fd && (!fd.scrolls || (fd.start && !fd.end)), `open ${w}px: summary chips past the card's edge fade there, and not at the row's end (${JSON.stringify(fd)})`);
  }
  await octx.close();
}
// Month names on a phone whose fallback font is wider than SF Pro (Android, Windows; critique 2026-10-27 finding 3). This Mac has SF Pro, so the
// check forces Verdana as --sans and first proves the font is wide enough that three letters could not fit a 22px cell: a check that passes
// only because the font was never swapped would be worthless.
for (const scheme of ['light', 'dark']) for (const [w, h] of [[360, 780], [375, 812]]) {
  const mctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: scheme });
  const mp = await mctx.newPage();
  await mp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  await mp.addStyleTag({ content: ':root { --sans: Verdana, "DejaVu Sans", sans-serif !important; }' });
  if (await mp.isVisible('#mfold')) await mp.click('#mfold');
  const m = await mp.evaluate(() => {
    const probe = document.createElement('span'); probe.textContent = 'May'; probe.style.cssText = 'position:absolute;visibility:hidden;font:600 12px/16px var(--sans)';
    document.body.appendChild(probe);
    const wide = probe.getBoundingClientRect().width, face = getComputedStyle(probe).fontFamily; probe.remove();
    const btns = [...document.querySelectorAll('#smonth .months button')].filter(b => b.getClientRects().length);
    const rs = btns.map(b => { const g = document.createRange(); g.selectNodeContents(b); const q = g.getBoundingClientRect(); return { name: b.getAttribute('aria-label').split(':')[0], left: q.left, right: q.right, cell: b.getBoundingClientRect().width }; });
    return { wide, face, n: rs.length, cell: Math.round(Math.min(...rs.map(r => r.cell))), hits: rs.slice(1).filter((r, i) => rs[i].right > r.left - 1).map(r => r.name), inCell: rs.every(r => r.right - r.left <= r.cell) };
  });
  check(m.wide > 26 && /Verdana/.test(m.face), `months ${w}px ${scheme}: the forced fallback font is wide (May is ${m.wide.toFixed(1)}px in ${m.face.slice(0, 30)})`);
  check(m.n === 12 && m.hits.length === 0 && m.inCell, `months ${w}px ${scheme}: with a wide fallback font the twelve month names keep a 1px gap and stay in their ${m.cell}px cells (touching: ${m.hits.join(', ')})`);
  await mctx.close();
}
{
  // From 380 px the spelled-out names return; the buttons keep their full names for screen readers at every width.
  for (const [w, h, want] of [[360, 780, 'J'], [390, 844, 'Jan']]) {
    const nctx = await browser.newContext({ viewport: { width: w, height: h } });
    const np = await nctx.newPage();
    await np.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
    if (w < 760 && await np.isVisible('#mfold')) await np.click('#mfold');
    const first = await np.evaluate(() => { const b = document.querySelector('#smonth .months button'); const g = document.createRange(); g.selectNodeContents(b); return { shown: g.toString().length ? [...b.children].filter(c => getComputedStyle(c).display !== 'none').map(c => c.textContent).join('') : '', label: b.getAttribute('aria-label').split(':')[0] }; });
    check(first.shown === want && first.label === 'January', `months ${w}px: the first month button shows "${want}" and is named January (${first.shown}, ${first.label})`);
    await nctx.close();
  }
}
// Guide pins: Kent (three-friends) and Codiga Park overlap at the opening zoom. Every guide must be the thing a tap at its pin reaches,
// either its own pin or a group pin that lists it, and the group's "Zoom in here" must pull the two apart.
for (const [w, h] of [[390, 844], [1280, 800]]) {
  const gctx = await browser.newContext({ viewport: { width: w, height: h } });
  const gp = await gctx.newPage(); const gerr = [];
  gp.on('pageerror', e => gerr.push(String(e)));
  await gp.goto(base + '/index.html?layers=seasons,spots,counts&today=' + today, { waitUntil: 'networkidle' });
  const reach = () => gp.evaluate(() => [...document.querySelectorAll('.spotpin[data-spot]')].map(n => {
    const id = n.getAttribute('data-spot'), grp = [...document.querySelectorAll('.spotpin[data-spotgroup]')].find(g => getComputedStyle(g).display !== 'none' && g.getAttribute('data-spotgroup').split(',').includes(id));
    const via = getComputedStyle(n).display !== 'none' ? n : grp;
    if (!via) return { id, ok: null };
    const r = via.querySelector('.balloon').getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
    if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) return { id, ok: null };
    const hit = document.elementFromPoint(x, y), top = hit && hit.closest('[data-spot],[data-spotgroup],[data-id],[data-season],[data-ssite],[data-tsite],[data-access],[data-count],[data-cluster]');
    return { id, ok: top === via, grouped: via === grp, hit: top ? top.outerHTML.slice(0, 60) : String(hit && hit.tagName) };
  }));
  const before = await reach(), kent = before.find(q => q.id === 'three-friends');
  check(!!kent && kent.ok === true, `guides ${w}px: a tap at the Kent guide's pin reaches it at the opening zoom (${JSON.stringify(kent)})`);
  check(before.every(q => q.ok !== false), `guides ${w}px: no guide pin is covered by another mark (${before.filter(q => q.ok === false).map(q => q.id + ' under ' + q.hit).join('; ')})`);
  // Critique 2026-10-27, finding 6: a group's name starts 4px past its count badge, and no group name sits on another guide pin.
  const gcheck = await gp.evaluate(() => {
    const vis = e => e.style.display !== 'none' && e.getClientRects().length;
    const groups = [...document.querySelectorAll('.spotgrp')].filter(vis), labs = [...document.querySelectorAll('#guides text.lab')].filter(t => vis(t) && /^\d+ spot guides$/.test(t.textContent));
    const hit = (a, b) => a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
    return labs.map(t => {
      const r = t.getBoundingClientRect(), start = t.getAttribute('text-anchor') === 'start';
      // This label's own group: among the groups with the label's count, the one whose badge is nearest its anchored edge.
      const n = t.textContent.split(' ')[0], ex = start ? r.left : r.right;
      const own = groups.filter(g => g.querySelector('.n text').textContent === n).map(g => ({ g, c: g.querySelector('.n circle').getBoundingClientRect() })).sort((p, q) => Math.hypot(p.c.right - ex, p.c.top - r.top) - Math.hypot(q.c.right - ex, q.c.top - r.top))[0];
      const others = [...document.querySelectorAll('.spotpin')].filter(e => vis(e) && e !== own.g).map(e => e.querySelector('.balloon').getBoundingClientRect());
      return { text: t.textContent, gap: start ? Math.round((r.left - own.c.right) * 10) / 10 : null, onPin: others.some(o => hit(r, o)) };
    });
  });
  check(gcheck.length > 0, `guides ${w}px: a group name is drawn at the opening view (${gcheck.length})`);
  check(gcheck.every(q => q.gap === null || q.gap >= 3.5), `guides ${w}px: a group name starts 4px past its count badge (${gcheck.map(q => q.text + ' gap ' + q.gap).join('; ')})`);
  check(gcheck.every(q => !q.onPin), `guides ${w}px: no group name touches another guide pin (${gcheck.filter(q => q.onPin).map(q => q.text).join('; ')})`);
  // Finding 4: every dashed season ring that draws carries its season's name, and the names never sit on a pin or on each other.
  const sr = await gp.evaluate(() => {
    const vis = e => e.style.display !== 'none' && e.getClientRects().length;
    const hit = (a, b) => a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
    const tags = [...document.querySelectorAll('.stag')].filter(vis), pins = [...document.querySelectorAll('#over .pin, #guides .pin')].filter(vis).map(p => p.querySelector('.balloon') || p);
    const rings = [...document.querySelectorAll('.sring')].filter(vis).map(r => {
      const c = r.getBoundingClientRect(), id = r.getAttribute('data-season');
      const near = tags.filter(t => t.getAttribute('data-season') === id).some(t => { const b = t.getBoundingClientRect(); return Math.min(Math.abs(b.left - c.right), Math.abs(c.left - b.right)) < 24 && b.top < c.bottom + 24 && b.bottom > c.top; });
      return { name: r.getAttribute('aria-label'), near };
    });
    const clash = tags.filter(t => { const b = t.getBoundingClientRect(); return pins.some(p => hit(b, p.getBoundingClientRect())) || tags.some(u => u !== t && hit(b, u.getBoundingClientRect())); }).map(t => t.textContent);
    return { rings, clash };
  });
  check(sr.rings.length > 0 && sr.rings.every(r => r.near), `seasons ${w}px: every dashed ring has its season's name beside it (${sr.rings.filter(r => !r.near).map(r => r.name).join('; ') || sr.rings.length + ' rings'})`);
  check(sr.clash.length === 0, `seasons ${w}px: no season name sits on a pin or on another name (${sr.clash.join('; ')})`);
  if (kent && kent.ok && kent.grouped) {
    const at = await gp.evaluate(() => { const g = [...document.querySelectorAll('.spotpin[data-spotgroup]')].find(n => getComputedStyle(n).display !== 'none' && n.getAttribute('data-spotgroup').split(',').includes('three-friends')); const r = g.querySelector('.balloon').getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; });
    await gp.mouse.click(at[0], at[1]);
    await gp.waitForTimeout(400);
    const ch = await gp.evaluate(() => ({ title: document.getElementById('stitle').textContent, rows: [...document.querySelectorAll('#sbody [data-spot]')].map(b => b.getAttribute('data-spot')), zoom: !!document.querySelector('#sbody [data-spotzoom]') }));
    check(/^\d+ spot guides here$/.test(ch.title) && ch.rows.includes('three-friends') && ch.rows.includes('codiga-park') && ch.zoom, `guides ${w}px: the group pin opens a chooser listing Kent and Codiga Park, with Zoom in here (${JSON.stringify(ch)})`);
    await gp.click('#sbody [data-spotzoom]');
    await gp.waitForTimeout(800);
    const after = await reach();
    check(['three-friends', 'codiga-park'].every(id => { const q = after.find(a => a.id === id); return q && q.ok === true && !q.grouped; }), `guides ${w}px: after Zoom in here, Kent and Codiga Park are separate pins a tap reaches (${JSON.stringify(after.filter(q => ['three-friends', 'codiga-park'].includes(q.id)))})`);
  }
  check(gerr.length === 0, `guides ${w}px: no page errors (${gerr.join(' | ').slice(0, 160)})`);
  await gctx.close();
}
} finally { await browser.close(); if (server) server.close(); }
console.log(fails.length ? `\n${fails.length} FAILED` : '\nall checks passed');
process.exit(fails.length ? 1 : 0);
