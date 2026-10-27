// Artifacts/salmon-rivers/layers.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Layers = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Map layers drawn on top of any mode. Nothing here rates anything: seasons are dates, spots are text, counts are counts. */
  var NAMES = ['seasons', 'spots', 'counts'];

  function canon(list) { return NAMES.filter(function (n) { return list.indexOf(n) >= 0; }); }
  function parse(str) { return canon(String(str || '').split(',')); }
  function toggle(list, name) {
    if (NAMES.indexOf(name) < 0) return canon(list);
    return list.indexOf(name) >= 0 ? canon(list.filter(function (n) { return n !== name; })) : canon(list.concat([name]));
  }

  /* The badge on a surveyed river. A river reported as sections plus a combined total is summed from the total only,
     or the sections would be counted twice. A null count means not reported, never zero. */
  function keptText(w) {
    if (!w) return null;
    if (!w.rows.length) return w.noCatch ? '0 kept' : null;
    var all = w.rows.filter(function (r) { return r.section === 'All sections combined'; });
    var known = (all.length ? all : w.rows).filter(function (r) { return r.kept !== null; });
    if (!known.length) return 'Kept not reported';
    return known.reduce(function (n, r) { return n + r.kept; }, 0) + ' kept';
  }

  return { NAMES: NAMES, parse: parse, toggle: toggle, keptText: keptText };
});
