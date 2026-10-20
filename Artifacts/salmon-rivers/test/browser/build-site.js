// Builds a local copy of the published app, laid out the way the artifact is: index.html wrapped in a publisher-style
// skeleton, the Map's scripts beside it, and year/, spots/ and counts/ (the outputs of scripts/build_app_tabs.py).
// Used by the *.pw.js scripts here; also runnable alone: node build-site.js [outDir]   (default: test/browser/site, gitignored)
const path = require('path');
const fs = require('fs');

const app = path.join(__dirname, '..', '..'); // Artifacts/salmon-rivers
const SKELETON = ['<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>[hidden]{display:none!important}</style></head><body>', '</body></html>'];
const MAPJS = ['geo.js', 'rivers-tap.js', 'rules.js', 'reports.js', 'counts.js', 'creel.js', 'typical.js', 'season.js', 'cluster.js', 'sites.js'];

function buildSite(out) {
  const site = path.resolve(out || path.join(__dirname, 'site'));
  fs.rmSync(site, { recursive: true, force: true });
  fs.mkdirSync(site, { recursive: true });
  fs.writeFileSync(path.join(site, 'index.html'), SKELETON[0] + fs.readFileSync(path.join(app, 'index.html'), 'utf8') + SKELETON[1]);
  for (const f of MAPJS) fs.copyFileSync(path.join(app, f), path.join(site, f));
  for (const sub of ['year', 'spots', 'counts']) fs.cpSync(path.join(app, sub), path.join(site, sub), { recursive: true });
  return site;
}

module.exports = buildSite;
if (require.main === module) console.log(buildSite(process.argv[2]));
