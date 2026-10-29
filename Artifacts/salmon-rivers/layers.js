// Artifacts/salmon-rivers/layers.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Layers = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Map layers drawn on top of any mode. Nothing here rates anything: seasons are dates, spots are text, counts are counts. */
  var NAMES = ['seasons', 'spots', 'access', 'counts', 'typical', 'spawn', 'depth', 'heat'];
  /* On when a link names no layers: the map opens with Typical season and Spawning drawn as neutral shapes over the reports. */
  var DEFAULT = [];

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

  var DAY = 86400000;
  var MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function day(iso) { return Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10)) / DAY; }
  function short(iso) { return MON[+iso.slice(5, 7) - 1] + ' ' + (+iso.slice(8, 10)); }
  /* Open at any point in that calendar month. */
  function openIn(s, year, month) {
    return day(s.start) <= Date.UTC(year, month, 0) / DAY && day(s.end) >= Date.UTC(year, month - 1, 1) / DAY;
  }
  /* The Week page's two windows, kept: an open season ending within 7 days, or one opening within 14. */
  function tagFor(s, today) {
    var t = day(today), a = day(s.start), b = day(s.end);
    if (a <= t && t <= b && b - t <= 7) return { kind: 'ends', days: b - t, text: b === t ? 'ends today' : 'ends ' + short(s.end) };
    if (a > t && a - t <= 14) return { kind: 'opens', days: a - t, text: 'opens ' + short(s.start) };
    return null;
  }
  function monthLabel(year, month) { return MONTHS[month - 1] + ' ' + year; }

  return { NAMES: NAMES, DEFAULT: DEFAULT, parse: parse, toggle: toggle, keptText: keptText, openIn: openIn, tagFor: tagFor, monthLabel: monthLabel };
});
