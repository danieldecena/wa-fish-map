// Artifacts/salmon-rivers/week.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Week = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* "This week": composes what the site already publishes — dated seasons and milestones (year/data.js), dated catch reports
     (reports.js) and dated WDFW notices (rules.js) — into one result. Nothing here is a rating of its own: report badges reuse
     reports.js' word and token; seasons, rules, milestones and tides are dates and text. Guidance, not regulation. */
  var R_KNOWN = /^(prime|good|fair|slow|unrated)$/;
  var DAY = 86400000, RULE_DAYS = 14, UPCOMING = 3;
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  var DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  /* Spot guides, until the spot-guide template sub-project turns these into data. */
  var SPOTS = [{ id: 'three-friends', name: 'Three Friends Fishing Hole', sub: 'Green River · Kent', href: '../spots/index.html' }];

  /* UTC day number for YYYY-MM-DD; throws on anything else, the same rule as reports.js. */
  function dayNum(iso) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso));
    if (!m) throw new Error('bad date: ' + iso);
    var ms = Date.UTC(+m[1], +m[2] - 1, +m[3]), d = new Date(ms);
    if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) throw new Error('bad date: ' + iso);
    return ms / DAY;
  }
  function isoOf(n) { return new Date(n * DAY).toISOString().slice(0, 10); }
  function fmt(iso) { var d = new Date(dayNum(iso) * DAY); return MONTHS[d.getUTCMonth()] + ' ' + d.getUTCDate(); }
  function fmtDow(iso) { return DOW[new Date(dayNum(iso) * DAY).getUTCDay()] + ' ' + fmt(iso); }
  function range(today) {
    var t = dayNum(today), mon = t - ((new Date(t * DAY).getUTCDay() + 6) % 7), days = [];
    for (var i = 0; i < 7; i++) days.push(isoOf(mon + i));
    return { start: days[0], end: days[6], days: days };
  }
  /* A Year row opens from its season id: year/anchor.js selects the row named by the hash. */
  function yearHref(id) { return '../year/index.html#' + encodeURIComponent(id); }
  function sources(src) { return !src ? [] : Array.isArray(src) ? src : [src]; }
  function byDateThenLabel(a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : a.label < b.label ? -1 : a.label > b.label ? 1 : 0; }

  function openNow(seasons, t) {
    return seasons.filter(function (s) { return dayNum(s.start) <= t && t <= dayNum(s.end); })
      .map(function (s) {
        var left = dayNum(s.end) - t;
        return { id: s.id, name: s.name, where: s.where || '', end: s.end, daysLeft: left, soon: left <= 7, flavor: s.flavor, note: s.note || '', sources: sources(s.source) };
      })
      .sort(function (a, b) { return a.end < b.end ? -1 : a.end > b.end ? 1 : a.name < b.name ? -1 : a.name > b.name ? 1 : 0; });
  }
  function reported(R, today) {
    var t = dayNum(today), out = [];
    R.SITES.forEach(function (site) {
      var have = site.reports || {}, rows = [];
      R.SPECIES.forEach(function (k) {
        var sp = have[k];
        if (!sp || !sp.asOf) return;
        var age = t - dayNum(sp.asOf);
        if (age > R.STALE_DAYS || age < 0) return; /* stale, or dated after today: not a fresh report */
        rows.push({ name: k, r: sp.r, label: (R.LABEL[sp.r] || 'No report') + (sp.release ? ', release only' : ''), release: !!sp.release, asOf: sp.asOf, age: R.describeAge(sp.asOf, today), d: sp.d, src: sp.src || null });
      });
      if (!rows.length) return;
      var keep = rows.filter(function (x) { return !x.release; });
      var best = Math.max.apply(null, (keep.length ? keep : rows).map(function (x) { return (R.RANK[x.r] === undefined ? -2 : R.RANK[x.r]); }));
      out.push({ id: site.id, name: site.name, sub: site.sub || '', href: '../index.html?mode=reports&river=' + encodeURIComponent(site.id), species: rows, _keep: keep.length > 0, _best: best });
    });
    out.sort(function (a, b) {
      if (a._keep !== b._keep) return a._keep ? -1 : 1;
      if (a._best !== b._best) return b._best - a._best;
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
    out.forEach(function (o) { delete o._keep; delete o._best; });
    return out;
  }
  function newRules(rules, t) {
    return rules.filter(function (r) { return t - dayNum(r.published) <= RULE_DAYS && dayNum(r.published) <= t; })
      .map(function (r) { return { rivers: r.rivers.slice(), published: r.published, d: r.d, url: r.url }; })
      .sort(function (a, b) { return a.published < b.published ? 1 : a.published > b.published ? -1 : 0; });
  }
  function upcoming(FY, t) {
    var items = [];
    (FY.seasons || []).forEach(function (s) { if (dayNum(s.start) > t) items.push({ kind: 'season', id: s.id, date: s.start, label: s.name, detail: s.where || '' }); });
    (FY.milestones || []).forEach(function (m) { if (dayNum(m.date) > t) items.push({ kind: 'milestone', date: m.date, label: m.label, detail: m.note || '' }); });
    items.sort(byDateThenLabel);
    return items.slice(0, UPCOMING).map(function (i) { i.daysUntil = dayNum(i.date) - t; return i; });
  }

  function build(FY, R, RL, today) {
    var t = dayNum(today);
    return {
      range: range(today),
      open: openNow(FY.seasons || [], t),
      reported: reported(R, today),
      latestReport: R.latestReport ? R.latestReport(R.SITES) : null,
      rules: newRules(RL.RULES || [], t),
      rulesChecked: RL.CHECKED || null,
      upcoming: upcoming(FY, t),
      spots: SPOTS.slice()
    };
  }

  /* ---- render: a plain DOM builder. doc is window.document on the page and a fake in tests. ---- */
  function render(res, doc) {
    function el(tag, cls, text) { var e = doc.createElement(tag); if (cls) e.className = cls; if (text !== undefined && text !== null) e.textContent = text; return e; }
    function link(href, text, ext) { var a = el('a', null, text); a.setAttribute('href', href); if (ext) { a.setAttribute('target', '_blank'); a.setAttribute('rel', 'noopener'); } return a; }
    function section(id, caption, lede) {
      var s = el('section', 'group'); s.id = id; s.setAttribute('aria-labelledby', 'cap-' + id);
      var h = el('h2', 'cap', caption); h.id = 'cap-' + id; s.appendChild(h);
      if (lede) s.appendChild(el('p', 'lede-s', lede));
      var panel = el('div', 'panel'); s.appendChild(panel);
      var ul = el('ul', 'list'); panel.appendChild(ul);
      return { s: s, ul: ul };
    }
    function empty(ul) { var li = el('li', 'row empty'); li.appendChild(el('span', 'v', 'Nothing this week')); ul.appendChild(li); }
    function days(n) { return n === 0 ? 'today' : n === 1 ? '1 day' : n + ' days'; }
    var root = el('div', 'week');

    var o = section('open', 'Open now');
    if (!res.open.length) empty(o.ul);
    res.open.forEach(function (s) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(link(yearHref(s.id), s.name));
      if (s.where) k.appendChild(el('span', 'sub', s.where));
      var ends = s.daysLeft === 0 ? 'ends today' : 'ends ' + fmt(s.end) + ' · ' + days(s.daysLeft);
      var when = el('span', s.soon ? 'chip soon' : 'dt', s.soon ? 'Ends soon · ' + ends : ends);
      k.appendChild(when);
      if (s.flavor) { var taste = el('span', 'chip', 'Taste #' + s.flavor + ' of 5'); taste.setAttribute('title', 'Taste order, richest first (Washington Fishing Year)'); k.appendChild(taste); }
      if (s.note) v.appendChild(el('p', 'note', s.note));
      if (s.sources.length) {
        var src = el('p', 'src');
        s.sources.forEach(function (x, i) { if (i) src.appendChild(doc.createTextNode(' · ')); src.appendChild(x.url ? link(x.url, x.label, true) : el('span', null, x.label)); if (x.checked) src.appendChild(doc.createTextNode(' (checked ' + fmt(x.checked) + ')')); });
        v.appendChild(src);
      }
      li.appendChild(k); li.appendChild(v); o.ul.appendChild(li);
    });
    root.appendChild(o.s);

    var r = section('reported', 'Reported this week', 'Catch reports, not season dates. Badges use the map’s own words.');
    if (!res.reported.length) {
      if (!res.latestReport) empty(r.ul);
      else {
        var eli = el('li', 'row empty'), ev = el('span', 'v', 'No reports from the last 7 days. Newest: ' + fmt(res.latestReport) + '. ');
        ev.appendChild(link('../index.html?mode=reports', 'See all reports on the map'));
        eli.appendChild(ev); r.ul.appendChild(eli);
      }
    }
    res.reported.forEach(function (site) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(link(site.href, site.name));
      if (site.sub) k.appendChild(el('span', 'sub', site.sub));
      site.species.forEach(function (sp) {
        var line = el('p', 'rep');
        var b = el('span', 'badge', sp.label); b.setAttribute('style', '--c:var(--' + (R_KNOWN.test(sp.r) ? sp.r : 'unrated') + ')');
        line.appendChild(b); line.appendChild(doc.createTextNode(' ' + sp.name + ' · ' + sp.age + ' — ' + sp.d));
        if (sp.src && sp.src.url) { line.appendChild(doc.createTextNode(' ')); line.appendChild(link(sp.src.url, sp.src.label, true)); }
        v.appendChild(line);
      });
      li.appendChild(k); li.appendChild(v); r.ul.appendChild(li);
    });
    root.appendChild(r.s);

    var u = section('rules', 'New rules', 'WDFW’s own wording, published in the last ' + RULE_DAYS + ' days.' + (res.rulesChecked ? ' Checked ' + fmt(res.rulesChecked) + '.' : ''));
    if (!res.rules.length) empty(u.ul);
    res.rules.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(el('span', 'nm', x.rivers.join(', ')));
      k.appendChild(el('span', 'sub', 'WDFW · published ' + fmt(x.published)));
      v.appendChild(el('p', 'note', x.d));
      var rl = link(x.url, 'Read the rule', true); rl.setAttribute('aria-label', 'Read the WDFW rule for ' + x.rivers.join(', ')); v.appendChild(rl);
      li.appendChild(k); li.appendChild(v); u.ul.appendChild(li);
    });
    root.appendChild(u.s);

    var c = section('upcoming', 'Coming up');
    if (!res.upcoming.length) empty(c.ul);
    res.upcoming.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k'), v = el('div', 'v');
      k.appendChild(x.kind === 'season' ? link(yearHref(x.id), x.label) : el('span', 'nm', x.label));
      k.appendChild(el('span', 'dt', (x.kind === 'season' ? 'opens ' : '') + fmt(x.date) + ' · in ' + days(x.daysUntil)));
      if (x.detail) v.appendChild(el('p', 'note', x.detail));
      li.appendChild(k); li.appendChild(v); c.ul.appendChild(li);
    });
    root.appendChild(c.s);

    var p = section('spots', 'Spots');
    if (!res.spots.length) empty(p.ul);
    res.spots.forEach(function (x) {
      var li = el('li', 'row'), k = el('div', 'k');
      k.appendChild(link(x.href, x.name)); k.appendChild(el('span', 'sub', x.sub));
      li.appendChild(k); p.ul.appendChild(li);
    });
    root.appendChild(p.s);
    return root;
  }

  return { SPOTS: SPOTS, yearHref: yearHref, RULE_DAYS: RULE_DAYS, UPCOMING: UPCOMING, MONTHS: MONTHS, dayNum: dayNum, isoOf: isoOf, fmt: fmt, fmtDow: fmtDow, range: range, build: build, render: render };
});
