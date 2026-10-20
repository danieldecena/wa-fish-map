// Playwright checks for tappable rivers, My location and the left-edge label fix.
// From the repo root: NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/river.pw.js [page.html]
// Without an argument it builds test/browser/site/ (build-site.js) and opens its index.html.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const dir = path.join(__dirname, '..', '..'); // Artifacts/salmon-rivers
const pageFile = process.argv[2] ? path.resolve(process.argv[2]) : path.join(require('./build-site')(), 'index.html');
const url = 'file://' + pageFile;
const shots = path.join(__dirname, 'shots');
fs.mkdirSync(shots, { recursive: true });
let fails = 0, passes = 0;
function check(ok, msg) { if (ok) { passes++; console.log('ok   ' + msg); } else { fails++; console.log('FAIL ' + msg); } }

// Screen point on a river's tap path that is not covered by anything else (chrome, pins, the report rivers' own hit paths).
async function riverPoint(p, id) {
  return p.evaluate((id) => {
    const r = window.RIVERTAP.rivers.find(x => x.id === id);
    const m = /translate\(([-\d.e]+) ([-\d.e]+)\) scale\(([-\d.e]+)\)/.exec(document.querySelector('#vp').getAttribute('transform'));
    const tx = +m[1], ty = +m[2], s = +m[3];
    const nums = r.d.match(/-?\d+(?:\.\d+)?/g).map(Number);
    const mr = document.querySelector('#map').getBoundingClientRect();
    const order = [];
    const n = nums.length / 2 | 0;
    for (let k = 0; k < n; k++) order.push((k + (n >> 1)) % n); // start mid-river
    for (const k of order) {
      const x = nums[2 * k] * s + tx + mr.left, y = nums[2 * k + 1] * s + ty + mr.top;
      if (x < 5 || y < 5 || x > innerWidth - 5 || y > innerHeight - 5) continue;
      const e = document.elementFromPoint(x, y);
      if (e && e.getAttribute && e.getAttribute('data-river') === id) return { x, y };
    }
    return null;
  }, id);
}
async function sheetText(p) { return p.evaluate(() => ({ open: document.querySelector('#sheet').classList.contains('open'), title: document.querySelector('#stitle').textContent, body: document.querySelector('#sbody').innerText })); }
async function zoomOutFully(p) { for (let i = 0; i < 6; i++) { await p.click('#zout'); await p.waitForTimeout(60); } await p.waitForTimeout(200); }

