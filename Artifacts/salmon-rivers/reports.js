(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Reports = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var RANK = { prime: 3, good: 2, fair: 1, slow: 0, unrated: -1 };
  var LABEL = { prime: 'Excellent', good: 'Good', fair: 'Fair', unrated: 'No report' };
  var SP_NAME = { coho: 'Coho', chinook: 'Chinook' };
  var STALE_DAYS = 7;
  var DAY = 86400000;
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /* Reports through Oct 17, 2026. asOf is the date of the report each rating comes from. */
  var SITES = [
    { id: 'cowlitz', name: 'Cowlitz River', sub: 'Below the hatchery at Salkum', hl: true,
      coho: { r: 'prime', asOf: '2026-10-17', d: 'Tacoma Power recovered 3,094 adult coho and 1,876 jacks at the hatchery separator over six days.' },
      chinook: { r: 'fair', release: true, asOf: '2026-10-03', d: 'Chinook are being caught here but must be released.' } },
    { id: 'columbia', name: 'Lower Columbia River', sub: 'Tongue Point to Bonneville Dam', hl: true,
      coho: { r: 'prime', asOf: '2026-10-11', d: 'Coho fishing was excellent in the flight count: 157 salmonid boats and 22 Washington bank rods on this stretch.' },
      chinook: { r: 'fair', release: true, asOf: null, d: 'The mainstem is closed for Chinook retention. Plenty are still caught and released.' } },
    { id: 'lewis', name: 'Lewis River', sub: 'Mouth to Merwin Dam', hl: true,
      coho: { r: 'good', asOf: '2026-10-13', d: '138 bank anglers kept 14 coho and 2 jacks and released 10 coho in the creel.' },
      chinook: { r: 'fair', asOf: '2026-10-13', d: 'Same creel: 3 Chinook and 1 jack kept.' }, extra: 'nws' },
    { id: 'wind', name: 'Wind River', sub: 'Lower river near Carson', hl: true,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Reported very good for coho.' },
      chinook: { r: 'fair', asOf: '2026-10-03', d: 'Chinook were still biting on the Wind River and Drano Lake.' } },
    { id: 'klickitat', name: 'Klickitat River', sub: 'Lower river near Lyle', hl: true,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      chinook: { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } },
    { id: 'drano', name: 'Drano Lake', sub: 'Mouth of the Little White Salmon River', hl: false,
      coho: { r: 'good', asOf: '2026-10-15', d: 'Coho rated good.' },
      chinook: { r: 'good', asOf: '2026-10-15', d: 'Chinook rated good.' } }
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
  function viewOf(site, filter, today) {
    var keys = filter === 'all' ? ['coho', 'chinook'] : [filter];
    var best = null;
    keys.forEach(function (k) {
      var sp = site[k];
      if (!sp) return;
      var c = { r: sp.r, release: !!sp.release, k: k, asOf: sp.asOf === undefined ? null : sp.asOf, fresh: freshness(sp.asOf, today) === 'fresh' };
      if (better(c, best)) best = c;
    });
    return best || { r: 'unrated', release: false, k: null, asOf: null, fresh: false };
  }

  function latestReport(sites) {
    var latest = null;
    sites.forEach(function (s) {
      ['coho', 'chinook'].forEach(function (k) {
        var a = s[k] && s[k].asOf;
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

  function rankSites(sites, filter, today) {
    return sites.map(function (s) { return { site: s, vw: viewOf(s, filter, today) }; }).sort(function (a, b) {
      if (a.vw.release !== b.vw.release) return a.vw.release ? 1 : -1;
      if (a.vw.fresh !== b.vw.fresh) return a.vw.fresh ? -1 : 1;
      if (RANK[a.vw.r] !== RANK[b.vw.r]) return RANK[b.vw.r] - RANK[a.vw.r];
      return a.site.name < b.site.name ? -1 : a.site.name > b.site.name ? 1 : 0;
    });
  }
  function ratingWord(vw) { return LABEL[vw.r] + (vw.release ? ', release only' : ''); }

  return {
    SITES: SITES, RANK: RANK, LABEL: LABEL, SP_NAME: SP_NAME, STALE_DAYS: STALE_DAYS,
    viewOf: viewOf, freshness: freshness, ageDays: ageDays, formatDay: formatDay, describeAge: describeAge,
    latestReport: latestReport, staleNotice: staleNotice, rankSites: rankSites, ratingWord: ratingWord
  };
});
