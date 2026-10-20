// Label clipping check alone: NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/labels.pw.js [page.html]
// Without an argument it builds test/browser/site/ (build-site.js) and opens its index.html.
const { chromium } = require('playwright');
const path = require('path');
const page = process.argv[2] ? path.resolve(process.argv[2]) : path.join(require('./build-site')(), 'index.html');
(async () => {
  const b = await chromium.launch();
  let bad = 0;
  for (const [w, h] of [[390, 844], [1440, 900]]) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    await p.goto('file://' + page); await p.waitForTimeout(500);
    for (const dx of [-250, -420, -560]) {
      await p.click('#zfit'); await p.waitForTimeout(450);
      const cx = w / 2, cy = h * 0.6;
      await p.mouse.move(cx, cy); await p.mouse.down(); await p.mouse.move(cx + dx / 2, cy, { steps: 4 }); await p.mouse.move(cx + dx, cy, { steps: 4 }); await p.mouse.up();
      await p.waitForTimeout(150);
      const clipped = await p.evaluate(() => [...document.querySelectorAll('#over > text.lab')].filter(t => t.style.display !== 'none' && t.textContent).map(t => { const r = t.getBoundingClientRect(); return { t: t.textContent, l: Math.round(r.left), r: Math.round(r.right) }; }).filter(o => o.l < 0 || o.r > innerWidth));
      if (clipped.length) { bad++; console.log(`FAIL ${w}px pan ${dx}: ${JSON.stringify(clipped)}`); } else console.log(`ok   ${w}px pan ${dx}`);
    }
  }
  await b.close();
  process.exit(bad ? 1 : 0);
})();