(async () => {
  const b = await chromium.launch();
  const errs = [];
  for (const [tag, w, h, scheme] of [['desk', 1440, 900, 'light'], ['phone', 390, 844, 'dark']]) {
    const ctx = await b.newContext({ viewport: { width: w, height: h }, colorScheme: scheme, hasTouch: tag === 'phone' });
    const p = await ctx.newPage();
    p.on('pageerror', e => errs.push(tag + ': ' + e.message));
    p.on('console', m => { if (m.type() === 'error') errs.push(tag + ': ' + m.text()); });
    await p.goto(url); await p.waitForTimeout(500);
    await p.evaluate(() => { try { localStorage.removeItem('wafish.me'); } catch (e) {} });
    await p.reload(); await p.waitForTimeout(500);

    check(await p.evaluate(() => !document.querySelector('#rhint').hidden && /Tap any river/.test(document.querySelector('#rhint').textContent)), tag + ': river hint shown in Recent reports');
    check(await p.evaluate(() => document.querySelectorAll('#rtap path[data-river]').length === window.RIVERTAP.rivers.length), tag + ': one hit path per river');
    check(await p.evaluate(() => { const a = [...document.querySelector('#vp').children]; const rt = a.indexOf(document.querySelector('#rtap')); return rt >= 0 && a.filter(n => n.classList && n.classList.contains('hl')).every(n => a.indexOf(n) > rt); }), tag + ': #rtap is below every .hl group');

    // 1. A non-report river with a gauge: Chehalis.
    let pt = await riverPoint(p, 'chehalis-river');
    if (!pt) { await zoomOutFully(p); pt = await riverPoint(p, 'chehalis-river'); }
    check(!!pt, tag + ': found an uncovered point on the Chehalis');
    if (pt) {
      await p.mouse.click(pt.x, pt.y); await p.waitForTimeout(500);
      const s = await sheetText(p);
      check(s.open && s.title === 'Chehalis River', tag + ': tapping the Chehalis opens its river sheet (' + s.title + ')');
      check(/No recent catch report for this river\./.test(s.body), tag + ': "No recent catch report"');
      check(/Typical flow in \w+/.test(s.body) && /Usually [\d,.]+–[\d,.]+ cfs; median [\d,.]+ cfs/.test(s.body), tag + ': typical flow with a cfs range');
      check(/USGS .+, \d{4}–\d{4} records/.test(s.body), tag + ': gauge and record years');
      const usgs = await p.evaluate(() => [...document.querySelectorAll('#sbody a')].filter(a => /Today’s flow on USGS/.test(a.textContent)).map(a => [a.href, a.target, a.rel]));
      check(usgs.length === 1 && /^https:\/\/waterdata\.usgs\.gov\/monitoring-location\/USGS-\d{8,15}\/$/.test(usgs[0][0]) && usgs[0][1] === '_blank' && usgs[0][2] === 'noopener', tag + ': USGS link ' + (usgs[0] || [''])[0]);
      check(/Before you go/.test(s.body) && /WDFW fishing rules and emergency changes/.test(s.body), tag + ': advisory and footer');
      check(!/Best:|Good:|bestMonths|goodMonths/.test(s.body), tag + ': no seasonal timing in the river sheet');
      check(await p.evaluate(() => document.querySelector('#rsel').style.display === '' && document.querySelector('#rsel .line').getAttribute('d').length > 10), tag + ': selected river highlighted');
      await p.screenshot({ path: path.join(shots, `pw-${tag}-river-chehalis.png`) });
      await p.keyboard.press('Escape'); await p.waitForTimeout(350);
      check(await p.evaluate(() => !document.querySelector('#sheet').classList.contains('open') && document.querySelector('#rsel').style.display === 'none'), tag + ': Escape closes the river sheet and removes the highlight');
    }

    // 2. A river with WDFW notices.
    await zoomOutFully(p);
    for (const id of ['stillaguamish-river', 'hoh-river']) {
      let q = await riverPoint(p, id);
      // Adapted for the app tab bar (2026-10-20): the card now sits 56 px lower, so on phones the zoomed-out north edge can be under it.
      // Drag the map down once and look again; nothing else in this check changed.
      if (!q) {
        const cx = w / 2, cy = h * 0.6;
        await p.mouse.move(cx, cy); await p.mouse.down(); await p.mouse.move(cx, cy + 70, { steps: 4 }); await p.mouse.move(cx, cy + 140, { steps: 4 }); await p.mouse.up();
        await p.waitForTimeout(150);
        q = await riverPoint(p, id);
      }
      check(!!q, tag + ': found a point on ' + id);
      if (!q) continue;
      await p.mouse.click(q.x, q.y); await p.waitForTimeout(450);
      const s = await sheetText(p);
      const links = await p.evaluate(() => [...document.querySelectorAll('#sbody a')].filter(a => a.textContent === 'Read the rule on WDFW').map(a => [a.href, a.target, a.rel]));
      check(s.open && /WDFW notices/.test(s.body) && /Posted [A-Z][a-z]{2} \d{1,2}/.test(s.body), tag + ': ' + id + ' shows WDFW notices with a posted date');
      check(links.length >= 1 && links.every(l => /^https:\/\/wdfw\.wa\.gov\//.test(l[0]) && l[1] === '_blank' && l[2] === 'noopener'), tag + ': ' + id + ' links to the WDFW rule');
      if (id === 'hoh-river' && tag === 'phone') await p.screenshot({ path: path.join(shots, `pw-${tag}-river-hoh.png`) });
      if (id === 'stillaguamish-river' && tag === 'desk') await p.screenshot({ path: path.join(shots, `pw-${tag}-river-stilly.png`) });
      await p.click('#sdone'); await p.waitForTimeout(300);
    }
    // A river without a gauge says so (Sol Duc has notices but no gauge in the data).
    {
      let q = await riverPoint(p, 'sol-duc-river');
      // Adapted for the app tab bar, as above: drag the map down once if the river is under the card.
      if (!q) {
        const cx = w / 2, cy = h * 0.6;
        await p.mouse.move(cx, cy); await p.mouse.down(); await p.mouse.move(cx, cy + 70, { steps: 4 }); await p.mouse.move(cx, cy + 140, { steps: 4 }); await p.mouse.up();
        await p.waitForTimeout(150);
        q = await riverPoint(p, 'sol-duc-river');
      }
      if (q) {
        await p.mouse.click(q.x, q.y); await p.waitForTimeout(450);
        const s = await sheetText(p);
        check(/No USGS gauge in WA Fish Map’s river data for this river\./.test(s.body), tag + ': gauge-less river says so');
        await p.click('#sdone'); await p.waitForTimeout(300);
      }
    }
    // A report river's tap path opens its catch-report sheet, not a "no report" sheet.
    {
      await p.click('#zfit'); await p.waitForTimeout(500);
      const q = await riverPoint(p, 'cowlitz-river');
      if (q) {
        await p.mouse.click(q.x, q.y); await p.waitForTimeout(450);
        const s = await sheetText(p);
        check(s.title === 'Cowlitz River' && !/No recent catch report/.test(s.body) && /What’s biting/.test(s.body), tag + ': Cowlitz tap path opens the Cowlitz report sheet');
        await p.click('#sdone'); await p.waitForTimeout(300);
      } else check(true, tag + ': (Cowlitz fully covered by its report line, nothing to route)');
    }

    // 3. My location: towns, persistence, list sort.
    await p.click('#zfit'); await p.waitForTimeout(400);
    await p.click('#mebtn'); await p.waitForTimeout(150);
    check(await p.evaluate(() => !document.querySelector('#mepanel').hidden && document.querySelectorAll('#mepanel [data-town]').length === 14), tag + ': location panel lists 14 towns');
    const small = await p.evaluate(() => [...document.querySelectorAll('#mebtn, #mepanel button, #mecancel')].filter(x => x.offsetParent && x.getBoundingClientRect().height < 44).map(x => x.textContent));
    check(small.length === 0, tag + ': location targets are at least 44 px ' + small.join(','));
    await p.screenshot({ path: path.join(shots, `pw-${tag}-location-panel.png`) });
    await p.click('#mepanel [data-town="0"]'); await p.waitForTimeout(250);
    check(await p.evaluate(() => JSON.parse(localStorage.getItem('wafish.me')).label === 'Seattle'), tag + ': Seattle stored in wafish.me');
    await p.reload(); await p.waitForTimeout(600);
    check(await p.evaluate(() => document.querySelector('#mebtn').textContent === 'My location: Seattle'), tag + ': restored after reload');
    check(await p.evaluate(() => { const a = [...document.querySelector('#over').children]; const y = a.indexOf(document.querySelector('.you')); return a.filter(n => n.classList.contains('pin') || n.classList.contains('lm')).every(n => a.indexOf(n) > y); }), tag + ': You dot is under pins and landmarks');
    // Zoom out so Seattle is on screen (the Recent reports home view is the southwest).
    await zoomOutFully(p);
    check(await p.evaluate(() => { const y = document.querySelector('.you'); const r = y.querySelector('.dot').getBoundingClientRect(); return y.style.display !== 'none' && r.width > 8 && r.left > 0 && r.right < innerWidth; }), tag + ': You dot drawn on screen once Seattle is in view');
    await p.screenshot({ path: path.join(shots, `pw-${tag}-you-dot.png`) });
    await p.click('#zfit'); await p.waitForTimeout(400);
    await p.click('#listbtn'); await p.waitForTimeout(400);
    check(await p.evaluate(() => document.querySelector('#sbody [data-sort="best"]').getAttribute('aria-checked') === 'true'), tag + ': list defaults to Best first');
    await p.click('#sbody [data-sort="near"]'); await p.waitForTimeout(200);
    const rows = await p.evaluate(() => [...document.querySelectorAll('#sbody .lrow .dt')].map(x => x.textContent));
    check(rows.length > 0 && / mi$/.test(rows[0]), tag + ': first row ends in " mi" (' + rows[0] + ')');
    const miles = rows.map(r => +(/· ([\d,]+) mi$/.exec(r) || [0, 'NaN'])[1].replace(',', ''));
    check(miles.every((m, i) => i === 0 || m >= miles[i - 1]), tag + ': Nearest first is ascending ' + miles.join(','));
    await p.click('#sbody .lrow'); await p.waitForTimeout(450);
    check(/About \d+ mi from you|Less than 1 mi from you/.test((await sheetText(p)).body), tag + ': report sheet shows distance');
    await p.click('#sdone'); await p.waitForTimeout(300);

    // 4. Tap mode: precedence over pins, Escape cancels.
    await p.click('#mebtn'); await p.click('#mepanel [data-me="tap"]'); await p.waitForTimeout(100);
    check(await p.evaluate(() => !document.querySelector('#metip').hidden), tag + ': tap-mode instruction shown');
    await p.screenshot({ path: path.join(shots, `pw-${tag}-tapmode.png`) });
    await p.keyboard.press('Escape'); await p.waitForTimeout(100);
    check(await p.evaluate(() => document.querySelector('#metip').hidden), tag + ': Escape cancels tap mode');
    await p.click('#mebtn'); await p.click('#mepanel [data-me="tap"]'); await p.waitForTimeout(100);
    // A pin whose centre really is the top element there (not under the card or legend).
    const pinPt = await p.evaluate(() => {
      for (const n of document.querySelectorAll('.pin[data-id]')) {
        if (n.style.display === 'none') continue;
        const r = n.querySelector('.balloon').getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
        const e = document.elementFromPoint(x, y);
        if (e && e.closest('.pin') === n) return { x, y, id: n.getAttribute('data-id') };
      }
      return null;
    });
    check(!!pinPt, tag + ': found an exposed pin for the tap-mode check');
    await p.mouse.click(pinPt.x, pinPt.y); await p.waitForTimeout(300);
    const st = await p.evaluate(() => ({ open: document.querySelector('#sheet').classList.contains('open'), me: JSON.parse(localStorage.getItem('wafish.me')), tip: document.querySelector('#metip').hidden }));
    check(!st.open && st.me.label === 'Tapped point' && st.tip, tag + ': armed tap on a pin sets the point and opens nothing');
    // Escape order: species panel first.
    await p.click('#mebtn'); await p.click('#mepanel [data-me="tap"]'); await p.click('#spbtn'); await p.waitForTimeout(100);
    await p.keyboard.press('Escape'); await p.waitForTimeout(80);
    check(await p.evaluate(() => document.querySelector('#sppanel').hidden && !document.querySelector('#metip').hidden), tag + ': Escape closes species panel before tap mode');
    await p.keyboard.press('Escape'); await p.waitForTimeout(80);
    check(await p.evaluate(() => document.querySelector('#metip').hidden), tag + ': second Escape cancels tap mode');
    // Back to Seattle for the typical checks.
    await p.click('#mebtn'); await p.click('#mepanel [data-town="0"]'); await p.waitForTimeout(150);

    // 5. Typical season: no river hit-testing, distance on site sheets.
    await p.click('[data-mode="typical"]'); await p.waitForTimeout(800);
    check(await p.evaluate(() => getComputedStyle(document.querySelector('#rtap')).display === 'none' && document.querySelector('#rhint').hidden), tag + ': Typical hides #rtap and the river hint');
    const hit = await p.evaluate(() => {
      const r = window.RIVERTAP.rivers.find(x => x.id === 'chehalis-river');
      const m = /translate\(([-\d.e]+) ([-\d.e]+)\) scale\(([-\d.e]+)\)/.exec(document.querySelector('#vp').getAttribute('transform'));
      const nums = r.d.match(/-?\d+(?:\.\d+)?/g).map(Number);
      for (let k = 0; k < nums.length; k += 2) {
        const x = nums[k] * +m[3] + +m[1], y = nums[k + 1] * +m[3] + +m[2];
        if (x < 10 || y < 200 || x > innerWidth - 10 || y > innerHeight - 200) continue;
        const e = document.elementFromPoint(x, y);
        if (e && !e.closest('.pin,.cluster,#chrome')) return { x, y, tag: e.tagName, river: e.getAttribute('data-river') };
      }
      return null;
    });
    check(!!hit, tag + ': found a Chehalis line point in Typical season');
    if (hit) {
      check(hit.river === null, tag + ': nothing with data-river under the point in Typical');
      await p.mouse.click(hit.x, hit.y); await p.waitForTimeout(400);
      const s = await sheetText(p);
      check(!(s.open && s.title === 'Chehalis River'), tag + ': click on a river line in Typical does not open a river sheet');
    }
    const tid = await p.evaluate(() => { const n = [...document.querySelectorAll('.pin')].find(x => x.style.display !== 'none' && x.getAttribute('data-id')); return n && n.getAttribute('data-id'); });
    await p.evaluate((id) => document.querySelector('.pin[data-id="' + id + '"]').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })), tid);
    await p.waitForTimeout(500);
    check(/About [\d,]+ mi from you|Less than 1 mi from you/.test((await sheetText(p)).body), tag + ': typical site sheet shows distance');
    await p.click('#sdone'); await p.waitForTimeout(300);
    await p.click('[data-mode="reports"]'); await p.waitForTimeout(600);

    // 6. Labels never start off the left edge or run off the right (pan the map so pins cross the left edge).
    for (const dx of [-250, -420, -560]) {
      await p.click('#zfit'); await p.waitForTimeout(450);
      const cx = w / 2, cy = h * 0.6;
      await p.mouse.move(cx, cy); await p.mouse.down(); await p.mouse.move(cx + dx / 2, cy, { steps: 4 }); await p.mouse.move(cx + dx, cy, { steps: 4 }); await p.mouse.up();
      await p.waitForTimeout(150);
      const bad = await p.evaluate(() => [...document.querySelectorAll('#over text.lab')].filter(t => t.style.display !== 'none' && t.parentNode === document.querySelector('#over') && t.textContent).map(t => { const r = t.getBoundingClientRect(); return { t: t.textContent, l: r.left, r: r.right }; }).filter(o => o.l < 0 || o.r > innerWidth));
      check(bad.length === 0, tag + ': no pin label clipped after panning ' + dx + 'px ' + JSON.stringify(bad));
    }
    await p.close();
    await ctx.close();
  }

  // 7. The page still works when rivers-tap.js and rules.js do not load.
  const tmp = path.join(__dirname, 'nofiles');
  fs.mkdirSync(tmp, { recursive: true });
  for (const f of ['geo.js', 'reports.js', 'counts.js', 'creel.js', 'typical.js', 'season.js', 'cluster.js']) fs.copyFileSync(path.join(dir, f), path.join(tmp, f));
  fs.copyFileSync(pageFile, path.join(tmp, 'page.html'));
  const q = await b.newPage({ viewport: { width: 1440, height: 900 } });
  const e2 = [];
  q.on('pageerror', e => e2.push(e.message));
  await q.goto('file://' + path.join(tmp, 'page.html')); await q.waitForTimeout(500);
  const st = await q.evaluate(() => ({ tap: typeof RIVERTAP, rules: typeof Rules, rt: !!document.querySelector('#rtap'), hint: document.querySelector('#rhint').hidden, pins: document.querySelectorAll('.pin[data-id]').length }));
  check(e2.length === 0 && st.tap === 'undefined' && st.rules === 'undefined' && !st.rt && st.hint && st.pins === 8, 'missing rivers-tap.js and rules.js: no errors, no tap paths, hint hidden, pins drawn ' + JSON.stringify(st) + ' ' + e2.join('; '));
  await q.click('[data-mode="typical"]'); await q.waitForTimeout(500);
  check(e2.length === 0, 'missing files: Typical season still runs');

  check(errs.length === 0, 'no page errors ' + errs.join(' | '));
  console.log(`\n${passes} passed, ${fails} failed`);
  await b.close();
  process.exit(fails ? 1 : 0);
})();
