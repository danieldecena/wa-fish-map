// Local check server: node Artifacts/salmon-rivers/serve.js  ->  http://127.0.0.1:4173/
// Wraps the Map's index.html in the same document skeleton the publisher uses, so default
// styles match the live page. The tab pages (year/, spots/, counts/) carry their own
// doctype and are served as they are, as in the artifact.
const http = require('http'), fs = require('fs'), path = require('path');
const root = __dirname;
const types = { '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.html': 'text/html; charset=utf-8', '.css': 'text/css' };
const head = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}html{scroll-padding-top:env(safe-area-inset-top,0px)}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}img{max-width:100%}[hidden]:not([hidden=until-found i]){display:none!important}</style></head><body>\n';
http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel.endsWith('/') ? rel + 'index.html' : rel);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    if (file === path.join(root, 'index.html')) {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }).end(head + buf + '</body></html>');
    } else {
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }).end(buf);
    }
  });
}).listen(4173, '127.0.0.1');
