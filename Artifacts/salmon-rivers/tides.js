// Artifacts/salmon-rivers/tides.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Tides = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* NOAA CO-OPS tide predictions for the map's marine site sheets, read from the bundle tides-data.js
     (window.TIDES, written by scripts/build_tides.py). The page makes no network request. Predictions, not observations; MLLW;
     station local time as NOAA returns it, never converted. Heights are never turned into a rating or a "good time" word. */
  /* Fallback list for Node tests and for a page whose bundle did not load. Names and coordinates verified against NOAA's station
     metadata on 2026-10-26 (STATUS.md). The bundle's own station list replaces it. */
  var STATIONS = [
    { id: '9447130', name: 'Seattle', lat: 47.6026, lon: -122.3393 },
    { id: '9446484', name: 'Tacoma', lat: 47.2667, lon: -122.4133 },
    { id: '9447659', name: 'Everett', lat: 47.98, lon: -122.223 },
    { id: '9444900', name: 'Port Townsend', lat: 48.1112, lon: -122.7597 },
    { id: '9449880', name: 'Friday Harbor', lat: 48.5453, lon: -123.0125 },
    { id: '9449424', name: 'Cherry Point', lat: 48.8627, lon: -122.7586 },
    { id: '9444090', name: 'Port Angeles', lat: 48.125, lon: -123.44 },
    { id: '9443090', name: 'Neah Bay', lat: 48.3707, lon: -124.6016 },
    { id: '9442396', name: 'La Push', lat: 47.9128, lon: -124.6357 },
    { id: '9441102', name: 'Westport', lat: 46.9043, lon: -124.1051 },
    { id: '9440910', name: 'Toke Point', lat: 46.7075, lon: -123.9669 }
  ];
  var DEFAULT = '9447130';

  function stationsOf(bundle) { return bundle && Array.isArray(bundle.stations) && bundle.stations.length ? bundle.stations : STATIONS; }
  function byId(id, list) { list = list || STATIONS; for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return null; }
  function miles(lat, lon, s) {
    var R = 3959, toR = Math.PI / 180, dLat = (s.lat - lat) * toR, dLon = (s.lon - lon) * toR;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat * toR) * Math.cos(s.lat * toR) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
  function nearest(lat, lon, list) {
    var best = null, bd = Infinity;
    (list || STATIONS).forEach(function (s) { var d = miles(lat, lon, s); if (d < bd) { bd = d; best = s; } });
    return best;
  }
  /* The bundled extremes for one station over range.days (ISO dates). null when there is no bundle or no data for the station.
     A day after the bundle's end (or before its start) has no extremes and a note saying so. */
  function days(station, range, bundle) {
    if (!bundle || !station || !bundle.predictions || !Array.isArray(bundle.predictions[station.id])) return null;
    var by = {};
    range.days.forEach(function (d) { by[d] = []; });
    bundle.predictions[station.id].forEach(function (p) {
      var date = p[0].slice(0, 10);
      if (by[date]) by[date].push({ t: p[0].slice(11, 16), type: p[1] === 'H' ? 'H' : 'L', v: +p[2] });
    });
    return range.days.map(function (d) {
      var day = { date: d, extremes: by[d] };
      if (d > bundle.end) day.note = 'Beyond the bundled predictions (through ' + shortDate(bundle.end) + ')';
      else if (d < bundle.start) day.note = 'Before the bundled predictions (from ' + shortDate(bundle.start) + ')';
      return day;
    });
  }
  function fmtTime(hhmm) {
    var h = parseInt(hhmm.slice(0, 2), 10), m = hhmm.slice(3, 5), ap = h < 12 ? 'am' : 'pm';
    h = h % 12; if (h === 0) h = 12;
    return h + ':' + m + ' ' + ap;
  }

  var MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function shortDate(iso) { var d = new Date(iso + 'T00:00:00Z'); return MON[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  function fmtExtreme(e) { return e.type + ' ' + fmtTime(e.t) + ' · ' + e.v.toFixed(1) + ' ft'; }
  function footnote(bundle) { return 'NOAA predictions through ' + shortDate(bundle.end) + ', MLLW, local time. Not observations.'; }

  return { STATIONS: STATIONS, DEFAULT: DEFAULT, stationsOf: stationsOf, byId: byId, miles: miles, nearest: nearest, days: days, fmtTime: fmtTime, fmtExtreme: fmtExtreme, footnote: footnote, shortDate: shortDate };
});
