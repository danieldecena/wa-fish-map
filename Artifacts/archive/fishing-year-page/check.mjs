#!/usr/bin/env node
// Checks the Washington Fishing Year page in Chrome, 400px and 720px wide,
// light and dark, every tab and every river. Fails (exit 1) on:
//   - any text size outside the type scale 28, 17, 15, 14, 13, 12
//   - any text under 4.5:1 contrast
//   - sideways page scroll
//   - a control that is not a 44px tap target (inline text links are exempt)
//   - a console error or a failed request of the page's own files
//
//   node check.mjs                run the whole matrix
//   node check.mjs --shots DIR    also save a full-page screenshot per view
//   node check.mjs --selftest     run the detectors on a known-bad and a
//                                 known-good page, so a green run means something
//
// Needs playwright-core and Chrome. PLAYWRIGHT_CORE and CHROME override the
// default locations.
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_CORE || '/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/playwright-core');
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// The document skeleton the artifact host wraps around the page. Without it
// the page would render in quirks mode and measure differently.
const SKELETON = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}[hidden]{display:none!important}</style></head><body>\n';

const argv = process.argv.slice(2);
const shotsDir = argv.includes('--shots') ? argv[argv.indexOf('--shots') + 1] : null;
if (shotsDir) mkdirSync(shotsDir, { recursive: true });

const GOOD = '<main style="padding:16px"><p style="font:14px/20px sans-serif;color:#1d1d1f;background:#fff;margin:0 0 8px">Plain text on white.</p><button style="min-height:44px;min-width:88px;font:14px/20px sans-serif">Press</button></main>';
const BAD = '<main style="padding:16px"><p style="font:10px/14px sans-serif;color:#aaa;background:#fff;margin:0 0 8px">Small and pale.</p><button style="height:20px;font:14px/20px sans-serif">Press</button><div style="width:900px;height:4px;background:#000"></div></main>';

function serve(pages) {
  const server = createServer((req, res) => {
    const path = req.url.split('?')[0];
    if (pages[path] !== undefined) { res.writeHead(200, { 'content-type': 'text/html' }); res.end(pages[path]); return; }
    if (path === '/data.js') { res.writeHead(200, { 'content-type': 'text/javascript' }); res.end(readFileSync(join(here, 'data.js'))); return; }
    if (path === '/favicon.ico') { res.writeHead(204); res.end(); return; }
    res.writeHead(404); res.end('not found');
  });
  return new Promise(ok => server.listen(0, '127.0.0.1', () => ok(server)));
}

// Runs inside the page. Returns what is wrong; empty lists mean nothing found.
function audit() {
  const SCALE = [28, 17, 15, 14, 13, 12];
  const parse = c => { const m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null; const p = m[1].split(/[ ,\/]+/).filter(Boolean).map(Number); return { r: p[0], g: p[1], b: p[2], a: p[3] === undefined ? 1 : p[3] }; };
  const over = (f, b) => ({ r: f.r * f.a + b.r * (1 - f.a), g: f.g * f.a + b.g * (1 - f.a), b: f.b * f.a + b.b * (1 - f.a), a: 1 });
  const lum = c => { const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const bgOf = el => {
    const stack = [];
    for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c && c.a > 0) { stack.push(c); if (c.a === 1) break; }
    }
    let base = { r: 255, g: 255, b: 255, a: 1 };
    for (let i = stack.length - 1; i >= 0; i--) base = over(stack[i], base);
    return base;
  };
  const cls = el => (el.getAttribute('class') || el.tagName.toLowerCase());
  const bad = [], lows = [], smallTargets = [];
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let t;
  while ((t = walker.nextNode())) {
    if (!t.nodeValue.trim()) continue;
    const el = t.parentElement;
    if (!el || el.closest('script,style,title,desc')) continue;
    const cs = getComputedStyle(el);
    const fs = parseFloat(cs.fontSize);
    const word = t.nodeValue.trim().slice(0, 24);
    if (!SCALE.includes(fs)) bad.push(`${fs}px ${cls(el)} "${word}"`);
    const isSvg = el instanceof SVGElement;
    const fg = parse(isSvg ? cs.fill : cs.color);
    if (!fg) continue;
    let bg = bgOf(isSvg ? el.ownerSVGElement.parentElement : el);
    if (isSvg && el.classList.contains('pin-n')) bg = parse(getComputedStyle(el.previousElementSibling).fill);
    if (isSvg && el.classList.contains('svg-mono')) {
      const snd = document.querySelector('.sound');
      if (snd && parseFloat(el.getAttribute('y')) < snd.getBBox().height) bg = over(parse(getComputedStyle(snd).fill), bg);
    }
    const cr = ratio(over(fg, bg), bg);
    if (cr < 4.5) lows.push(`${cr.toFixed(2)} ${cls(el)} "${word}"`);
  }
  const card = document.querySelector('.stopcard');
  if (card) card.style.display = 'none';
  for (const el of document.querySelectorAll('button,a[href],[role=button],[role=tab]')) {
    if (el.tagName === 'A' && el.parentElement && el.parentElement.tagName === 'P') continue;
    el.scrollIntoView({ block: 'center' });
    const hit = el.querySelector('.hit');
    const r = (hit || el).getBoundingClientRect();
    if (!r.width || !r.height) continue;
    const x = r.left + r.width / 2, y = r.top + r.height / 2;
    const reach = [-21, 21].every(dy => { const e = document.elementFromPoint(x, y + dy); return e && el.contains(e); });
    if (!reach) smallTargets.push(`${Math.round(r.height)}px ${cls(el)} "${(el.textContent || '').trim().slice(0, 20)}"`);
  }
  const de = document.documentElement;
  return { bad, lows, smallTargets, hscroll: de.scrollWidth > de.clientWidth, scrollers: [...document.querySelectorAll('.scroll')].filter(e => e.scrollWidth > e.clientWidth).length };
}

