(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Reports = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var RANK = { prime: 3, good: 2, fair: 1, slow: 0, unrated: -1 };
  var LABEL = { prime: 'Excellent', good: 'Good', fair: 'Fair', slow: 'Slow', unrated: 'No report' };
  var STALE_DAYS = 7;
  /* Display order of every species with at least one report. Each is an exact species name from the app's species list. */
  var SPECIES = ['Coho Salmon', 'Chinook Salmon', 'Fall Chinook'];
  var DAY = 86400000;
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /* Reports through Oct 17, 2026. asOf is the date of the report each rating comes from. */
  var SITES = [
    { id: 'cowlitz', name: 'Cowlitz River', sub: 'Below the hatchery at Salkum', hl: true,
      reports: { 'Coho Salmon': { r: 'prime', asOf: '2026-10-17', d: 'Tacoma Power recovered 3,094 adult coho and 1,876 jacks at the hatchery separator over six days.' },
      'Chinook Salmon': { r: 'fair', release: true, asOf: '2026-10-03', d: 'Chinook are being caught here but must be released.' } } },
    { id: 'columbia', name: 'Lower Columbia River', sub: 'Tongue Point to Bonneville Dam', hl: true,
      reports: { 'Coho Salmon': { r: 'prime', asOf: '2026-10-11', d: 'Coho fishing was excellent in the flight count: 157 salmonid boats and 22 Washington bank rods on this stretch.' },
      'Chinook Salmon': { r: 'fair', release: true, asOf: null, d: 'The mainstem is closed for Chinook retention. Plenty are still caught and released.' } } },
    { id: 'lewis', name: 'Lewis River', sub: 'Mouth to Merwin Dam', hl: true,
      reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-13', d: '138 bank anglers kept 14 coho and 2 jacks and released 10 coho in the creel.' },
      'Chinook Salmon': { r: 'fair', asOf: '2026-10-13', d: 'Same creel: 3 Chinook and 1 jack kept.' },
      'Fall Chinook': { r: 'good', asOf: '2026-09-26', d: 'Fall Chinook reported in good numbers, though the report says the run may be past its peak.',
        src: { label: 'The Guide\u2019s Forecast, Sep 26', url: 'https://www.theguidesforecast.com/free/salmon-and-coho-retention-reopens/286727/' } } }, extra: 'nws' },
    { id: 'wind', name: 'Wind River', sub: 'Lower river near Carson', hl: true,
      reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-15', d: 'Reported very good for coho.' },
      'Chinook Salmon': { r: 'fair', asOf: '2026-10-03', d: 'Chinook were still biting on the Wind River and Drano Lake.' } } },
    { id: 'klickitat', name: 'Klickitat River', sub: 'Lower river near Lyle', hl: true,
      reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      'Chinook Salmon': { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } } },
    { id: 'drano', name: 'Drano Lake', sub: 'Mouth of the Little White Salmon River', hl: false,
      reports: { 'Coho Salmon': { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      'Chinook Salmon': { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } } },
    /* Slow is only ever the source's own word (slow or poor), kept in phrase. Never worked out from a number. */
    { id: 'kalama', name: 'Kalama River', sub: 'Lower river near Kalama', hl: true,
      reports: { 'Coho Salmon': { r: 'slow', asOf: '2026-10-17', phrase: 'Fishing remains poor', d: 'Fishing is poor in low water. Four bank anglers kept one coho, and the weir is still in place. It is expected out this week.',
        src: { label: 'The Guide\u2019s Forecast, Oct 17', url: 'https://www.theguidesforecast.com/free/coho-run-heats-up/287017/' } } } },
    /* No rating: the Oct 17 Guide's Forecast calls Washougal fishing slow but names no species, and this page rates by exact species, so the word cannot be carried onto one. A gray No report pin; its sheet shows the WDFW creel figures. */
    { id: 'washougal', name: 'Washougal River', sub: 'Lower river near Camas', hl: true, reports: {} }
  ];

  function parseDay(iso) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    if (!m) throw new Error('bad date: ' + iso);
    var ms = Date.UTC(+m[1], +m[2] - 1, +m[3]);
    var d = new Date(ms);
    if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) throw new Error('bad date: ' + iso);
    return ms;
  }
  function ageDays(asOf, today) {
    if (asOf === null || asOf === undefined) return null;
    return Math.round((parseDay(today) - parseDay(asOf)) / DAY);
  }
  function freshness(asOf, today) {
    var a = ageDays(asOf, today);
    if (a === null) return 'undated';
    return a <= STALE_DAYS ? 'fresh' : 'stale';
  }
  function formatDay(iso) {
    var d = new Date(parseDay(iso));
    return MONTHS[d.getUTCMonth()] + ' ' + d.getUTCDate();
  }
  function describeAge(asOf, today) {
    var a = ageDays(asOf, today);
    if (a === null) return 'Date not given';
    var when = a <= 0 ? 'today' : a === 1 ? 'yesterday' : a + ' days ago';
    return formatDay(asOf) + ' · ' + when;
  }

  // c replaces best when: best is release-only and c is not; else c is fresh and best is not; else c rates higher.
  function better(c, best) {
    if (!best) return true;
    if (best.release !== c.release) return best.release;
    if (best.fresh !== c.fresh) return c.fresh;
    return RANK[c.r] > RANK[best.r];
  }
  function reportsOf(site) { return site.reports || {}; }
  function viewOf(site, species, today) {
    if (species !== null && SPECIES.indexOf(species) < 0) throw new Error('unknown species: ' + species);
    var have = reportsOf(site);
    var best = null;
    (species === null ? SPECIES : [species]).forEach(function (k) {
      var sp = have[k];
      if (!sp) return;
      var c = { r: sp.r, release: !!sp.release, k: k, asOf: sp.asOf === undefined ? null : sp.asOf, fresh: freshness(sp.asOf, today) === 'fresh' };
      if (better(c, best)) best = c;
    });
    return best || { r: 'unrated', release: false, k: null, asOf: null, fresh: false };
  }

  function latestReport(sites) {
    var latest = null;
    sites.forEach(function (s) {
      var have = reportsOf(s);
      Object.keys(have).forEach(function (k) {
        var a = have[k].asOf;
        if (a && (latest === null || a > latest)) latest = a;
      });
    });
    return latest;
  }
  function staleNotice(sites, today) {
    var latest = latestReport(sites);
    if (latest === null) return null;
    var a = ageDays(latest, today);
    if (a <= STALE_DAYS) return null;
    return 'The newest report here is ' + a + ' days old (' + formatDay(latest) + '). Check WDFW or The Guide’s Forecast for current catch.';
  }

  function rankSites(sites, species, today) {
    return sites.map(function (s) { return { site: s, vw: viewOf(s, species, today) }; }).sort(function (a, b) {
      if (a.vw.release !== b.vw.release) return a.vw.release ? 1 : -1;
      if (a.vw.fresh !== b.vw.fresh) return a.vw.fresh ? -1 : 1;
      if (RANK[a.vw.r] !== RANK[b.vw.r]) return RANK[b.vw.r] - RANK[a.vw.r];
      return a.site.name < b.site.name ? -1 : a.site.name > b.site.name ? 1 : 0;
    });
  }
  function pinLabel(site, vw, species) {
    if (vw.k === null) return site.name + ', no report' + (species ? ' for ' + species : '');
    return site.name + ', ' + LABEL[vw.r].toLowerCase() + ' reports for ' + vw.k.toLowerCase() + (vw.release ? ', release only' : '');
  }
  function reportRows(site) {
    var have = reportsOf(site);
    return SPECIES.filter(function (k) { return !!have[k]; }).map(function (k) { return { name: k, sp: have[k] }; });
  }
  function missingNote(site, species) {
    if (species === null || reportsOf(site)[species]) return null;
    return 'No report for ' + species + ' on this water. Confirm what is open and what you may keep on WDFW before you fish.';
  }
  function ratingWord(vw) { return LABEL[vw.r] + (vw.release ? ', release only' : ''); }
  /* The Recent reports opening box: base (the southwest, down to the Columbia) grown to hold every report pin with room for
     the pin and its label above it (pad: [x, above]). Pure; the page passes its own projected points. */
  function homeBox(points, base, pad) {
    var px = pad ? pad[0] : 12, py = pad ? pad[1] : 24;
    var x0 = base[0][0], y0 = base[0][1], x1 = base[1][0], y1 = base[1][1];
    points.forEach(function (p) { x0 = Math.min(x0, p[0] - px); x1 = Math.max(x1, p[0] + px); y0 = Math.min(y0, p[1] - py); y1 = Math.max(y1, p[1]); });
    return [[x0, y0], [x1, y1]];
  }
  /* The region the map's title and label name: the southwest while every report pin is inside its box, else the state. */
  function regionName(points, sw) {
    var inside = points.every(function (p) { return p[0] >= sw[0][0] && p[0] <= sw[1][0] && p[1] >= sw[0][1] && p[1] <= sw[1][1]; });
    return inside ? 'Southwest Washington' : 'Washington';
  }

  return {
    SITES: SITES, RANK: RANK, LABEL: LABEL, STALE_DAYS: STALE_DAYS, SPECIES: SPECIES,
    viewOf: viewOf, freshness: freshness, ageDays: ageDays, formatDay: formatDay, describeAge: describeAge,
    latestReport: latestReport, staleNotice: staleNotice, rankSites: rankSites, ratingWord: ratingWord, pinLabel: pinLabel,
    reportRows: reportRows, missingNote: missingNote, homeBox: homeBox, regionName: regionName
  };
});
