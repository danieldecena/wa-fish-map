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

  return { NAMES: NAMES, parse: parse, toggle: toggle };
});