async function selftest(browser) {
  const server = await serve({ '/good': GOOD, '/bad': BAD });
  const port = server.address().port;
  const page = await (await browser.newContext({ viewport: { width: 400, height: 800 } })).newPage();
  const run = async p => { await page.goto(`http://127.0.0.1:${port}${p}`); return page.evaluate(audit); };
  const good = await run('/good'), bad = await run('/bad');
  server.close();
  const fails = [];
  if (good.bad.length || good.lows.length || good.smallTargets.length || good.hscroll) fails.push('known-good page was flagged: ' + JSON.stringify(good));
  if (!bad.bad.length) fails.push('off-scale text not detected');
  if (!bad.lows.length) fails.push('low contrast not detected');
  if (!bad.smallTargets.length) fails.push('small tap target not detected');
  if (!bad.hscroll) fails.push('sideways scroll not detected');
  return fails;
}

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
const sf = await selftest(browser);
if (sf.length) { console.log('SELFTEST FAILED\n  ' + sf.join('\n  ')); await browser.close(); process.exit(1); }
console.log('selftest ok: the checks fire on a bad page and stay quiet on a good one');
if (argv.includes('--selftest')) { await browser.close(); process.exit(0); }

const html = SKELETON + readFileSync(join(here, 'index.html'), 'utf8') + '\n</body></html>\n';
const server = await serve({ '/': html });
const url = `http://127.0.0.1:${server.address().port}/`;
const RIVERS = ['Green', 'Snoqualmie', 'Skykomish', 'Puyallup', 'Skagit'];
const problems = [];
let views = 0;
for (const w of [400, 720]) {
  for (const scheme of ['light', 'dark']) {
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, colorScheme: scheme, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', e => errors.push('pageerror ' + e.message));
    page.on('requestfailed', r => errors.push('request failed ' + r.url()));
    page.on('response', r => { if (r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
    await page.goto(url);
    await page.waitForSelector('.tab');
    for (const tab of ['Calendar', 'River map', 'Migration']) {
      await page.getByRole('tab', { name: tab }).click();
      for (const rv of tab === 'River map' ? RIVERS : [null]) {
        if (rv) await page.locator('.rv', { hasText: rv }).first().click();
        await page.waitForTimeout(200);
        const name = `${w}-${scheme}-${tab.replace(' ', '')}${rv ? '-' + rv : ''}`;
        if (shotsDir) await page.screenshot({ path: join(shotsDir, name + '.png'), fullPage: true });
        const a = await page.evaluate(audit);
        views++;
        for (const k of ['bad', 'lows', 'smallTargets']) for (const x of a[k]) problems.push(`${name} ${k}: ${x}`);
        if (a.hscroll) problems.push(`${name}: page scrolls sideways`);
        if (a.scrollers) problems.push(`${name}: a chart scrolls sideways`);
      }
    }
    for (const e of errors) problems.push(`${w}-${scheme}: ${e}`);
    await ctx.close();
  }
}
server.close();
await browser.close();
const unique = [...new Set(problems)];
console.log(`${views} views checked`);
if (unique.length) { console.log(`${unique.length} problem(s):\n  ` + unique.slice(0, 40).join('\n  ')); process.exit(1); }
console.log('all clear');
