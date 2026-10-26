// Artifacts/salmon-rivers/tides.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Tides = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* NOAA CO-OPS tide predictions for the Week page and the map's marine site sheets, read from the bundle week/tides-data.js
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

  function getBundle() { return typeof globalThis !== 'undefined' ? globalThis.TIDES : undefined; }
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

  var STORE_KEY = 'wafish.tideStation', ME_KEY = 'wafish.me';
  var DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function dayLabel(iso) { var d = new Date(iso + 'T00:00:00Z'); return DOW[d.getUTCDay()] + ' ' + MON[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  function shortDate(iso) { var d = new Date(iso + 'T00:00:00Z'); return MON[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  function fmtExtreme(e) { return e.type + ' ' + fmtTime(e.t) + ' · ' + e.v.toFixed(1) + ' ft'; }
  function footnote(bundle) { return 'NOAA predictions through ' + shortDate(bundle.end) + ', MLLW, local time. Not observations.'; }
  /* now is 'YYYY-MM-DD HH:MM' in the station's local time; the bundle's t strings compare the same way. */
  function nextIndex(days, now) {
    for (var d = 0; d < days.length; d++) for (var i = 0; i < days[d].extremes.length; i++)
      if (days[d].date + ' ' + days[d].extremes[i].t > now) return { day: d, i: i };
    return null;
  }
  function render(days, now, doc) {
    var table = doc.createElement('table'); table.className = 'tides';
    var cap = doc.createElement('caption'); cap.className = 'sr'; cap.textContent = 'High and low tide predictions, one row per day'; table.appendChild(cap);
    var tbody = doc.createElement('tbody'); table.appendChild(tbody);
    var nx = nextIndex(days, now), today = now.slice(0, 10);
    days.forEach(function (d, di) {
      var tr = doc.createElement('tr'); if (d.date === today) tr.className = 'today';
      var th = doc.createElement('th'); th.setAttribute('scope', 'row'); th.textContent = dayLabel(d.date); tr.appendChild(th);
      var td = doc.createElement('td');
      if (d.note) { td.textContent = d.note; td.className = 'none'; }
      else if (!d.extremes.length) { td.textContent = '—'; td.className = 'none'; }
      d.extremes.forEach(function (e, i) {
        var s = doc.createElement('span');
        s.className = 'ex ' + e.type + (nx && nx.day === di && nx.i === i ? ' next' : '');
        s.textContent = fmtExtreme(e);
        td.appendChild(s);
      });
      tr.appendChild(td); tbody.appendChild(tr);
    });
    return table;
  }
  function readStorage(storage, key) { try { return storage ? storage.getItem(key) : null; } catch (e) { return null; } }
  function writeStorage(storage, key, v) { try { if (storage) storage.setItem(key, v); } catch (e) { /* not persisted */ } }
  /* Washington time, not the device's: every bundled station is in America/Los_Angeles, and the t strings are in that zone. */
  function localNow() {
    var o = {};
    new Intl.DateTimeFormat('en-US', { timeZone: 'America/Los_Angeles', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
      .formatToParts(new Date()).forEach(function (p) { o[p.type] = p.value; });
    return o.year + '-' + o.month + '-' + o.day + ' ' + o.hour + ':' + o.minute;
  }
  function startingStation(storage, list) {
    var stored = byId(readStorage(storage, STORE_KEY) || '', list);
    if (stored) return stored;
    try {
      var me = JSON.parse(readStorage(storage, ME_KEY) || 'null');
      if (me && typeof me.lat === 'number' && typeof me.lon === 'number' && isFinite(me.lat) && isFinite(me.lon)) return nearest(+me.lat, +me.lon, list);
    } catch (e) { /* unreadable: default */ }
    return byId(DEFAULT, list) || list[0];
  }
  /* mount builds <section id="tides"> after afterSection and fills it from the bundle. opts: { bundle, storage, now } — the page passes
     nothing and gets window.TIDES, localStorage and the clock. Synchronous; makes no network request. */
  function mount(root, afterSection, range, today, doc, opts) {
    opts = opts || {};
    var bundle = 'bundle' in opts ? opts.bundle : getBundle();
    var list = stationsOf(bundle);
    var storage;
    if ('storage' in opts) storage = opts.storage;
    else { try { storage = typeof localStorage !== 'undefined' ? localStorage : null; } catch (e) { storage = null; } }
    var real = localNow();
    var now = opts.now || (!today || today === real.slice(0, 10) ? real : today + ' 00:00');
    var sec = doc.createElement('section'); sec.className = 'group'; sec.id = 'tides'; sec.setAttribute('aria-labelledby', 'cap-tides');
    var head = doc.createElement('div'); head.className = 'tides-head';
    var h = doc.createElement('h2'); h.className = 'cap'; h.id = 'cap-tides'; head.appendChild(h);
    var sel = doc.createElement('select'); sel.setAttribute('aria-label', 'Tide station');
    list.forEach(function (s) { var o = doc.createElement('option'); o.setAttribute('value', s.id); o.value = s.id; o.textContent = s.name; sel.appendChild(o); });
    head.appendChild(sel); sec.appendChild(head);
    var panel = doc.createElement('div'); panel.className = 'panel'; sec.appendChild(panel);
    var fine = doc.createElement('p'); fine.className = 'fine'; sec.appendChild(fine);
    root.insertBefore(sec, afterSection.nextSibling);
    var station = startingStation(storage, list);
    sel.value = station.id;
    function show(node) { panel.textContent = ''; panel.appendChild(node); }
    function unavailable(st) {
      var p = doc.createElement('p'); p.className = 'fine';
      p.textContent = 'Tide predictions unavailable right now. ';
      var a = doc.createElement('a'); a.setAttribute('href', 'https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=' + st.id); a.setAttribute('target', '_blank'); a.setAttribute('rel', 'noopener'); a.textContent = 'See NOAA for ' + st.name;
      p.appendChild(a); return p;
    }
    function go(st) {
      h.textContent = 'Tides';
      var ds = days(st, range, bundle);
      if (!ds) { fine.textContent = ''; show(unavailable(st)); return; }
      fine.textContent = footnote(bundle);
      show(render(ds, now, doc));
    }
    sel.addEventListener('change', function () {
      var st = byId(sel.value, list); if (!st) return;
      writeStorage(storage, STORE_KEY, st.id);
      go(st);
    });
    go(station);
    return sec;
  }

  return { STATIONS: STATIONS, DEFAULT: DEFAULT, stationsOf: stationsOf, byId: byId, miles: miles, nearest: nearest, days: days, fmtTime: fmtTime, fmtExtreme: fmtExtreme, footnote: footnote, shortDate: shortDate, render: render, mount: mount, nextIndex: nextIndex, STORE_KEY: STORE_KEY, ME_KEY: ME_KEY };
});
