// Frame cost of panning with the river tap paths present vs removed (display:none), same page, same moves. A measurement, not a pass/fail test.
// NODE_PATH=$(npm root -g) node Artifacts/salmon-rivers/test/browser/perf.pw.js
const { chromium } = require('playwright');
const path = require('path');
const page = path.join(require('./build-site')(), 'index.html');
(async () => {
  const b = await chromium.launch();
  for (const [w, h] of [[1440, 900], [390, 844]]) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    await p.goto('file://' + page); await p.waitForTimeout(500);
    const run = async (hide) => p.evaluate(async (hide) => {
      document.querySelector('#rtap').style.display = hide ? 'none' : '';
      const map = document.querySelector('#map'), r = map.getBoundingClientRect();
      const frames = [];
      for (let rep = 0; rep < 3; rep++) for (let i = 0; i < 40; i++) {
        const t0 = performance.now();
        map.dispatchEvent(new WheelEvent('wheel', { deltaY: i < 20 ? -60 : 60, clientX: r.width / 2, clientY: r.height / 2, bubbles: true, cancelable: true }));
        await new Promise(res => requestAnimationFrame(() => requestAnimationFrame(res)));
        frames.push(performance.now() - t0);
      }
      frames.sort((a, b) => a - b);
      return { median: frames[frames.length >> 1].toFixed(1), p90: frames[Math.floor(frames.length * 0.9)].toFixed(1) };
    }, hide);
    const a1 = await run(true), b1 = await run(false), a2 = await run(true), b2 = await run(false);
    console.log(`${w}px  without #rtap: ${JSON.stringify(a1)} ${JSON.stringify(a2)}   with #rtap: ${JSON.stringify(b1)} ${JSON.stringify(b2)}  (ms per 2 frames)`);
  }
  await b.close();
})();
