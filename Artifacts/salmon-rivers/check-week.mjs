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
      // A mouse on a wide window gets the compact bar: one 44px row with 36px controls. Everything else keeps 44px targets. A compact control may draw smaller
      // than that if an invisible ::after extender brings its tappable height up to the target (tapH adds the extender's negative top and bottom inset).
      const bar = await page.evaluate(() => { const tapH = (b) => { const r = b.getBoundingClientRect().height, a = getComputedStyle(b, '::after'); const ext = a.content !== 'none' && a.position === 'absolute' ? Math.max(0, -parseFloat(a.top) || 0) + Math.max(0, -parseFloat(a.bottom) || 0) : 0; return r + ext; }; return ({ h: Math.round(document.getElementById('bar').getBoundingClientRect().height), min: Math.min(...[...document.querySelectorAll('#bar .listbtn, #bar .nbtn')].filter(b => b.getClientRects().length).map(b => tapH(b))), tabs: !!document.querySelector('nav.apptabs') }); });
      check(!bar.tabs, `${name} ${w}px: no page tab bar`);
      check(bar.min >= (w >= 1024 ? 36 : 44), `${name} ${w}px: bar controls are ${w >= 1024 ? 36 : 44}px targets (${bar.min}px, bar ${bar.h}px)`);
      const sx = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
      check(sx, `${name} ${w}px: no horizontal scroll`);
      if (name === 'Layers') {
        const lay = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, smonth: !document.getElementById('smonth').hidden, spot: !!document.querySelector('#guides .spotpin') && getComputedStyle(document.querySelector('#guides .spotpin')).display !== 'none', legend: document.querySelectorAll('#layl li:not(.lkh)').length }));
        check(lay.btn === 'Layers · 3' && lay.smonth && lay.legend === 3, `Layers ${w}px ${scheme}: three layers on, month slider shown, three legend lines (${lay.btn}, ${lay.legend})`);
      }
      if (name === 'Map') {
        // The month card carries no "at a glance" heading and no report tally chip; the three neutral chips stay.
        const gl = await page.evaluate(() => { const c = document.getElementById('sml'); const b = [...c.querySelectorAll('.dsum button')].map(x => x.getAttribute('data-dash')); return { glance: /at a glance/.test(c.textContent), tally: !!c.querySelector('[data-dash="reports"], .rk'), chips: b }; });
        check(!gl.glance && !gl.tally && gl.chips.includes('seasons') && gl.chips.includes('spawn') && gl.chips.includes('typical'), `Map ${w}px ${scheme}: the month card has no "at a glance" heading or report tally, and keeps seasons, spawning and prime-season chips (${gl.chips.join(', ')})`);
      }
      if (name === 'Map') {
        // Heat circles and bars never use the rating ramp: red, orange and amber already mean Excellent, Good and Fair reports.
        const hv = await page.evaluate(() => { const cs = getComputedStyle(document.documentElement), g = n => cs.getPropertyValue('--' + n).trim().toLowerCase(); const heat = [1, 2, 3].map(i => g('heat-' + i)), rate = ['prime', 'good', 'fair', 'slow'].map(g); return { heat, rate, clash: heat.filter(h => rate.includes(h)).length }; });
        check(hv.heat.every(Boolean) && hv.rate.every(Boolean) && hv.clash === 0, `Map ${w}px ${scheme}: the heat ramp shares no colour with the rating ramp (heat ${hv.heat.join(' ')}; ratings ${hv.rate.join(' ')})`);
        // Layers menu: All off clears every layer, All on restores them, and the Key titles its layer lines.
        await page.click('#laybtn');
        await page.click('#laypop [data-layers="none"]');
        const off = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, key: document.querySelectorAll('#layl li:not(.lkh)').length, on: document.querySelectorAll('#laypop [data-layer][aria-checked=true]').length }));
        await page.click('#laypop [data-layers="all"]');
        const on = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, rows: document.querySelectorAll('#laypop [data-layer]').length, on: document.querySelectorAll('#laypop [data-layer][aria-checked=true]').length, head: (document.querySelector('#layl .lkh') || {}).textContent }));
        check(off.btn === 'Layers' && off.key === 0 && off.on === 0 && on.on === on.rows && /Layers on the map/.test(on.head || ''), `Map ${w}px ${scheme}: All off clears every layer, All on restores them, the Key titles its layer lines (${off.btn}, ${on.btn}, ${on.head})`);
        await page.click('#laybtn');
      }
      if (name === 'Map' && w >= 1024) {
        // With every layer on, the Depth chip shows at load; it must not sit on the hint box under the map.
        const ov = await page.evaluate(() => { const c = document.getElementById('depthchip'), h = document.querySelector('.hints'); if (!c || c.hidden || !h || getComputedStyle(h).display === 'none') return { skipped: true }; const a = c.getBoundingClientRect(), b = h.getBoundingClientRect(); return { skipped: false, hit: a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top }; });
        check(!ov.skipped && !ov.hit, `Map ${w}px ${scheme}: the Depth chip and the hint box do not overlap (${ov.skipped ? 'one of them is not showing: the check proves nothing' : ov.hit ? 'overlap' : 'clear'})`);
      }
      if (name === 'Map') {
        const dl = await page.evaluate(() => ({ btn: document.getElementById('laylbl').textContent, legend: document.querySelectorAll('#layl li:not(.lkh)').length, rows: document.querySelectorAll('#laypop [data-layer]').length, on: [...document.querySelectorAll('#laypop [data-layer][aria-checked=true]')].length }));
        check(dl.rows >= 9 && dl.on === dl.rows && dl.legend === dl.rows, `Map ${w}px ${scheme}: a bare link opens with every layer on (${dl.btn}, ${dl.on} of ${dl.rows} on, ${dl.legend} legend lines)`);
      }
      if (name === 'Map' && w <= 390) {
        const k = await page.evaluate(() => { const tapH = (b) => { const r = b.getBoundingClientRect().height, a = getComputedStyle(b, '::after'); const ext = a.content !== 'none' && a.position === 'absolute' ? Math.max(0, -parseFloat(a.top) || 0) + Math.max(0, -parseFloat(a.bottom) || 0) : 0; return r + ext; }; const b = document.getElementById('keybtn'); return { h: tapH(b), shown: getComputedStyle(b).display !== 'none', body: !document.getElementById('keypop').hidden, exp: b.getAttribute('aria-expanded'), text: b.textContent, hint: getComputedStyle(document.getElementById('rhint')).display !== 'none' }; });
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
      const sh = await page.evaluate(() => {
        const row = document.querySelector('#sbody .acts'), ic = [...document.querySelectorAll('#sbody .acts .ico')];
        const tap = ic.map(b => { const r = b.getBoundingClientRect(), a = getComputedStyle(b, '::after'), t = parseFloat(a.top); return r.height + (t < 0 ? -t - parseFloat(a.bottom) : 0); });
        const sv = getComputedStyle(ic[0].querySelector('svg'));
        return { n: ic.length, labels: ic.map(b => b.textContent.trim()), minTap: Math.min(...tap), stroke: sv.strokeWidth, fill: sv.fill, rowH: row ? Math.round(row.getBoundingClientRect().height) : 0, creelKey: !!document.querySelector('#sbody .ckey'), dash: /(^|\s)[\u2013-]\s*kept/.test(document.getElementById('sbody').textContent) };
      });
      check(sh.n >= 2 && sh.labels[0] === 'Directions' && sh.minTap >= 44 && parseFloat(sh.stroke) <= 1.5 && sh.fill === 'none' && sh.rowH <= 40, `river sheet: one compact icon row, thin outline icons, 44px to tap (${sh.labels.join(' | ')}; tap ${Math.round(sh.minTap)}px, stroke ${sh.stroke}, fill ${sh.fill}, row ${sh.rowH}px)`);
      check(sh.creelKey && !sh.dash, `river sheet: the creel bars carry a kept and released key, and no row reads as a bare dash before "kept" (key ${sh.creelKey}, dash ${sh.dash})`);
      // Sheets show no source links (2026-10-29): not the section, not the report or creel PDF links. The WDFW link and the notes stay.
      const cw = await page.evaluate(() => { const b = document.getElementById('sbody'); return { srcLinks: b.querySelectorAll('a[href*="theguidesforecast"], a[href*="nwsportsmanmag"], a[href$=".pdf"]').length, heading: /Sources and notes/.test(b.innerText), wdfw: b.querySelectorAll('a[href*="wdfw.wa.gov"]').length }; });
      check(cw.srcLinks === 0 && !cw.heading && cw.wdfw >= 1, `river sheet: no source links or "Sources and notes", the WDFW link stays (${cw.srcLinks} source links, heading ${cw.heading}, ${cw.wdfw} WDFW links)`);
      await page.goto(base + '/index.html?mode=reports&river=columbia', { waitUntil: 'networkidle' });
      const cn = await page.evaluate(() => { const d = document.querySelector('#sbody details.srcs'); return { text: d ? d.textContent : '', links: d ? d.querySelectorAll('a').length : 0 }; });
      check(/Notes/.test(cn.text) && /Sections that reported/.test(cn.text) && cn.links === 0, `river sheet: the Columbia creel note still shows, in a Notes section with no links (${cn.text.slice(0, 60).replace(/\s+/g, ' ')})`);
      // Rules for the river (river-rules.js, 2026-10-29): cards under the creel section and above "Before you go", a checked date, and no link inside.
      const rulesOf = () => page.evaluate(() => {
        const b = document.getElementById('sbody'), hs = [...b.querySelectorAll('h3')], h = hs.find(x => /^Rules for /.test(x.textContent)), sec = h && h.parentElement;
        const at = re => hs.findIndex(x => re.test(x.textContent));
        return { title: h ? h.textContent : '', cards: sec ? sec.querySelectorAll('.row').length : 0, links: sec ? sec.querySelectorAll('a[href]').length : 0, text: sec ? sec.innerText : '',
          order: h ? [at(/^WDFW weekly creel/), at(/^Rules for /), at(/^Before you go/)] : [], advisory: /Confirm this water’s rules on WDFW before you fish/.test(b.innerText) };
      });
      await page.goto(base + '/index.html?mode=reports&river=cowlitz&today=2026-10-29', { waitUntil: 'networkidle' });
      const rl = await rulesOf();
      check(rl.title === 'Rules for Cowlitz River' && rl.cards >= 2 && /Checked Oct 29/.test(rl.text) && rl.links === 0, `river sheet: Cowlitz shows "Rules for Cowlitz River" with ${rl.cards} cards, "Checked Oct 29" and no link inside (${rl.title}, ${rl.links} links)`);
      check(rl.order.length === 3 && rl.order[0] >= 0 && rl.order[0] < rl.order[1] && rl.order[1] < rl.order[2] && rl.advisory, `river sheet: Rules sit under the creel section and above "Before you go", whose WDFW line is unchanged (${rl.order.join(',')})`);
      check(/Release/.test(rl.text) && !/\bopen\b/i.test(rl.text), 'river sheet: a release-only rule carries the Release chip, and the section never says open');
      // A water with nothing in force shows no section: every row past its date (a real file), and one water with its rows removed (intercepted file).
      await page.goto(base + '/index.html?mode=reports&river=cowlitz&today=2027-02-01', { waitUntil: 'networkidle' });
      const rx = await rulesOf();
      check(rx.title === '' && rx.cards === 0 && rx.advisory, `river sheet: once every row is past its date there is no Rules section, and the advisory stays (${rx.title})`);
      const nctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
      const np = await nctx.newPage();
      await np.route('**/river-rules.js', async route => { const res = await route.fetch(); await route.fulfill({ response: res, body: (await res.text()) + "\n;(function(){var R=window.RIVER_RULES;R.ROWS.splice(0,R.ROWS.length,...R.ROWS.filter(function(r){return r.id!=='cowlitz';}));})();\n" }); });
      await np.goto(base + '/index.html?mode=reports&river=cowlitz&today=2026-10-29', { waitUntil: 'networkidle' });
      const rn = await np.evaluate(() => ({ title: document.getElementById('stitle').textContent, rules: [...document.querySelectorAll('#sbody h3')].some(x => /^Rules for /.test(x.textContent)) }));
      await np.goto(base + '/index.html?mode=reports&river=columbia&today=2026-10-29', { waitUntil: 'networkidle' });
      const rc = await np.evaluate(() => [...document.querySelectorAll('#sbody h3')].some(x => /^Rules for /.test(x.textContent)));
      check(/Cowlitz/.test(rn.title) && !rn.rules && rc, `river sheet: a water with no rows shows no Rules section while another still does (cowlitz ${rn.rules}, columbia ${rc})`);
      await nctx.close();
      await page.goto(base + '/index.html?mode=reports&river=cowlitz', { waitUntil: 'networkidle' });
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
// The wide-screen sheet grows with the window (380px at narrow desktops, up to 520px) and the map keeps the tapped river clear of it.
for (const [w, h, lo, hi] of [[1024, 768, 380, 380], [1440, 900, 480, 500], [1920, 1080, 520, 520]]) {
  const wctx = await browser.newContext({ viewport: { width: w, height: h } });
  const wp = await wctx.newPage();
  await wp.goto(base + '/index.html?mode=reports&river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
  await wp.waitForTimeout(700);
  const sw = await wp.evaluate(() => { const s = document.getElementById('sheet').getBoundingClientRect(); const pin = [...document.querySelectorAll('#over .pin[aria-label]')].find(p => /cowlitz/i.test(p.getAttribute('aria-label'))); const r = pin && pin.getBoundingClientRect(); return { w: Math.round(s.width), left: Math.round(s.left), pinX: r ? Math.round(r.left + r.width / 2) : null }; });
  check(sw.w >= lo && sw.w <= hi && sw.pinX !== null && sw.pinX < sw.left, `sheet ${w}px: the side sheet is ${sw.w}px wide (expected ${lo} to ${hi}) and the tapped river's pin (x ${sw.pinX}) sits left of it (x ${sw.left})`);
  await wctx.close();
}
// The opening view fits where the fishing is. On a portrait phone Washington's wide box used to take a third of the screen; the view now opens on the west
// side (Puget Sound, the coast, the Columbia), at least 1.5 times tighter than the whole-state fit, and zooming out still reaches the whole state.
{
  const fctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
  const fp = await fctx.newPage();
  await fp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  await fp.waitForTimeout(800);
  const read = () => fp.evaluate(() => {
    const m = /scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform') || ''), sb = window.GEO.bounds.state, W = innerWidth, H = innerHeight;
    const whole = Math.min(W / (sb[1][0] - sb[0][0]), H / (sb[1][1] - sb[0][1]));
    return { s: m ? +m[1] : null, whole };
  });
  const open = await fp.evaluate(() => 0).then(read);
  for (let i = 0; i < 6; i++) { await fp.click('#zout'); await fp.waitForTimeout(350); }
  await fp.waitForTimeout(500);
  const out = await read();
  check(open.s !== null && open.s >= open.whole * 1.5, `phone opening view: ${open.s} is ${(open.s / open.whole).toFixed(2)} times the whole-state fit (at least 1.5 times; the old whole-state opening was about 1.0)`);
  check(out.s !== null && out.s <= out.whole * 1.0 + 0.02, `phone zoom out: six zoom-outs reach the whole state (scale ${out.s} against the whole-state fit ${out.whole.toFixed(2)})`);
  await fctx.close();
}
// Panning stays inside Washington: zoomed in and dragged hard in every direction, the screen's edges end within a small margin of the state's border.
{
  const pctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const pp = await pctx.newPage();
  await pp.goto(base + '/index.html?layers=none&today=' + today, { waitUntil: 'networkidle' });
  await pp.waitForTimeout(600);
  for (let i = 0; i < 4; i++) { await pp.click('#zin'); await pp.waitForTimeout(450); }
  await pp.waitForTimeout(500);
  const drag = async (dx, dy) => { await pp.mouse.move(640, 450); await pp.mouse.down(); for (let k = 1; k <= 8; k++) await pp.mouse.move(640 + dx * k / 8, 450 + dy * k / 8); await pp.mouse.up(); await pp.waitForTimeout(450); };
  const edges = () => pp.evaluate(() => {
    const m = /translate\(([-\d.]+)[ ,]+([-\d.]+)\)\s*scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform') || '');
    if (!m) return null; const tx = +m[1], ty = +m[2], s = +m[3], sb = window.GEO.bounds.state, W = innerWidth, H = innerHeight;
    const mg = Math.max(sb[1][0] - sb[0][0], sb[1][1] - sb[0][1]) * 0.025;
    return { s, left: -tx / s, right: (W - tx) / s, top: -ty / s, bottom: (H - ty) / s, x0: sb[0][0] - mg, x1: sb[1][0] + mg, y0: sb[0][1] - mg, y1: sb[1][1] + mg, vw: W / s, vh: H / s };
  });
  const bad = [];
  for (const [dx, dy, name] of [[3000, 0, 'right'], [-3000, 0, 'left'], [0, 3000, 'down'], [0, -3000, 'up']]) {
    await drag(dx, dy);
    const e = await edges();
    if (!e) { bad.push(name + ': unreadable'); continue; }
    const tol = 0.6;
    if (e.vw < e.x1 - e.x0 && (e.left < e.x0 - tol || e.right > e.x1 + tol)) bad.push(name + ': x edges ' + e.left.toFixed(1) + '..' + e.right.toFixed(1) + ' outside ' + e.x0.toFixed(1) + '..' + e.x1.toFixed(1));
    if (e.vh < e.y1 - e.y0 && (e.top < e.y0 - tol || e.bottom > e.y1 + tol)) bad.push(name + ': y edges ' + e.top.toFixed(1) + '..' + e.bottom.toFixed(1) + ' outside ' + e.y0.toFixed(1) + '..' + e.y1.toFixed(1));
  }
  check(bad.length === 0, `pan limit: dragged hard right, left, down and up while zoomed in, the screen's edges stay within the state's border plus a small margin (${bad.join('; ') || 'all four held'})`);
  await pctx.close();
}
// Layer-marker labels on the map are the name alone; the rating word stays in the marker's accessible name (and the sheet).
{
  const lctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const lp = await lctx.newPage();
  await lp.goto(base + '/index.html?layers=typical,access,spots,seasons&today=' + today, { waitUntil: 'networkidle' });
  await lp.waitForTimeout(600);
  for (let i = 0; i < 4; i++) { await lp.click('#zin'); await lp.waitForTimeout(450); }
  await lp.waitForTimeout(500);
  const lb = await lp.evaluate(() => {
    const out = [];
    document.querySelectorAll('#over g.omark').forEach(g => { const l = g.nextElementSibling; if (!l || l.tagName !== 'text' || l.style.display === 'none' || !l.textContent.trim()) return; out.push({ vis: l.textContent, aria: g.getAttribute('aria-label') || '' }); });
    return out;
  });
  const worded = lb.filter(x => /\u00b7/.test(x.vis)), lost = lb.filter(x => !/\u00b7/.test(x.aria));
  check(lb.length >= 10 && worded.length === 0 && lost.length === 0, `map labels: ${lb.length} layer-marker labels show the name alone (${worded.length} still carry a rating word), and every marker keeps the word in its accessible name (${lost.length} lost it)`);
  await lctx.close();
}
// Tapping a site in Typical season zooms to a neighbourhood (at most 3 times the state fit, it was 5), keeps its neighbours in frame and the pin left of the sheet.
// A freshwater lake here: a pier or launch inside a marine area fits the whole area instead (see "Marine area focus" below).
{
  const zctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const zp = await zctx.newPage();
  const scaleOf = () => zp.evaluate(() => { const m = /scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform') || ''); return m ? +m[1] : null; });
  await zp.goto(base + '/index.html?mode=typical&today=' + today, { waitUntil: 'networkidle' });
  await zp.waitForTimeout(700);
  const home = await scaleOf();
  await zp.goto(base + '/index.html?mode=typical&site=lake-alice&today=' + today, { waitUntil: 'networkidle' });
  await zp.waitForTimeout(900);
  const zoomed = await scaleOf();
  const ratio = home && zoomed ? zoomed / home : null;
  check(ratio !== null && ratio >= 1.4 && ratio <= 3.05, `Typical site tap: the zoom is ${ratio === null ? 'unreadable' : ratio.toFixed(2)} times the state fit (neighbourhood: 1.4 to 3.05; the old tight view was 5)`);
  await zctx.close();
}
// Fish names and the species list. A chip, the bar label and a sheet row show a short name when the exact one is long; the exact name stays in the
// tooltip and the accessible name. The Typical sheet lists species one line each, Good and Prime open and the rest folded.
{
  const sctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const sp = await sctx.newPage();
  await sp.goto(base + '/index.html?mode=typical&site=les-davis-pier&today=' + today, { waitUntil: 'networkidle' });
  await sp.waitForTimeout(600);
  const fn = await sp.evaluate(() => {
    const chips = [...document.querySelectorAll('#sppanel button')], long = chips.filter(b => b.textContent.trim().length > 18);
    const cut = chips.filter(b => b.title && b.getAttribute('aria-label') === b.title);
    const sec = document.querySelector('#sbody details.sp') && document.querySelector('#sbody details.sp').closest('section');
    const rows = [...document.querySelectorAll('#sbody details.sp')], vis = rows.filter(r => { const f = r.closest('details.moresp'); return !f || f.open; }), sum = vis.map(r => r.querySelector('summary').getBoundingClientRect().height);
    const list = sec ? sec.querySelector('.rows') : null;
    return { chips: chips.length, long: long.map(b => b.textContent.trim()), cut: cut.length, rows: rows.length, shown: vis.length, minSum: Math.min(...sum), fold: !!document.querySelector('#sbody details.moresp'), h: sec ? Math.round(sec.getBoundingClientRect().height) : 0 };
  });
  check(fn.chips > 10 && fn.long.length === 0 && fn.cut >= 3, `species chips: none shows a name over 18 characters, and each shortened one keeps its exact name in the tooltip and accessible name (${fn.chips} chips, long ${JSON.stringify(fn.long)}, shortened ${fn.cut})`);
  await sp.click('#sbody details.moresp > summary');
  const fo = await sp.evaluate(() => { const s = [...document.querySelectorAll('#sbody details.sp summary')].map(x => x.getBoundingClientRect().height); return { n: s.length, min: Math.min(...s) }; });
  check(fo.n >= 6 && fo.min >= 44, `Typical sheet: with the fold open all ${fo.n} species lines are 44px or taller (smallest ${Math.round(fo.min)}px)`);
  check(fn.rows >= 6 && fn.shown <= 3 && fn.fold && fn.minSum >= 44 && fn.h <= 360, `Typical sheet: ${fn.rows} species in one-line rows, only ${fn.shown} visible until the fold opens, each line 44px or taller, the section ${fn.h}px tall (limit 360)`);
  await sctx.close();
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
// Water focus: tapping a river fits it on screen, blurs and dims the rest, keeps the river and its access sites sharp, and Done, Escape or a tap on empty map
// brings the camera back. Run at laptop and phone size; then the deep links, a touch phone, reduced motion and reduced transparency.
{
  const scaleOf = p => p.evaluate(() => +/scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform'))[1]);
  const tapRiver = async (p, id) => {
    const pt = await p.evaluate(id => {
      const path = document.querySelector('#rtap path[data-river="' + id + '"]'), m = path.getScreenCTM(), L = path.getTotalLength();
      const bar = Math.max(document.getElementById('bar').getBoundingClientRect().bottom, document.getElementById('smonth').getBoundingClientRect().bottom);
      for (let f = 0.5; f < 0.97; f += 0.03) { const q = path.getPointAtLength(L * f), x = m.a * q.x + m.e, y = m.d * q.y + m.f; if (x > 20 && x < innerWidth * 0.6 && y > bar + 20 && y < innerHeight - 220) return [x, y]; }
      return null;
    }, id);
    await p.mouse.click(pt[0], pt[1]);
    await p.waitForTimeout(1300);
  };
  // Where the river is and where the free map is, in client pixels: free = below the bar and month card, left of the sheet (wide) or above it (phone).
  const geom = p => p.evaluate(() => {
    const r = document.querySelector('#rsel .casing').getBoundingClientRect(), s = document.getElementById('sheet').getBoundingClientRect();
    const top = Math.max(document.getElementById('bar').getBoundingClientRect().bottom, document.getElementById('smonth').getBoundingClientRect().bottom);
    const wide = innerWidth >= 760, free = { l: 0, t: top, r: wide ? s.left : innerWidth, b: wide ? innerHeight : s.top };
    return { river: { l: r.left, t: r.top, r: r.right, b: r.bottom }, free };
  });
  const inside = g => g.river.l >= g.free.l - 4 && g.river.r <= g.free.r + 4 && g.river.t >= g.free.t - 4 && g.river.b <= g.free.b + 4;
  const fills = g => (g.river.r - g.river.l) >= 0.5 * (g.free.r - g.free.l) || (g.river.b - g.river.t) >= 0.5 * (g.free.b - g.free.t);
  const state = p => p.evaluate(() => {
    const vis = e => e.style.display !== 'none' && e.getClientRects().length, op = e => +getComputedStyle(e).opacity;
    const dim = [...document.querySelectorAll('#over > :not(.infocus)')].filter(vis), sharp = [...document.querySelectorAll('#over > .infocus')].filter(vis);
    return {
      cls: document.getElementById('app').classList.contains('focus-water'),
      dimN: dim.length, dimMax: Math.max(0, ...dim.map(op)), sharpN: sharp.length, sharpMin: Math.min(1, ...sharp.map(op)),
      launches: [...document.querySelectorAll('#over .omark.infocus')].filter(vis).length,
      baseFilter: getComputedStyle(document.getElementById('base')).filter, dimFilter: dim[0] ? getComputedStyle(dim[0]).filter : null, sharpFilter: sharp[0] ? getComputedStyle(sharp[0]).filter : null,
      rselInBase: !!document.getElementById('rsel').closest('#base'), say: (document.getElementById('wfsay') || {}).textContent, title: document.getElementById('stitle').textContent,
      scrim: getComputedStyle(document.getElementById('wfscrim') || document.body).opacity, marked: document.querySelectorAll('.infocus').length
    };
  });
  for (const [w, h] of [[1280, 800], [390, 844]]) {
    const fctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: 'light' });
    const fp = await fctx.newPage(); const ferr = [];
    fp.on('pageerror', e => ferr.push(String(e)));
    fp.on('console', m => { if (m.type() === 'error') ferr.push(m.text()); });
    await fp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
    const s0 = await scaleOf(fp);
    const rc0 = await fp.evaluate(() => document.querySelector('#over .pin[data-id="cowlitz"]').style.getPropertyValue('--rc'));
    const N = await fp.evaluate(() => Object.values(RIVERTAP.siteRiver).filter(r => r === 'cowlitz-river').length);
    const idle = await state(fp);
    check(!idle.cls && idle.marked === 0 && idle.baseFilter === 'none' && idle.scrim === '0', `focus ${w}px: before a tap nothing is focused, marked, blurred or dimmed (${idle.baseFilter}, scrim ${idle.scrim})`);
    await tapRiver(fp, 'cowlitz-river');
    const a = await state(fp), g = await geom(fp);
    check(a.cls && a.title === 'Cowlitz River', `focus ${w}px: tapping the Cowlitz puts the app in water focus (${a.cls}, ${a.title})`);
    check(inside(g) && fills(g), `focus ${w}px: the whole river fits in the free map area and fills it (river ${JSON.stringify(g.river)}, free ${JSON.stringify(g.free)})`);
    if (w < 760) { const sh = await fp.evaluate(() => document.getElementById('sheet').getBoundingClientRect().height / innerHeight); check(sh <= 0.44, `focus ${w}px: on a phone the card takes at most 44 percent of the screen while a river is in focus (${(sh * 100).toFixed(0)} percent), so the whole river has room above it`); }
    check(a.dimN > 0 && a.dimMax <= 0.35, `focus ${w}px: ${a.dimN} other markers and labels compute opacity at most .35 (${a.dimMax})`);
    check(a.sharpN > N && a.sharpMin === 1 && a.launches === N, `focus ${w}px: the river's pin, its ${a.launches} of ${N} launches and their labels compute opacity 1 (${a.sharpN} sharp, min ${a.sharpMin})`);
    check(/blur\(3\.5px\)/.test(a.baseFilter) && /blur\(2px\)/.test(a.dimFilter) && a.sharpFilter === 'none' && !a.rselInBase, `focus ${w}px: the base and the other markers are blurred, the river and its sites are not (${a.baseFilter}, ${a.dimFilter}, ${a.sharpFilter}, river in base ${a.rselInBase})`);
    check(a.scrim === '1' && /^Focused on Cowlitz River, 5 access sites\. Press Escape to leave\.$/.test(a.say), `focus ${w}px: the wash is up and the live region says what happened (${a.scrim}; ${a.say})`);
    check(await fp.evaluate(() => document.querySelector('#over .pin[data-id="cowlitz"]').style.getPropertyValue('--rc')) === rc0, `focus ${w}px: the rating colour is unchanged (${rc0})`);
    const card = await fp.evaluate(() => ({ h3: (document.querySelector('#sbody .wfacc h3') || {}).textContent, n: document.querySelectorAll('#sbody [data-wfsite]').length, kinds: [...document.querySelectorAll('#sbody [data-wfsite] .dt')].map(e => e.textContent), head: (document.querySelector('#sbody .head') || {}).textContent, links: document.querySelectorAll('#sbody .wfacc a').length }));
    check(card.n === N && card.h3 === `Access on this river (${N})` && card.kinds.every(k => /^(Boat launch|Shore access)$/.test(k)) && /Length 203 km \(126 mi\)/.test(card.head) && card.links === 0, `focus ${w}px: the card lists ${card.n} of ${N} access sites with their kind, no links, and the river's length (${card.h3}; ${card.kinds.join(', ')})`);
    if (card.n === 0) { await fctx.close(); continue; }   // nothing to click: the rest of this size would only repeat the failure
    // Moving to a launch keeps the focus and the camera, and the launch sheet offers the way back.
    const sBefore = await scaleOf(fp), tBefore = await fp.evaluate(() => document.getElementById('vp').getAttribute('transform'));
    const first = await fp.evaluate(() => document.querySelector('#sbody [data-wfsite] .nm').textContent);
    await fp.click('#sbody [data-wfsite]');
    await fp.waitForTimeout(700);
    const b = await state(fp), back = await fp.evaluate(() => (document.querySelector('#sbody [data-wfback]') || {}).textContent);
    check(b.cls && b.title === first && back === 'Back to Cowlitz River', `focus ${w}px: a launch opened from the card keeps the focus and shows "Back to Cowlitz River" (${b.title}; ${back})`);
    check(await fp.evaluate(() => document.getElementById('vp').getAttribute('transform')) === tBefore, `focus ${w}px: moving to a launch does not move the camera`);
    await fp.click('#sbody [data-wfback]');
    await fp.waitForTimeout(1000);
    const c = await state(fp), g2 = await geom(fp);
    check(c.cls && c.title === 'Cowlitz River' && inside(g2), `focus ${w}px: Back returns to the river's card with the river still in view (${c.title})`);
    // Escape: the camera returns to where it was before the first focus (not to where the launch step left it).
    await fp.keyboard.press('Escape');
    await fp.waitForTimeout(1000);
    const d = await state(fp), s1 = await scaleOf(fp);
    check(!d.cls && d.marked === 0 && d.scrim === '0' && d.baseFilter === 'none' && Math.abs(s1 / s0 - 1) <= 0.02, `focus ${w}px: Escape ends the focus, clears the marks and the dim, and restores the scale within 2% (${s0.toFixed(3)} -> ${s1.toFixed(3)})`);
    check(/^Left focus on Cowlitz River\.$/.test(d.say) && !(await fp.evaluate(() => document.getElementById('sheet').classList.contains('open'))), `focus ${w}px: leaving is announced (${d.say})`);
    // Done and a tap on empty map end it the same way.
    await tapRiver(fp, 'cowlitz-river');
    await fp.click('#sdone');
    await fp.waitForTimeout(1000);
    const e1 = await state(fp), s2 = await scaleOf(fp);
    check(!e1.cls && e1.marked === 0 && Math.abs(s2 / s0 - 1) <= 0.02, `focus ${w}px: Done ends the focus and restores the scale (${s2.toFixed(3)})`);
    await tapRiver(fp, 'cowlitz-river');
    const empty = await fp.evaluate(() => {
      const g = document.getElementById('sheet').getBoundingClientRect(), wide = innerWidth >= 760;
      for (let y = innerHeight - 40; y > 160; y -= 17) for (let x = 20; x < (wide ? g.left : innerWidth) - 20; x += 23) {
        if (!wide && y > g.top - 10) continue;
        const el = document.elementFromPoint(x, y);
        if (el && !el.closest('#chrome,#sheet,.zoom,#bottom,.hints,.depthchip,[data-river],[data-id],[data-cluster],[data-tsite],[data-ssite],[data-access],[data-season],[data-spot],[data-spotgroup],[data-count]') && el.closest('#map')) return [x, y];
      }
      return null;
    });
    await fp.mouse.click(empty[0], empty[1]);
    await fp.waitForTimeout(1000);
    const e2 = await state(fp), s3 = await scaleOf(fp);
    check(empty && !e2.cls && e2.marked === 0 && Math.abs(s3 / s0 - 1) <= 0.02, `focus ${w}px: a tap on empty map ends the focus and restores the scale (${s3.toFixed(3)})`);
    // Another river, with launches of its own, and one with none: the card says how many.
    const bare = await fp.evaluate(() => { const used = new Set(Object.values(RIVERTAP.siteRiver)), r = RIVERTAP.rivers.find(r => !used.has(r.id) && !['cowlitz', 'columbia', 'lewis', 'wind', 'klickitat', 'kalama', 'skagit', 'washougal'].some(n => r.name.toLowerCase().startsWith(n))); return [r.id, r.name]; });
    for (const [rid, nm] of [['skykomish-river', 'Skykomish River'], bare]) {
      const n2 = await fp.evaluate(r => Object.values(RIVERTAP.siteRiver).filter(x => x === r).length, rid);
      await fp.goto(base + '/index.html?river=' + rid + '&today=' + today, { waitUntil: 'networkidle' });
      await fp.waitForTimeout(1200);
      const o = await state(fp), og = await geom(fp), oc = await fp.evaluate(() => ({ n: document.querySelectorAll('#sbody [data-wfsite]').length, sec: !!document.querySelector('#sbody .wfacc'), h3: (document.querySelector('#sbody .wfacc h3') || {}).textContent }));
      check(o.cls && o.title === nm && oc.n === n2 && (n2 === 0 ? !oc.sec : oc.h3 === `Access on this river (${n2})`) && inside(og), `focus ${w}px: ?river=${rid} opens in focus with ${n2} access sites listed and the river in view (${o.title}; ${oc.n})`);
    }
    // Deep link to a report river: in focus once the page has loaded, the river clear of the bar and the month card, the address bar still says river=cowlitz.
    await fp.goto(base + '/index.html?river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
    await fp.waitForTimeout(1300);
    const l = await state(fp), lg = await geom(fp);
    check(l.cls && /^Focused on Cowlitz River, 5 access sites/.test(l.say) && inside(lg) && /[?&]river=cowlitz(&|$)/.test(await fp.evaluate(() => location.search)), `focus ${w}px: ?river=cowlitz enters focus, fits the river and keeps the link (${l.say})`);
    // Typical season: a tap on a launch of the river focuses the river; the card there words each site's rating.
    const lid = await fp.evaluate(() => Object.keys(RIVERTAP.siteRiver).find(k => RIVERTAP.siteRiver[k] === 'cowlitz-river'));
    await fp.goto(base + '/index.html?mode=typical&site=' + lid + '&today=' + today, { waitUntil: 'networkidle' });
    await fp.waitForTimeout(1300);
    const t = await state(fp), tb = await fp.evaluate(() => (document.querySelector('#sbody [data-wfback]') || {}).textContent), tg = await geom(fp);
    check(t.cls && tb === 'Back to Cowlitz River' && inside(tg), `focus ${w}px: a Typical season launch on the Cowlitz opens in focus with "Back to Cowlitz River" (${t.title}; ${tb})`);
    await fp.click('#sbody [data-wfback]');
    await fp.waitForTimeout(900);
    const tr = await fp.evaluate(() => ({ title: document.getElementById('stitle').textContent, n: document.querySelectorAll('#sbody [data-wfsite]').length, dts: [...document.querySelectorAll('#sbody [data-wfsite] .dt')].map(e => e.textContent), cls: document.getElementById('app').classList.contains('focus-water'), rsel: getComputedStyle(document.getElementById('rsel')).display }));
    check(tr.cls && tr.title === 'Cowlitz River' && tr.n === 5 && tr.dts.every(x => / · (Prime|Good|Fair|Slow|No guidance)$/.test(x)) && tr.rsel !== 'none', `focus ${w}px: in Typical season the river card words each site's rating and the river line shows (${tr.dts.join(' | ')})`);
    check(ferr.length === 0, `focus ${w}px: no page errors (${ferr.join(' | ').slice(0, 160)})`);
    await fctx.close();
  }
  // Dark: a darkening wash. Touch phone: two blurred layers and the markers only dimmed. Reduced motion: no blur, dim at once. Reduced transparency: dim only.
  const dctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: 'dark' });
  const dp = await dctx.newPage();
  await dp.goto(base + '/index.html?river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
  await dp.waitForTimeout(900);
  const dk = await dp.evaluate(() => getComputedStyle(document.getElementById('wfscrim') || document.body).backgroundColor);
  check(/^rgba\(0, 0, 0, 0\.4\d*\)$/.test(dk), `focus dark: the wash is a darkening black (${dk})`);
  await dctx.close();
  const tctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const tp = await tctx.newPage();
  await tp.goto(base + '/index.html?river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
  await tp.waitForTimeout(1100);
  const ts = await state(tp);
  check(ts.cls && /blur\(3\.5px\)/.test(ts.baseFilter) && ts.dimFilter === 'none' && ts.dimMax <= 0.35 && ts.sharpMin === 1, `focus touch phone: the base is blurred and the markers are only dimmed (${ts.baseFilter}, ${ts.dimFilter}, ${ts.dimMax})`);
  await tctx.close();
  for (const mode of ['no-preference', 'reduce', 'transparency']) {
    const mctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, reducedMotion: mode === 'reduce' ? 'reduce' : 'no-preference' });
    const mp = await mctx.newPage();
    if (mode === 'transparency') await (await mctx.newCDPSession(mp)).send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-transparency', value: 'reduce' }] });
    await mp.goto(base + '/index.html?river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
    await mp.waitForTimeout(900);
    const ms = await state(mp), tr = await mp.evaluate(() => ({ scrim: getComputedStyle(document.getElementById('wfscrim') || document.body).transitionDuration, marker: getComputedStyle(document.querySelector('#over > :not(.infocus)')).transitionDuration, base: getComputedStyle(document.getElementById('base')).transitionDuration, heat: getComputedStyle(document.getElementById('heat')).filter }));
    if (mode === 'no-preference') check(/blur\(3\.5px\)/.test(ms.baseFilter) && tr.scrim === '0.2s, 0.2s' && tr.base === '0.2s' && tr.marker === '0.2s, 0.2s', `focus no-preference: blur and dim ease in over 200 ms together (${ms.baseFilter}; scrim ${tr.scrim}, base ${tr.base}, marker ${tr.marker})`);
    if (mode === 'reduce') check(ms.cls && ms.baseFilter === 'none' && ms.dimFilter === 'none' && tr.scrim === '0s' && tr.marker === '0s' && tr.base === '0s' && ms.dimMax <= 0.35 && ms.scrim === '1', `focus reduced motion: no blur, the dim changes at once (scrim ${tr.scrim}, marker ${tr.marker}, base ${tr.base}; dim ${ms.dimMax}; ${ms.baseFilter})`);
    if (mode === 'transparency') check(ms.cls && ms.baseFilter === 'none' && ms.dimFilter === 'none' && ms.dimMax <= 0.35 && /blur\(2\.5px\)/.test(tr.heat), `focus reduced transparency: dim only, no blur on the base or the markers (${ms.baseFilter}, ${ms.dimFilter}, dim ${ms.dimMax}, heat ${tr.heat})`);
    await mctx.close();
  }
  // Marine area focus: the same effect for a WDFW marine area (Marine Area 11, Tacoma - Vashon Island). Entered by tapping a pier or launch of the area on the map
  // (its own sheet opens, the camera fits the whole area) or by tapping the water inside the outline (the sheet is the area's card). Laptop and phone.
  const SITE11 = await (async () => { const pg = await browser.newPage(); await pg.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' }); const r = await pg.evaluate(() => TypicalData.sites.filter(s => s.area === '11').map(s => s.id)); await pg.close(); return r; })();
  const N11 = SITE11.length;
  const areaGeom = p => p.evaluate(() => {
    const line = document.querySelector('#asel .line'), r = line ? line.getBoundingClientRect() : { left: 0, top: 0, right: 0, bottom: 0 }, s = document.getElementById('sheet').getBoundingClientRect();
    const top = Math.max(document.getElementById('bar').getBoundingClientRect().bottom, document.getElementById('smonth').getBoundingClientRect().bottom);
    const wide = innerWidth >= 760, free = { l: 0, t: top, r: wide ? s.left : innerWidth, b: wide ? innerHeight : s.top };
    return { river: { l: r.left, t: r.top, r: r.right, b: r.bottom }, free, shown: !!line && getComputedStyle(document.getElementById('asel')).display !== 'none' };
  });
  const siteXY = (p, id) => p.evaluate(id => {
    const t = /translate\(([-\d.e]+) ([-\d.e]+)\) scale\(([\d.e]+)\)/.exec(document.getElementById('vp').getAttribute('transform')), s = TypicalData.sites.find(q => q.id === id), P = GEO.proj;
    return [(s.lon - P.lon0) * P.kx * +t[3] + +t[1], (P.lat0 - s.lat) * P.k * +t[3] + +t[2]];
  }, id);
  // Wheel-zoom on a site until its marker is drawn and a click on it lands on it; pan first if it is under the bar or off the screen.
  const tapSite = async (p, id) => {
    for (let i = 0; i < 16; i++) {
      const hit = await p.evaluate(id => {
        const g = document.querySelector('#over .omark[data-tsite="' + id + '"]');
        if (!g || g.style.display === 'none') return null;
        const r = g.querySelector('.d').getBoundingClientRect(), x = r.x + r.width / 2, y = r.y + r.height / 2, e = document.elementFromPoint(x, y);
        return e && e.closest('[data-tsite="' + id + '"]') ? [x, y] : null;
      }, id);
      if (hit) { const pre = await scaleOf(p); await p.mouse.click(hit[0], hit[1]); await p.waitForTimeout(1500); return pre; }
      let [x, y] = await siteXY(p, id);
      const vw = p.viewportSize().width;
      const free = await p.evaluate(() => ({ t: Math.max(document.getElementById('bar').getBoundingClientRect().bottom, document.getElementById('smonth').getBoundingClientRect().bottom) + 40, b: innerHeight - 140 }));
      if (x < 30 || x > vw - 30 || y < free.t || y > free.b) {
        const tx = vw * 0.4, ty = (free.t + free.b) / 2, sx = vw * 0.6, sy = free.b - 10;
        await p.mouse.move(sx, sy); await p.mouse.down(); await p.mouse.move(sx + (tx - x) / 2, sy + (ty - y) / 2, { steps: 4 }); await p.mouse.move(sx + (tx - x), sy + (ty - y), { steps: 4 }); await p.mouse.up();
        await p.waitForTimeout(200);
        [x, y] = await siteXY(p, id);
      }
      await p.mouse.move(x, y); await p.mouse.wheel(0, -300); await p.waitForTimeout(350);
    }
    return 0;
  };
  // A point in an area's water that no pin, label or river takes, after zooming in on the area.
  const tapWater = async (p, id) => {
    const c = await p.evaluate(id => { const r = document.querySelector('#atap path[data-area="' + id + '"]').getBoundingClientRect(); return [(r.left + r.right) / 2, (r.top + r.bottom) / 2]; }, id);
    await p.mouse.move(c[0], c[1]);
    for (let i = 0; i < 6; i++) { await p.mouse.wheel(0, -300); await p.waitForTimeout(60); }
    await p.waitForTimeout(500);
    const pt = await p.evaluate(id => {
      const bar = document.getElementById('smonth').getBoundingClientRect().bottom + 20, sh = document.getElementById('sheet').getBoundingClientRect();
      const r = document.querySelector('#atap path[data-area="' + id + '"]').getBoundingClientRect();
      const x0 = Math.max(r.left, 4), x1 = Math.min(r.right, innerWidth - 4), y0 = Math.max(r.top, bar), y1 = Math.min(r.bottom, innerHeight - 100), hits = [];
      for (let y = y0; y < y1; y += 9) for (let x = x0; x < x1; x += 9) { const e = document.elementFromPoint(x, y); if (e && e.closest('[data-area="' + id + '"]')) hits.push([x, y]); }
      const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
      hits.sort((a, b) => Math.hypot(a[0] - cx, a[1] - cy) - Math.hypot(b[0] - cx, b[1] - cy));
      return hits[0] || null;
    }, id);
    if (!pt) return 0;
    const pre = await scaleOf(p);
    await p.mouse.click(pt[0], pt[1]); await p.waitForTimeout(1500);
    return pre;
  };
  const areaState = p => p.evaluate(() => ({
    kind: document.getElementById('app').getAttribute('data-focus'), title: document.getElementById('stitle').textContent, say: document.getElementById('wfsay').textContent,
    sharp11: [...document.querySelectorAll('#over .omark.infocus, #over .pin.infocus[data-id]')].filter(e => e.style.display !== 'none' && e.getClientRects().length).length
  }));
  for (const [w, h] of [[1280, 800], [390, 844]]) {
    const actx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: 'light' });
    const ap = await actx.newPage(); const aerr = [];
    ap.on('pageerror', e => aerr.push(String(e)));
    ap.on('console', m => { if (m.type() === 'error') aerr.push(m.text()); });
    try {
      await ap.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
      const idle = await ap.evaluate(() => ({ kind: document.getElementById('app').getAttribute('data-focus'), hit: document.querySelectorAll('#atap path').length, area11: !!document.querySelector('#atap path[data-area="11"]'), inBase: !!document.querySelector('#base #atap'), beforeRivers: !!document.getElementById('atap') && !!(document.getElementById('atap').compareDocumentPosition(document.getElementById('rtap')) & Node.DOCUMENT_POSITION_FOLLOWING) }));
      check(idle.kind === null && idle.hit === 16 && idle.area11 && idle.inBase && idle.beforeRivers, `marine ${w}px: before a tap there is no focus, and 16 hit polygons sit in the base map under the rivers' own hit paths (${JSON.stringify(idle)})`);
      // (a) a pier of the area
      const sPre = await tapSite(ap, 'les-davis-pier');   // the scale just before the tap is what Escape must restore
      const tapped = sPre > 0;
      check(tapped, `marine ${w}px: Les Davis Pier can be tapped on the map`);
      if (!tapped) throw new Error('there is no pier to tap, the rest of this size would only repeat the failure');
      const a = await state(ap), k = await areaState(ap), g = await areaGeom(ap);
      check(a.cls && k.kind === 'area' && k.title === 'Les Davis Pier', `marine ${w}px: tapping Les Davis Pier puts the app in area focus and keeps the pier's own sheet (${k.kind}; ${k.title})`);
      check(/^Focused on Marine Area 11, Tacoma - Vashon Island, 8 piers and launches\. Press Escape to leave\.$/.test(k.say) && N11 === 8, `marine ${w}px: the live region says what happened (${k.say})`);
      check(g.shown && inside(g) && fills(g), `marine ${w}px: the whole of Marine Area 11 fits in the free map area and fills it (outline ${JSON.stringify(g.river)}, free ${JSON.stringify(g.free)})`);
      if (w < 760) { const sh = await ap.evaluate(() => document.getElementById('sheet').getBoundingClientRect().height / innerHeight); check(sh <= 0.44, `marine ${w}px: on a phone the card takes at most 44 percent of the screen (${(sh * 100).toFixed(0)} percent)`); }
      check(a.dimN > 0 && a.dimMax <= 0.35, `marine ${w}px: ${a.dimN} other markers and labels compute opacity at most .35 (${a.dimMax})`);
      check(k.sharp11 === N11 && a.sharpN > N11 && a.sharpMin === 1, `marine ${w}px: the area's ${k.sharp11} of ${N11} sites, their labels and pins compute opacity 1 (${a.sharpN} sharp, min ${a.sharpMin})`);
      const sel = await ap.evaluate(() => { const p = document.querySelector('#over .pin.sel[data-id="les-davis-pier"]'); return p ? { cls: p.classList.contains('infocus'), op: +getComputedStyle(p).opacity } : null; });
      check(sel && sel.cls && sel.op === 1, `marine ${w}px: the tapped pier's pin is sharp and marked as the selected one (${JSON.stringify(sel)})`);
      check(/blur\(3\.5px\)/.test(a.baseFilter) && a.sharpFilter === 'none' && !(await ap.evaluate(() => !document.getElementById('asel') || !!document.getElementById('asel').closest('#base'))), `marine ${w}px: the base map is blurred and the outline is not (${a.baseFilter})`);
      check(a.scrim === '1', `marine ${w}px: the wash is up (${a.scrim})`);
      const site = await ap.evaluate(() => ({ back: (document.querySelector('#sbody [data-wfback]') || {}).textContent, h3: [...document.querySelectorAll('#sbody .wfacc h3')].map(e => e.textContent), n: document.querySelectorAll('#sbody .wfacc [data-wfsite]').length, self: [...document.querySelectorAll('#sbody .wfacc [data-wfsite] .nm')].some(e => e.textContent === 'Les Davis Pier') }));
      check(site.back === 'Back to Marine Area 11' && site.h3.join() === 'In Marine Area 11' && site.n === N11 - 1 && !site.self, `marine ${w}px: the pier's sheet offers "Back to Marine Area 11" and lists the other ${site.n} of ${N11 - 1} sites, not itself (${site.h3.join()})`);
      const rc = await ap.evaluate(() => document.querySelector('#over .pin[data-id="les-davis-pier"]').style.getPropertyValue('--rc'));
      check(/^var\(--(prime|good|fair|slow|unrated)\)$/.test(rc), `marine ${w}px: the pin keeps its rating colour (${rc})`);
      // Back to the area's card, then a site from the card.
      await ap.click('#sbody [data-wfback]');
      await ap.waitForTimeout(1000);
      const card = await ap.evaluate(() => ({
        title: document.getElementById('stitle').textContent, head: [...document.querySelectorAll('#sbody .head p')].map(e => e.textContent), h3: [...document.querySelectorAll('#sbody h3')].map(e => e.textContent),
        n: document.querySelectorAll('#sbody [data-wfsite]').length, kinds: [...document.querySelectorAll('#sbody [data-wfsite] .dt')].map(e => e.textContent), rows: document.querySelectorAll('#sbody details.sp').length,
        hrefs: [...document.querySelectorAll('#sbody a')].map(e => e.href), text: document.getElementById('sbody').textContent, tide: (document.querySelector('#sbody .tidenow') || {}).textContent, back: !!document.querySelector('#sbody [data-wfback]')
      }));
      check(card.title === 'Marine Area 11' && card.head[0] === 'Tacoma - Vashon Island' && /^\d+ pier/.test(card.head[1]) && /8 piers/.test(card.head[1]), `marine ${w}px: Back opens the area's card, "Marine Area 11" over its title and how many sites it holds (${card.head.join(' | ')})`);
      check(card.n === N11 && card.h3.includes(`Piers and launches in this area (${N11})`) && card.kinds.every(x => /^(Pier|Boat launch|Shore access) · (Prime|Good|Fair|Slow|No guidance)$/.test(x)) && !card.back, `marine ${w}px: the card lists ${card.n} of ${N11} sites by kind and rating word (${card.kinds.slice(0, 3).join(', ')})`);
      check(card.h3.includes('In season now') && card.rows >= 3 && card.h3.includes('Tides') && /ft and (rising|falling)/.test(card.tide || '') && card.h3.includes('Before you go'), `marine ${w}px: the card has In season now (${card.rows} species rows), Tides and Before you go (${card.h3.join(' | ')})`);
      check(card.hrefs.length === 2 && card.hrefs.every(x => /^https:\/\/wdfw\.wa\.gov\//.test(x)) && !/220-311|WAC|boundar|source/i.test(card.text), `marine ${w}px: the card shows the WDFW rules link and no source label (${card.hrefs.join(' ')})`);
      const first = await ap.evaluate(() => document.querySelector('#sbody [data-wfsite] .nm').textContent);
      const tCard = await ap.evaluate(() => document.getElementById('vp').getAttribute('transform'));
      await ap.click('#sbody [data-wfsite]');
      await ap.waitForTimeout(800);
      const b = await state(ap), kb = await areaState(ap), backBtn = await ap.evaluate(() => (document.querySelector('#sbody [data-wfback]') || {}).textContent);
      check(b.cls && kb.kind === 'area' && kb.title === first && backBtn === 'Back to Marine Area 11', `marine ${w}px: a site opened from the card keeps the focus and shows "Back to Marine Area 11" (${kb.title}; ${backBtn})`);
      check(await ap.evaluate(() => document.getElementById('vp').getAttribute('transform')) === tCard, `marine ${w}px: moving to a site does not move the camera`);
      // Escape: the camera from before the first focus.
      await ap.keyboard.press('Escape');
      await ap.waitForTimeout(1000);
      const d = await state(ap), s1 = await scaleOf(ap);
      check(!d.cls && (await areaState(ap)).kind === null && d.marked === 0 && d.scrim === '0' && d.baseFilter === 'none' && Math.abs(s1 / sPre - 1) <= 0.02, `marine ${w}px: Escape ends the focus, clears the marks and the dim and restores the scale within 2% (${sPre.toFixed(3)} -> ${s1.toFixed(3)})`);
      check(/^Left focus on Marine Area 11\.$/.test(d.say), `marine ${w}px: leaving is announced (${d.say})`);
      // (b) the water of the area: its card opens, then Done, and a tap on empty map end it.
      const preW = await tapWater(ap, '11');
      const okW = preW > 0;
      check(okW, `marine ${w}px: there is a point of open water in Marine Area 11 to tap`);
      if (okW) {
        const w1 = await state(ap), kw = await areaState(ap), gw = await areaGeom(ap);
        check(w1.cls && kw.kind === 'area' && kw.title === 'Marine Area 11' && inside(gw) && fills(gw), `marine ${w}px: tapping the water opens the card and fits the area (${kw.kind}; ${kw.title})`);
        const cw = await ap.evaluate(() => document.querySelectorAll('#sbody [data-wfsite]').length);
        check(cw === N11 && w1.dimMax <= 0.35 && w1.sharpMin === 1, `marine ${w}px: the card lists exactly ${cw} of the ${N11} sites typical.js puts in area 11`);
        await ap.click('#sdone');
        await ap.waitForTimeout(1000);
        const w2 = await state(ap), s2 = await scaleOf(ap);
        check(!w2.cls && w2.marked === 0 && Math.abs(s2 / preW - 1) <= 0.02, `marine ${w}px: Done ends the focus and restores the scale (${s2.toFixed(3)} from ${preW.toFixed(3)})`);
        // Re-enter by the water, then a tap on empty map (land, outside every outline) leaves and restores the camera held before that first focus.
        const preW2 = await tapWater(ap, '11');
        const empty = await ap.evaluate(() => {
          const g = document.getElementById('sheet').getBoundingClientRect(), wide = innerWidth >= 760;
          for (let y = innerHeight - 40; y > 200; y -= 17) for (let x = 20; x < (wide ? g.left : innerWidth) - 20; x += 23) {
            if (!wide && y > g.top - 10) continue;
            const el = document.elementFromPoint(x, y);
            if (el && !el.closest('#chrome,#sheet,.zoom,#bottom,.hints,.depthchip,[data-river],[data-id],[data-cluster],[data-tsite],[data-ssite],[data-access],[data-season],[data-spot],[data-spotgroup],[data-count],[data-area]') && el.closest('#map')) return [x, y];
          }
          return null;
        });
        await ap.mouse.click(empty[0], empty[1]);
        await ap.waitForTimeout(1000);
        const w3 = await state(ap), s3 = await scaleOf(ap);
        check(!!empty && preW2 > 0 && !w3.cls && w3.marked === 0 && Math.abs(s3 / preW2 - 1) <= 0.02, `marine ${w}px: a tap on empty map (land) ends the focus and restores the scale within 2% (${preW2.toFixed(3)} -> ${s3.toFixed(3)})`);
      }
      // (c) the deep link that already exists reaches the same focus.
      await ap.goto(base + '/index.html?mode=typical&site=les-davis-pier&today=' + today, { waitUntil: 'networkidle' });
      await ap.waitForTimeout(1300);
      const dl = await areaState(ap), dg = await areaGeom(ap);
      check(dl.kind === 'area' && dl.title === 'Les Davis Pier' && inside(dg) && /[?&]site=les-davis-pier(&|$)/.test(await ap.evaluate(() => location.search)) && !/river=/.test(await ap.evaluate(() => location.search)), `marine ${w}px: ?mode=typical&site=les-davis-pier opens in area focus, fits the area and keeps the link (${dl.kind})`);
      // A freshwater site does not enter area focus; a river tap still enters river focus.
      await ap.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
      const fresh = await ap.evaluate(() => { const used = new Set(Object.keys(RIVERTAP.siteRiver)); return TypicalData.sites.filter(s => s.area === null && s.county === 'King' && !used.has(s.id) && s.kind !== 'pier').map(s => s.id)[0]; });
      const tf = (await tapSite(ap, fresh)) > 0;
      const f1 = await areaState(ap), f2 = await ap.evaluate(() => document.getElementById('app').classList.contains('focus-water'));
      check(tf && f1.kind === null && !f2 && f1.title.length > 0 && await ap.evaluate(() => document.getElementById('sheet').classList.contains('open')), `marine ${w}px: tapping a freshwater site (${fresh}) opens its sheet and does not enter area focus (${f1.kind}; ${f1.title})`);
      await ap.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
      await tapRiver(ap, 'cowlitz-river');
      const rv = await state(ap), rk = await areaState(ap);
      check(rv.cls && rk.kind === 'river' && rv.title === 'Cowlitz River' && /^Focused on Cowlitz River, 5 access sites/.test(rv.say), `marine ${w}px: a river tap still enters river focus (${rk.kind}; ${rv.title})`);
      check(aerr.length === 0, `marine ${w}px: no page errors (${aerr.join(' | ').slice(0, 160)})`);
    } catch (e) { check(false, `marine ${w}px: the checks stopped on an error: ${String(e.message).split('\n')[0]}`); }
    await actx.close();
  }
  // Reduced motion: the area's dim changes at once and there is no blur, like a river's.
  {
    const rctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, reducedMotion: 'reduce' });
    const rp = await rctx.newPage();
    await rp.goto(base + '/index.html?mode=typical&site=les-davis-pier&today=' + today, { waitUntil: 'networkidle' });
    await rp.waitForTimeout(900);
    const rs = await state(rp), rk = await areaState(rp), rt = await rp.evaluate(() => ({ scrim: getComputedStyle(document.getElementById('wfscrim')).transitionDuration, marker: getComputedStyle(document.querySelector('#over > :not(.infocus)')).transitionDuration, base: getComputedStyle(document.getElementById('base')).transitionDuration }));
    check(rk.kind === 'area' && rs.baseFilter === 'none' && rs.dimFilter === 'none' && rt.scrim === '0s' && rt.marker === '0s' && rt.base === '0s' && rs.dimMax <= 0.35 && rs.scrim === '1', `marine reduced motion: no blur, the dim changes at once (scrim ${rt.scrim}, marker ${rt.marker}, base ${rt.base}; dim ${rs.dimMax}; ${rs.baseFilter})`);
    await rctx.close();
  }
}
// Motion (docs/design/motion-spec.md). With reduced motion emulated the sheet, the popovers and the disclosures change at once, and the computed styles say so;
// with no preference the same elements move. Each number is read from a rule, then the popover is watched: after two frames it is part-way through its fade.
for (const motion of ['reduce', 'no-preference']) {
  const rm = motion === 'reduce';
  const mctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, reducedMotion: motion });
  const mp = await mctx.newPage(); const merr = [];
  mp.on('pageerror', e => merr.push(String(e)));
  await mp.goto(base + '/index.html?mode=reports&river=cowlitz&today=' + today, { waitUntil: 'networkidle' });
  const open = await mp.evaluate(() => { const s = document.getElementById('sheet'), g = (el, p) => getComputedStyle(el)[p], r = document.querySelector('#over .pin.sel .ring'), pn = document.querySelector('#over .pin.sel .pin-s');
    return { isOpen: s.classList.contains('open'), dur: g(s, 'transitionDuration'), ease: g(s, 'transitionTimingFunction'), ring: r ? g(r, 'animationName') : null, lift: pn ? g(pn, 'translate') : null }; });
  check(open.isOpen && open.dur === (rm ? '0s' : '0.28s') && (rm || /cubic-bezier\(0\.2, 0\.8, 0\.2, 1\)/.test(open.ease)), `motion ${motion}: the open sheet's transition is ${rm ? 'none' : '280 ms ease-out'} (${open.dur} ${open.ease})`);
  check(open.ring === (rm ? 'none' : 'pin-ring') && open.lift === (rm ? 'none' : '0px -2px'), `motion ${motion}: the selected pin ${rm ? 'has no ring pulse and does not lift' : 'pulses a ring once and lifts 2px'} (${open.ring}, ${open.lift})`);
  await mp.click('#sdone');
  const shut = await mp.evaluate(() => { const s = document.getElementById('sheet'), c = getComputedStyle(s); return { closed: !s.classList.contains('open'), dur: c.transitionDuration, ease: c.transitionTimingFunction }; });
  check(shut.closed && shut.dur === (rm ? '0s' : '0.2s, 0s') && (rm || /cubic-bezier\(0\.4, 0, 1, 1\)/.test(shut.ease)), `motion ${motion}: closing the sheet is ${rm ? 'instant' : 'shorter (200 ms) and eases in'} (${shut.dur} ${shut.ease})`);
  await mp.waitForTimeout(400);
  await mp.click('#listbtn');
  const rise = await mp.evaluate(() => { const b = document.getElementById('sbody'), k = b.children[1] || b.firstElementChild; return { cls: b.classList.contains('rise'), name: getComputedStyle(k).animationName, delay: getComputedStyle(k).animationDelay }; });
  check(rise.name === (rm ? 'none' : 'rise') && (rm || (rise.cls && rise.delay === '0.12s')), `motion ${motion}: the opened sheet's blocks ${rm ? 'do not rise' : 'rise one after another'} (${rise.name}, second block delay ${rise.delay})`);
  await mp.waitForTimeout(750);
  check(await mp.evaluate(() => !document.getElementById('sbody').classList.contains('rise')), `motion ${motion}: the rise class comes off again, so a re-render of the same sheet stays still`);
  const pop = await mp.evaluate(() => new Promise(done => {
    const b = document.getElementById('laybtn'), p = document.getElementById('laypop');
    b.click();
    const opened = !p.hidden;
    // Read straight after the click: the transition starts at this style update and the panel is still at its first frame, so the opacity is below 1 only if a transition ran.
    const mid = +getComputedStyle(p).opacity, dur = getComputedStyle(p).transitionDuration;
    const runs = p.getAnimations().filter(a => a.transitionProperty).map(a => a.transitionProperty + ':' + a.effect.getTiming().duration).sort();
    setTimeout(() => {
      const end = +getComputedStyle(p).opacity; b.click();
      const g = document.querySelector('.pop.ghost');
      const o = { opened, mid, end, runs, dur, hiddenNow: p.hidden, ghosts: document.querySelectorAll('.pop.ghost').length, ghostAnim: g ? getComputedStyle(g).animationName : null, ghostIds: document.querySelectorAll('.pop.ghost [id], .pop.ghost[id]').length };
      setTimeout(() => { o.ghostsLater = document.querySelectorAll('.pop.ghost').length; done(o); }, 450);
    }, 400);
  }));
  check(pop.opened && pop.end === 1 && pop.dur === (rm ? '0s' : '0.16s, 0.16s') && (rm ? pop.mid === 1 && pop.runs.length === 0 : (pop.mid < 1 && pop.runs.join() === 'opacity:160,transform:160')), `motion ${motion}: the Layers popover ${rm ? 'is fully visible at its first frame' : 'starts an opacity and a transform transition of 160 ms when it opens'} (first-frame opacity ${pop.mid}, then ${pop.end}; running ${pop.runs.join(' ') || 'none'}; ${pop.dur})`);
  check(pop.hiddenNow && (rm ? pop.ghosts === 0 : (pop.ghosts === 1 && pop.ghostAnim === 'pop-out' && pop.ghostIds === 0 && pop.ghostsLater === 0)), `motion ${motion}: closing the popover ${rm ? 'leaves no exit copy' : 'plays a short exit on an id-free copy that removes itself'}, and the panel itself is hidden at once (${pop.ghosts} copies, ${pop.ghostAnim}, ${pop.ghostIds} ids, ${pop.ghostsLater} later)`);
  const sw = await mp.evaluate(() => { const e = document.querySelector('.layrow .sw'); return [getComputedStyle(e).transitionDuration, getComputedStyle(e, '::after').transitionDuration]; });
  check(sw.every(d => d === (rm ? '0s' : '0.16s')), `motion ${motion}: the Layers switch moves in ${rm ? '0' : '160'} ms (${sw.join(', ')})`);
  await mp.goto(base + '/index.html?mode=typical&site=port-angeles-city-pier&today=' + today, { waitUntil: 'networkidle' });
  const det = await mp.evaluate(() => { const ds = [...document.querySelectorAll('#sbody details.sp')], d = ds[0], pc = () => getComputedStyle(d, '::details-content').transitionDuration;
    const off = pc(); d.open = true; const on = pc(); return { n: ds.length, on, off }; });
  check(det.n >= 6 && det.on === (rm ? '0s' : '0.2s, 0.2s') && det.off === (rm ? '0s' : '0.12s, 0.12s'), `motion ${motion}: a species row's disclosure ${rm ? 'opens and closes at once' : 'opens in 200 ms and closes in 120'} (open ${det.on}, closed ${det.off})`);
  // Heat circles and Depth lines are drawn only from Puget Sound scale; zoom in until they are, then read how they arrived.
  await mp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  for (let i = 0; i < 5; i++) { await mp.click('#zin'); await mp.waitForTimeout(650); }
  const lay = await mp.evaluate(() => { const cs = [...document.querySelectorAll('svg#heat circle')], g = document.getElementById('depthg'), ds = cs.map(c => parseFloat(c.style.animationDelay) || 0);
    return { n: cs.length, anim: cs[0] ? getComputedStyle(cs[0]).animationName : null, maxDelay: Math.max(0, ...ds), depth: g ? getComputedStyle(g).animationName : null }; });
  check(lay.n > 0 && lay.anim === (rm ? 'none' : 'layer-in') && lay.maxDelay <= 150 && lay.depth === (rm ? 'none' : 'layer-fade'), `motion ${motion}: ${lay.n} heat circles and the depth lines ${rm ? 'appear without a fade' : 'fade in, the circles waiting at most 150 ms'} (${lay.anim}, longest wait ${lay.maxDelay} ms, ${lay.depth})`);
  check(merr.length === 0, `motion ${motion}: no page errors (${merr.join(' | ').slice(0, 160)})`);
  await mctx.close();
}
// Depth shading layer (depth-shading.js): image tiles in #vp under the rivers and the NOAA contours, in #base so water focus blurs and dims them.
{
  const SH = (p) => p.evaluate(() => { const g = document.getElementById('shade'); return g ? { n: g.querySelectorAll('image').length, inVp: g.parentNode.id === 'vp', prev: g.previousElementSibling && g.previousElementSibling.id, pe: getComputedStyle(g).pointerEvents, op: +getComputedStyle(g).opacity, f: g.style.getPropertyValue('--shade-f'), anim: getComputedStyle(g).animationName, inBase: !!g.closest('#base'), data: [...g.querySelectorAll('image')].every(i => /^data:image\/webp;base64,/.test(i.getAttribute('href')) && i.getAttribute('preserveAspectRatio') === 'none') } : null; });
  for (const scheme of ['light', 'dark']) {
    const sctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: scheme });
    const sp = await sctx.newPage(); const serr = [], outside = [];
    sp.on('pageerror', e => serr.push(String(e)));
    sp.on('console', m => { if (m.type() === 'error') serr.push(m.text()); });
    sp.on('request', r => { if (!r.url().startsWith(base) && !r.url().startsWith('data:') && !r.url().startsWith('blob:')) outside.push(r.url()); });
    await sp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
    const N = await sp.evaluate(() => window.DEPTHSHADE.tiles.length);
    const a = await SH(sp);
    check(!!a && a.n === N && N >= 20 && a.inVp && a.prev === 'tbase' && a.pe === 'none' && a.data, `shading ${scheme}: a bare link draws ${a && a.n} of ${N} inline image tiles, in #vp right after the base map, taking no taps`);
    check(a && Math.abs(a.op - (scheme === 'dark' ? 0.5 : 0.8)) < 0.01, `shading ${scheme}: opacity ${a && a.op} (the ramp reads at .8 in light and .5 in dark)`);
    // Every tile decodes in this browser at its stated size, and the shading stays on Puget Sound water.
    const dec = await sp.evaluate(() => Promise.all(window.DEPTHSHADE.tiles.map(t => new Promise(ok => { const i = new Image(); i.onload = () => ok(i.naturalWidth === t.px[0] && i.naturalHeight === t.px[1]); i.onerror = () => ok(false); i.src = t.uri; }))));
    check(dec.length === N && dec.every(Boolean), `shading ${scheme}: all ${N} tiles decode at their stated size (${dec.filter(Boolean).length} of ${dec.length})`);
    if (scheme === 'light') {
      const px = await sp.evaluate(async () => {
        const P = window.GEO.proj, S = window.DEPTHSHADE;
        const alphaAt = async (lon, lat) => {
          const x = (lon - P.lon0) * P.kx, y = (P.lat0 - lat) * P.k, hit = S.tiles.filter(t => x >= t.x && x < t.x + t.w && y >= t.y && y < t.y + t.h);
          if (!hit.length) return -1;
          let best = 0;
          for (const t of hit) {
            const im = await new Promise(ok => { const i = new Image(); i.onload = () => ok(i); i.src = t.uri; });
            const c = document.createElement('canvas'); c.width = t.px[0]; c.height = t.px[1]; const g = c.getContext('2d'); g.drawImage(im, 0, 0);
            const a = g.getImageData(Math.min(t.px[0] - 1, Math.floor((x - t.x) / t.w * t.px[0])), Math.min(t.px[1] - 1, Math.floor((y - t.y) / t.h * t.px[1])), 1, 1).data[3];
            best = Math.max(best, a);
          }
          return best;
        };
        const out = {};
        for (const [k, [lo, la]] of Object.entries({ elliott: [-122.40, 47.60], commencement: [-122.485, 47.301], hood: [-122.93, 47.40], whidbey: [-122.345, 47.931], lakeWashington: [-122.255, 47.62], lakeUnion: [-122.335, 47.64], capitolHill: [-122.31, 47.62], strait: [-123.1, 48.18], sanJuan: [-122.9, 48.55] })) out[k] = await alphaAt(lo, la);
        return out;
      });
      check(px.elliott > 200 && px.commencement > 200 && px.hood > 200 && px.whidbey > 200, `shading: water in Elliott Bay, Commencement Bay, Hood Canal and the Whidbey Basin is opaque (${px.elliott}, ${px.commencement}, ${px.hood}, ${px.whidbey})`);
      check(px.lakeWashington <= 0 && px.lakeUnion <= 0 && px.capitolHill <= 0, `shading: Lake Washington, Lake Union and Capitol Hill land are transparent or off the tiles (${px.lakeWashington}, ${px.lakeUnion}, ${px.capitolHill})`);
      check(px.strait === -1 && px.sanJuan === -1, `shading: nothing is drawn over the Strait or the San Juans (${px.strait}, ${px.sanJuan})`);
    }
    // Zoom in: the NOAA contour group is built, and it sits after (over) the shading. At the closest zoom the shading eases down but is still there.
    for (let i = 0; i < 6; i++) { await sp.click('#zin'); await sp.waitForTimeout(450); }
    const z = await sp.evaluate(() => { const g = document.getElementById('shade'), d = document.getElementById('depthg'); return { n: g ? g.querySelectorAll('image').length : 0, depth: !!d, over: !!(g && d && (g.compareDocumentPosition(d) & Node.DOCUMENT_POSITION_FOLLOWING)), s: +/scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform'))[1] }; });
    check(z.depth && z.over && z.n === N, `shading ${scheme}: with the contours drawn they come after the shading in the DOM, so they sit on top (${z.depth ? 'contours' : 'no contours'}, scale ${z.s.toFixed(0)})`);
    for (let i = 0; i < 4; i++) { await sp.click('#zin'); await sp.waitForTimeout(450); }
    const close = await sp.evaluate(() => { const g = document.getElementById('shade'), t = window.DEPTHSHADE.tiles[0], s = +/scale\(([\d.]+)\)/.exec(document.getElementById('vp').getAttribute('transform'))[1]; return { f: g ? parseFloat(g.style.getPropertyValue('--shade-f') || '1') : null, px: Math.max(t.w / t.px[0], t.h / t.px[1]) * s, s, op: g ? +getComputedStyle(g).opacity : null }; });
    check(close.s > 100 && close.f !== null && close.f >= 0.6 && close.f <= 1 && (close.px <= 2.5 ? close.f === 1 : close.f < 1) && close.op > 0.2, `shading ${scheme}: at scale ${close.s.toFixed(0)} a raster pixel is ${close.px.toFixed(1)} CSS px and the strength factor is ${close.f}, so it holds rather than vanishing (opacity ${close.op})`);
    check(outside.length === 0, `shading ${scheme}: no request leaves the page (${outside.slice(0, 3).join(', ')})`);
    check(serr.length === 0, `shading ${scheme}: no page errors (${serr.join(' | ').slice(0, 160)})`);
    await sctx.close();
  }
  // The layer in the menu, the URL and the key.
  const lctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const lp = await lctx.newPage();
  await lp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  await lp.click('#laybtn');
  const m0 = await lp.evaluate(() => ({ rows: document.querySelectorAll('#laypop [data-layer]').length, row: (document.querySelector('#laypop [data-layer="shading"]') || {}).textContent, on: document.querySelector('#laypop [data-layer="shading"]')?.getAttribute('aria-checked'), btn: document.getElementById('laylbl').textContent, q: location.search }));
  check(m0.rows === 9 && /Depth shading/.test(m0.row || '') && m0.on === 'true' && m0.btn === 'Layers · 9' && !/layers=/.test(m0.q), `shading menu: nine layers, "Depth shading" is a row and is on by default (${m0.rows} rows, ${m0.btn})`);
  await lp.click('#laypop [data-layer="shading"]');
  const off = await lp.evaluate(() => ({ shade: !!document.getElementById('shade'), btn: document.getElementById('laylbl').textContent, q: location.search, key: [...document.querySelectorAll('#layl li:not(.lkh)')].length, checked: document.querySelector('#laypop [data-layer="shading"]').getAttribute('aria-checked') }));
  check(!off.shade && off.btn === 'Layers · 8' && /layers=seasons%2Cspots%2Caccess%2Ccounts%2Ctypical%2Cspawn%2Cdepth%2Cheat/.test(off.q) && off.checked === 'false' && off.key === 8, `shading menu: turning it off removes the tiles, says Layers · 8, and the URL lists the other eight (${off.btn}, ${off.q})`);
  await lp.click('#laypop [data-layer="shading"]');
  const on = await lp.evaluate(() => ({ shade: !!document.getElementById('shade'), n: document.querySelectorAll('#shade image').length, btn: document.getElementById('laylbl').textContent, q: location.search }));
  check(on.shade && on.n > 20 && on.btn === 'Layers · 9' && !/layers=/.test(on.q), `shading menu: turning it back on restores the tiles and a link with no layers (${on.n} tiles, ${on.q})`);
  await lp.click('#laypop [data-layers="none"]');
  check(await lp.evaluate(() => !document.getElementById('shade')), 'shading menu: All off removes the tiles');
  await lp.click('#laypop [data-layers="all"]');
  check(await lp.evaluate(() => !!document.getElementById('shade')), 'shading menu: All on draws them again');
  await lp.goto(base + '/index.html?layers=shading&today=' + today, { waitUntil: 'networkidle' });
  const only = await lp.evaluate(() => ({ shade: !!document.getElementById('shade'), depthg: !!document.getElementById('depthg'), chip: !document.getElementById('depthchip').hidden, btn: document.getElementById('laylbl').textContent }));
  check(only.shade && !only.depthg && !only.chip && only.btn === 'Layers · 1', `shading link: ?layers=shading draws the shading alone, with no contours and no depth chip (${only.btn})`);
  await lp.goto(base + '/index.html?layers=none&today=' + today, { waitUntil: 'networkidle' });
  check(await lp.evaluate(() => !document.getElementById('shade')), 'shading link: ?layers=none draws no shading');
  await lp.goto(base + '/index.html?layers=depth&today=' + today, { waitUntil: 'networkidle' });
  check(await lp.evaluate(() => !document.getElementById('shade')), 'shading link: ?layers=depth (the contours without the shading) draws no shading');
  await lp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  await lp.click('#keybtn');
  const key = await lp.evaluate(() => { const li = document.querySelector('#layl li.shadekey'); return li ? { text: li.textContent, ramp: !!li.querySelector('.ramp[role="img"]'), grad: li.querySelector('.ramp').style.background, labels: [...li.querySelectorAll('.rampl span')].map(s => s.textContent), vis: li.getBoundingClientRect().height > 60, n: document.querySelectorAll('#layl li:not(.lkh)').length, rows: document.querySelectorAll('#laypop [data-layer]').length } : null; });
  check(!!key && key.ramp && /linear-gradient/.test(key.grad) && key.labels.join() === '0,30,120,240,480,800' && key.vis && key.n === key.rows, `shading key: a depth ramp legend in feet below low tide (${key && key.labels.join(' ')}), one key line per layer (${key && key.n} of ${key && key.rows})`);
  check(!!key && /not a survey and not sonar/.test(key.text) && /Not for navigation/.test(key.text) && /Puget Sound only/.test(key.text) && /not the Strait, San Juans or coast/.test(key.text) && /CIRES \/ NCEI, doi:10\.25921\/ds9v-ky35/.test(key.text) && /Feet below low tide/.test(key.text), 'shading key: says model not survey not sonar, not for navigation, where it covers, and cites NOAA NCEI CUDEM');
  await lctx.close();
  // Water focus (a river, and a marine area) blurs and dims the base map, shading included.
  for (const [what, q] of [['river', '?river=cowlitz'], ['marine area', '?mode=typical&site=les-davis-pier']]) {
    const fctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: 'light' });
    const fp = await fctx.newPage(); const ferr = [];
    fp.on('pageerror', e => ferr.push(String(e)));
    await fp.goto(base + '/index.html' + q + '&today=' + today, { waitUntil: 'networkidle' });
    await fp.waitForTimeout(900);
    const f = await fp.evaluate(() => { const g = document.getElementById('shade'), b = document.getElementById('base'), sc = document.getElementById('wfscrim'); return { focus: document.getElementById('app').classList.contains('focus-water'), n: g ? g.querySelectorAll('image').length : 0, inBase: !!(g && g.closest('#base')), filter: getComputedStyle(b).filter, scrim: getComputedStyle(sc).opacity, order: !!(b.compareDocumentPosition(sc) & Node.DOCUMENT_POSITION_FOLLOWING) }; });
    check(f.focus && f.n > 20 && f.inBase && /blur\(3\.5px\)/.test(f.filter) && f.scrim === '1' && f.order, `shading focus (${what}): the tiles stay in the blurred base and the scrim lies over them (${f.n} tiles, ${f.filter}, scrim ${f.scrim})`);
    check(ferr.length === 0, `shading focus (${what}): no page errors`);
    await fctx.close();
  }
  // Motion: the tiles fade in with the other layers unless the visitor asked for reduced motion.
  for (const motion of ['reduce', 'no-preference']) {
    const mctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, reducedMotion: motion });
    const mp = await mctx.newPage();
    await mp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
    const a = await SH(mp);
    check(a && a.anim === (motion === 'reduce' ? 'none' : 'layer-fade'), `shading motion ${motion}: the tiles ${motion === 'reduce' ? 'appear without a fade' : 'fade in with the other layers'} (${a && a.anim})`);
    await mctx.close();
  }
  // A phone: the shading is there, nothing scrolls sideways, and the key does not spill.
  const pctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const pp = await pctx.newPage(); const perr = [];
  pp.on('pageerror', e => perr.push(String(e)));
  await pp.goto(base + '/index.html?today=' + today, { waitUntil: 'networkidle' });
  await pp.click('#keybtn');
  const ph = await pp.evaluate(() => { const li = document.querySelector('#layl li.shadekey'), k = document.getElementById('keypop').getBoundingClientRect(); return { n: document.querySelectorAll('#shade image').length, sx: document.documentElement.scrollWidth <= innerWidth, fits: !!li && k.left >= 0 && k.right <= innerWidth + 1, over: li ? li.scrollWidth <= li.clientWidth + 1 : false }; });
  check(ph.n > 20 && ph.sx && ph.fits && ph.over, `shading phone 390px: tiles drawn (${ph.n}), no sideways scroll, the key and its ramp fit the screen`);
  check(perr.length === 0, 'shading phone 390px: no page errors');
  await pctx.close();
}
} finally { await browser.close(); if (server) server.close(); }
console.log(fails.length ? `\n${fails.length} FAILED` : '\nall checks passed');
process.exit(fails.length ? 1 : 0);
