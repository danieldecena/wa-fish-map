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

  /* Tides computed in the page: the Neaps engine (tide-predictor.js) on NOAA's harmonic constants (tide-harmonics.js), so no date
     runs out and nothing is fetched. Heights read against MLLW and times in Washington time, as NOAA's own predictions do; test/tide-engine.test.js
     holds them to NOAA's published predictions. A subordinate station predicts from its reference station with NOAA's corrections. */
  var TZ = 'America/Los_Angeles', MS = 60000;
  var laFmt = null;
  function laParts(d) {
    laFmt = laFmt || new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
    var p = {}; laFmt.formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
    return { date: p.year + '-' + p.month + '-' + p.day, hm: p.hour + ':' + p.minute };
  }
  // The instant Washington's local midnight begins on an ISO date: 07:00 or 08:00 UTC, whichever reads as 00:00 there.
  function laMidnight(iso) {
    var y = +iso.slice(0, 4), m = +iso.slice(5, 7) - 1, d = +iso.slice(8, 10);
    for (var h = 7; h <= 8; h++) { var t = new Date(Date.UTC(y, m, d, h)); if (laParts(t).hm === '00:00') return t; }
    return new Date(Date.UTC(y, m, d, 8));
  }
  function engine(H, TP) {
    if (!H || !Array.isArray(H.stations) || !TP || typeof TP.createTidePredictor !== 'function') return null;
    var byStation = {}, cache = {};
    H.stations.forEach(function (s) { byStation[s.id] = s; });
    function model(id) {
      var s = byStation[id]; if (!s) return null;
      var ref = s.harmonics ? s : byStation[s.ref];
      if (!ref || !ref.harmonics) return null;
      cache[ref.id] = cache[ref.id] || TP.createTidePredictor(ref.harmonics, { offset: ref.msl });
      return { p: cache[ref.id], offsets: s.harmonics ? undefined : s.offsets };
    }
    function day(id, iso) {
      var m = model(id); if (!m) return null;
      var start = laMidnight(iso);
      // Two hours either side, so a subordinate station's time correction cannot push a tide out of its own day.
      var ex = m.p.getExtremesPrediction({ start: new Date(start.getTime() - 2 * 60 * MS), end: new Date(start.getTime() + 26 * 60 * MS), offsets: m.offsets });
      return ex.filter(function (x) { return laParts(x.time).date === iso; })
        .map(function (x) { return { t: laParts(x.time).hm, type: x.high ? 'H' : 'L', v: Math.round(x.level * 10) / 10, at: x.time }; });
    }
    // Level at an instant, and whether the water is rising: compared with ten minutes later.
    function now(id, when) {
      var m = model(id); if (!m) return null;
      var a = m.p.getWaterLevelAtTime({ time: when, offsets: m.offsets }), b = m.p.getWaterLevelAtTime({ time: new Date(when.getTime() + 10 * MS), offsets: m.offsets });
      return { v: Math.round(a.level * 10) / 10, rising: b.level > a.level };
    }
    function curve(id, iso) {
      var m = model(id); if (!m) return null;
      var start = laMidnight(iso);
      return m.p.getTimelinePrediction({ start: start, end: new Date(start.getTime() + 24 * 60 * MS), timeFidelity: 900, offsets: m.offsets })
        .map(function (q) { return { at: q.time, v: q.level }; });
    }
    var list = H.stations.filter(function (s) { return !s.refOnly; }).map(function (s) { return { id: s.id, name: s.name, lat: s.lat, lon: s.lon }; });
    return { stations: list, day: day, now: now, curve: curve };
  }

  return { STATIONS: STATIONS, DEFAULT: DEFAULT, stationsOf: stationsOf, byId: byId, miles: miles, nearest: nearest, days: days, fmtTime: fmtTime, fmtExtreme: fmtExtreme, footnote: footnote, shortDate: shortDate, engine: engine, laParts: laParts, laMidnight: laMidnight };
});
