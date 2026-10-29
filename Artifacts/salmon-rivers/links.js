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
  /* Map layers (layers.js) work in every mode. The list is repeated here so links.js stays standalone; test/layers.test.js holds them equal. */
  var LAYERS = ['seasons', 'spots', 'access', 'counts', 'typical', 'spawn', 'depth', 'heat'];
  /* No `layers` in the link means the default set; `layers=none` means every layer off. */
  var DEFAULT_LAYERS = [];
  function layerList(s) { var a = String(s || '').split(','); return LAYERS.filter(function (n) { return a.indexOf(n) >= 0; }); }
  var DATE = /^\d{4}-\d{2}-\d{2}$/;
  /* A real calendar date: the shape matches and the date survives a round trip (2026-02-30 and 2026-13-99 do not). */
  function realDate(s) {
    var m = typeof s === 'string' && DATE.exec(s);
    if (!m) return false;
    var d = new Date(Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)));
    return d.toISOString().slice(0, 10) === s;
  }

  function params(search) {
    return new URLSearchParams(search && search.charAt(0) === '?' ? search.slice(1) : (search || ''));
  }
  function read(search) {
    var p = params(search);
    var mode = p.get('mode'), rawMonth = p.get('month') || '', today = p.get('today');
    var month = /^\d{1,2}$/.test(rawMonth) ? parseInt(rawMonth, 10) : NaN;
    return {
      mode: MODES.indexOf(mode) >= 0 ? mode : null,
      month: month >= 1 && month <= 12 ? month : null,
      species: p.get('species') || null,
      site: p.get('site') || null,
      river: p.get('river') || null,
      today: realDate(today) ? today : null,
      layers: p.has('layers') ? layerList(p.get('layers')) : DEFAULT_LAYERS.slice(),
      spot: p.get('spot') || null,
      season: p.get('season') || null,
      access: p.get('access') || null
    };
  }
  function toQuery(state) {
    if (!state || typeof state !== 'object') return '';
    var mode = MODES.indexOf(state.mode) >= 0 ? state.mode : 'reports';
    var p = new URLSearchParams();
    if (mode !== 'reports') p.set('mode', mode);
    KEYS[mode].forEach(function (k) {
      var v = state[k];
      if (v !== null && v !== undefined && v !== '') p.set(k, String(v));
    });
    var ls = state.layers ? layerList(state.layers.join(',')) : DEFAULT_LAYERS.slice();
    if (!ls.length) { if (DEFAULT_LAYERS.length) p.set('layers', 'none'); }
    else if (ls.join() !== DEFAULT_LAYERS.join()) p.set('layers', ls.join(','));
    // A spot sheet is only reachable with its layer on, so the link carries it only then.
    if (ls.indexOf('spots') >= 0 && state.spot) p.set('spot', String(state.spot));
    if (ls.indexOf('access') >= 0 && state.access) p.set('access', String(state.access));
    // The Seasons layer has its own month outside Spawning, and its sheet; both travel with the layer.
    if (ls.indexOf('seasons') >= 0) {
      if (mode !== 'spawning' && state.month >= 1 && state.month <= 12) p.set('month', String(state.month));
      if (state.season) p.set('season', String(state.season));
    }
    if (realDate(state.today)) p.set('today', state.today);
    var s = p.toString();
    return s ? '?' + s : '';
  }
  function write(state, history, location) {
    var q = toQuery(state);
    if ((location.search || '') === q) return;
    history.replaceState(null, '', location.pathname + q + (location.hash || ''));
  }

  return { MODES: MODES, KEYS: KEYS, LAYERS: LAYERS, DEFAULT_LAYERS: DEFAULT_LAYERS, realDate: realDate, read: read, toQuery: toQuery, write: write };
});
