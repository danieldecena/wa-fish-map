// Artifacts/salmon-rivers/tides.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Tides = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* NOAA CO-OPS tide predictions for the Week page. Predictions, not observations; MLLW; station local time as NOAA returns it,
     never converted. The only network call on the site. Heights are never turned into a rating or a "good time" word. */
  var BASE = 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter';
  /* Names and coordinates verified against NOAA's station metadata on 2026-10-26 (see docs/HANDOFF-2026-10-26.md; STATUS.md in the real repo). */
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

  function byId(id) { for (var i = 0; i < STATIONS.length; i++) if (STATIONS[i].id === id) return STATIONS[i]; return null; }
  function nearest(lat, lon) {
    var best = null, bd = Infinity, R = 3959, toR = Math.PI / 180;
    STATIONS.forEach(function (s) {
      var dLat = (s.lat - lat) * toR, dLon = (s.lon - lon) * toR;
      var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat * toR) * Math.cos(s.lat * toR) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
      var d = 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      if (d < bd) { bd = d; best = s; }
    });
    return best;
  }
  function ymd(iso) { return iso.replace(/-/g, ''); }
  function url(station, range) {
    return BASE + '?product=predictions&datum=MLLW&interval=hilo&units=english&time_zone=lst_ldt&format=json' +
      '&station=' + encodeURIComponent(station.id) + '&begin_date=' + ymd(range.start) + '&end_date=' + ymd(range.end);
  }
  function parse(json, range) {
    var by = {};
    range.days.forEach(function (d) { by[d] = []; });
    ((json && json.predictions) || []).forEach(function (p) {
      var date = String(p.t).slice(0, 10);
      if (!by[date]) return;
      by[date].push({ t: String(p.t).slice(11, 16), type: p.type === 'H' ? 'H' : 'L', v: parseFloat(p.v) });
    });
    return range.days.map(function (d) { return { date: d, extremes: by[d] }; });
  }
  function load(station, range, fetchFn) {
    return fetchFn(url(station, range)).then(function (r) {
      if (!r.ok) throw new Error('NOAA HTTP ' + r.status);
      return r.json();
    }).then(function (j) {
      if (j && j.error) throw new Error('NOAA: ' + (j.error.message || 'error'));
      return parse(j, range);
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
  /* now is 'YYYY-MM-DD HH:MM' in the station's local time; NOAA's t strings compare the same way. */
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
      if (!d.extremes.length) td.textContent = '—';
      d.extremes.forEach(function (e, i) {
        var s = doc.createElement('span');
        s.className = 'ex ' + e.type + (nx && nx.day === di && nx.i === i ? ' next' : '');
        s.textContent = e.type + ' ' + fmtTime(e.t) + ' · ' + e.v.toFixed(1) + ' ft';
        td.appendChild(s);
      });
      tr.appendChild(td); tbody.appendChild(tr);
    });
    return table;
  }
  function readStorage(storage, key) { try { return storage ? storage.getItem(key) : null; } catch (e) { return null; } }
  function writeStorage(storage, key, v) { try { if (storage) storage.setItem(key, v); } catch (e) { /* not persisted */ } }
  function localNow() { var d = new Date(); function p(n) { return String(n).padStart(2, '0'); } return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes()); }
  function startingStation(storage) {
    var stored = byId(readStorage(storage, STORE_KEY) || '');
    if (stored) return stored;
    try {
      var me = JSON.parse(readStorage(storage, ME_KEY) || 'null');
      if (me && isFinite(me.lat) && isFinite(me.lon)) return nearest(+me.lat, +me.lon);
    } catch (e) { /* unreadable: default */ }
    return byId(DEFAULT);
  }
  /* mount builds <section id="tides"> after afterSection and fills it. opts: { fetch, storage, now, timeoutMs } — the page passes nothing and gets window.fetch, localStorage and the clock. */
  function mount(root, afterSection, range, today, doc, opts) {
    opts = opts || {};
    var timeoutMs = opts.timeoutMs > 0 ? opts.timeoutMs : 10000;
    var useDefault = !opts.fetch;
    // Whichever fetch is used, a request that hangs past timeoutMs takes the same failure path; the default request is also aborted.
    function loadTimed(st) {
      var ctl = useDefault && typeof AbortController !== 'undefined' ? new AbortController() : null, timer;
      var fetchFn = opts.fetch || function (u) { return ctl ? fetch(u, { signal: ctl.signal }) : fetch(u); };
      var p = load(st, range, fetchFn);
      var t = new Promise(function (_, reject) {
        timer = setTimeout(function () { if (ctl) { try { ctl.abort(); } catch (e) { /* already done */ } } reject(new Error('NOAA timeout')); }, timeoutMs);
      });
      var clear = function () { clearTimeout(timer); };
      p.then(clear, clear);
      return Promise.race([p, t]);
    }
    var storage;
    if ('storage' in opts) storage = opts.storage;
    else { try { storage = typeof localStorage !== 'undefined' ? localStorage : null; } catch (e) { storage = null; } }
    var real = localNow();
    var now = opts.now || (!today || today === real.slice(0, 10) ? real : today + ' 00:00');
    var seq = 0;
    var sec = doc.createElement('section'); sec.className = 'group'; sec.id = 'tides'; sec.setAttribute('aria-labelledby', 'cap-tides');
    var head = doc.createElement('div'); head.className = 'tides-head';
    var h = doc.createElement('h2'); h.className = 'cap'; h.id = 'cap-tides'; head.appendChild(h);
    var sel = doc.createElement('select'); sel.setAttribute('aria-label', 'Tide station');
    STATIONS.forEach(function (s) { var o = doc.createElement('option'); o.setAttribute('value', s.id); o.value = s.id; o.textContent = s.name; sel.appendChild(o); });
    head.appendChild(sel); sec.appendChild(head);
    var panel = doc.createElement('div'); panel.className = 'panel'; sec.appendChild(panel);
    var fine = doc.createElement('p'); fine.className = 'fine'; fine.textContent = 'NOAA predictions, MLLW, local time. Not observations.'; sec.appendChild(fine);
    root.insertBefore(sec, afterSection.nextSibling);
    var station = startingStation(storage);
    sel.value = station.id;
    function show(node) { panel.textContent = ''; panel.appendChild(node); }
    function pending() { var p = doc.createElement('p'); p.className = 'fine'; p.textContent = '—'; return p; }
    function failed(st) {
      var p = doc.createElement('p'); p.className = 'fine';
      p.textContent = 'Tide predictions unavailable right now. ';
      var a = doc.createElement('a'); a.setAttribute('href', 'https://tidesandcurrents.noaa.gov/noaatidepredictions.html?id=' + st.id); a.setAttribute('target', '_blank'); a.setAttribute('rel', 'noopener'); a.textContent = 'See NOAA for ' + st.name;
      p.appendChild(a); return p;
    }
    function go(st) {
      var my = ++seq;
      h.textContent = 'Tides · ' + st.name;
      show(pending());
      return loadTimed(st).then(function (days) { if (my !== seq) return; show(render(days, now, doc)); }, function () { if (my !== seq) return; show(failed(st)); });
    }
    sel.addEventListener('change', function () {
      var st = byId(sel.value); if (!st) return;
      writeStorage(storage, STORE_KEY, st.id);
      go(st);
    });
    return go(station);
  }

  return { STATIONS: STATIONS, DEFAULT: DEFAULT, byId: byId, nearest: nearest, url: url, parse: parse, load: load, fmtTime: fmtTime, render: render, mount: mount, nextIndex: nextIndex, STORE_KEY: STORE_KEY, ME_KEY: ME_KEY };
});
