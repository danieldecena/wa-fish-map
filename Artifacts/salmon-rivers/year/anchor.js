// Artifacts/salmon-rivers/year/anchor.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.YearAnchor = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Opens the Year row named by the URL hash, so Week can link to ../year/index.html#<season id>.
     The page's own code renders each season as a button with id "row-<season id>" and selects it on click; this file
     only presses that button, so the page's selection state stays the one source of truth. It loads before the page's
     module script runs, so it waits for the rows to appear. Hand-maintained: the Year page's source is not in this repo. */

  /* 'none' no usable hash; 'wait' rows not drawn yet; 'missing' rows drawn but not this one; 'opened' pressed. */
  function open(doc, hash) {
    var id;
    try { id = decodeURIComponent(String(hash || '').replace(/^#/, '')); } catch (e) { return 'none'; }
    if (!id) return 'none';
    var row = doc.getElementById('row-' + id);
    if (!row) return doc.querySelector('[id^="row-"]') ? 'missing' : 'wait';
    if (row.getAttribute('aria-pressed') !== 'true') row.click();
    row.scrollIntoView({ block: 'center' });
    return 'opened';
  }

  function boot(win) {
    var doc = win.document, watcher = null;
    function run() {
      if (watcher) { watcher.disconnect(); watcher = null; }
      if (open(doc, win.location.hash) !== 'wait') return;
      watcher = new win.MutationObserver(function () {
        if (open(doc, win.location.hash) !== 'wait') { watcher.disconnect(); watcher = null; }
      });
      watcher.observe(doc.documentElement, { childList: true, subtree: true });
    }
    run();
    win.addEventListener('hashchange', run);
  }

  if (typeof window !== 'undefined' && window.document && window.MutationObserver) boot(window);
  return { open: open };
});
