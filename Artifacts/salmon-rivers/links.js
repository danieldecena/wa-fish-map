// Artifacts/salmon-rivers/links.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Links = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* URL state for the map page. read() parses location.search; write() puts the current state back with
     history.replaceState so a shared link opens on the same mode, month, species and sheet. Never pushState:
     Back leaves the site instead of walking through map taps. `today` is carried through but never invented. */
  var MODES = ['reports', 'typical', 'spawning'];
  /* Which keys mean anything in each mode. Typical season has no month control, so month is spawning-only. */
  var KEYS = { reports: ['species', 'river'], typical: ['species', 'site'], spawning: ['month', 'species', 'site'] };
  var DATE = /^\d{4}-\d{2}-\d{2}$/;

  function params(search) {
    return new URLSearchParams(search && search.charAt(0) === '?' ? search.slice(1) : (search || ''));
  }
  function read(search) {
    var p = params(search);
    var mode = p.get('mode'), month = parseInt(p.get('month') || '', 10), today = p.get('today');
    return {
      mode: MODES.indexOf(mode) >= 0 ? mode : null,
      month: month >= 1 && month <= 12 ? month : null,
      species: p.get('species') || null,
      site: p.get('site') || null,
      river: p.get('river') || null,
      today: today && DATE.test(today) ? today : null
    };
  }
  function toQuery(state) {
    var mode = state && MODES.indexOf(state.mode) >= 0 ? state.mode : 'reports';
    var p = new URLSearchParams();
    if (mode !== 'reports') p.set('mode', mode);
    KEYS[mode].forEach(function (k) {
      var v = state[k];
      if (v !== null && v !== undefined && v !== '') p.set(k, String(v));
    });
    if (state && state.today && DATE.test(state.today)) p.set('today', state.today);
    var s = p.toString();
    return s ? '?' + s : '';
  }
  function write(state, history, location) {
    var q = toQuery(state);
    if ((location.search || '') === q) return;
    history.replaceState(null, '', location.pathname + q + (location.hash || ''));
  }

  return { MODES: MODES, KEYS: KEYS, read: read, toQuery: toQuery, write: write };
});
