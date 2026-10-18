(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Season = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* A port of the WA Fish Map rating (FishingRating, SpeciesSeason.rating, AreaFishery in
     WAFishMap/Models/Fishery.swift). It scores typical seasonal timing from the app's curated
     guidance. It is not a catch report and not a claim that any fishery is open. The data is
     typical.js, generated from fisheries.json; this file only reads it. */

  var POOR = 0, FAIR = 1, GOOD = 2, EXCELLENT = 3;
  /* Swift enum case -> the page's existing colour token -> the app's label. */
  var TOKEN = ['slow', 'fair', 'good', 'prime'];
  var LABEL = { slow: 'Slow', fair: 'Fair', good: 'Good', prime: 'Prime', unrated: 'No seasonal guidance' };
  /* The word a small pin label carries when the site name does not fit beside it. Every token has a different word. */
  var SHORT = { slow: 'Slow', fair: 'Fair', good: 'Good', prime: 'Prime', unrated: 'No data' };
  var RANK = { prime: 3, good: 2, fair: 1, slow: 0, unrated: -1 };
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  function circularMonthDistance(a, b) {
    var raw = Math.abs(a - b) % 12;
    return Math.min(raw, 12 - raw);
  }
  function has(list, m) { return list.indexOf(m) >= 0; }

  /* SeasonRisk.matches: case-insensitive substring. */
  function riskMatches(row, speciesName) {
    return speciesName.toLowerCase().indexOf(row.match.toLowerCase()) >= 0;
  }

  /* SpeciesSeason.resolvingSeasonRisk: union the months of every matching row, join distinct reasons; a row marked "none" opts out. */
  function resolveRisk(sp, table) {
    if (typeof sp.seasonRisk === 'string' && sp.seasonRisk.toLowerCase() === 'none') return { riskMonths: [], riskReason: null };
    var hits = table.filter(function (t) { return riskMatches(t, sp.species); });
    if (!hits.length) return { riskMonths: [], riskReason: null };
    var months = [];
    hits.forEach(function (h) { h.months.forEach(function (m) { if (!has(months, m)) months.push(m); }); });
    months.sort(function (a, b) { return a - b; });
    var reasons = [];
    hits.forEach(function (h) { if (!has(reasons, h.reason)) reasons.push(h.reason); });
    return { riskMonths: months, riskReason: reasons.join('; ') };
  }

  /* SpeciesSeason.resolvingYear: "odd"/"even" rows are off in the wrong year. */
  function offYear(sp, year) {
    var y = typeof sp.years === 'string' ? sp.years.toLowerCase() : null;
    if (y === 'odd') return year % 2 === 0;
    if (y === 'even') return year % 2 !== 0;
    return false;
  }

  /* One species row stamped the way the app stamps it at load. */
  function stamp(sp, table, year) {
    var risk = resolveRisk(sp, table);
    return {
      species: sp.species,
      best: sp.bestMonths || [],
      good: sp.goodMonths || [],
      note: sp.note || null,
      riskMonths: risk.riskMonths,
      riskReason: risk.riskReason,
      offYear: offYear(sp, year)
    };
  }

  /* SpeciesSeason.rating(inMonth:) -> 0..3. */
  function speciesRating(sp, month) {
    if (sp.offYear) return POOR;
    var base;
    if (has(sp.best, month)) base = EXCELLENT;
    else if (has(sp.good, month)) base = GOOD;
    else {
      var shoulder = sp.best.concat(sp.good).some(function (m) { return circularMonthDistance(m, month) === 1; });
      base = shoulder ? FAIR : POOR;
    }
    return has(sp.riskMonths, month) ? Math.min(base, FAIR) : base;
  }

  /* AreaFishery.breadthRating: the rounded mean of the best three species. */
  function breadthRating(rows, month) {
    var top = rows.map(function (s) { return speciesRating(s, month); }).sort(function (a, b) { return b - a; }).slice(0, 3);
    if (!top.length) return POOR;
    var mean = top.reduce(function (a, b) { return a + b; }, 0) / top.length;
    /* Swift's .rounded() is half away from zero; the values are non-negative. */
    return Math.round(mean);
  }

  /* AreaFishery.rating(inMonth:species:): null species is All; a named species is an exact match, or null when the area does not list it. */
  function areaRating(rows, month, name) {
    if (name === null || name === undefined) return breadthRating(rows, month);
    for (var i = 0; i < rows.length; i++) if (rows[i].species === name) return speciesRating(rows[i], month);
    return null;
  }

  /* AreaFishery.closurePlausible(inMonth:species:). */
  function closurePlausible(rows, month, name) {
    if (name !== null && name !== undefined) {
      for (var i = 0; i < rows.length; i++) if (rows[i].species === name) return has(rows[i].riskMonths, month);
      return false;
    }
    var top = Math.max.apply(null, rows.map(function (s) { return speciesRating(s, month); }));
    var leaders = rows.filter(function (s) { return speciesRating(s, month) === top; });
    return leaders.length > 0 && leaders.every(function (s) { return has(s.riskMonths, month); });
  }

  /* AreaFishery.inSeason(month:): fair or better, best first, ties by declaration order. */
  function inSeason(rows, month) {
    var ranked = [];
    rows.forEach(function (s, i) {
      var r = speciesRating(s, month);
      if (r >= FAIR) ranked.push({ i: i, s: s, r: r });
    });
    ranked.sort(function (a, b) { return a.r !== b.r ? b.r - a.r : a.i - b.i; });
    return ranked.map(function (e) { return e.s; });
  }

  /* Resolve every guide in the generated data once, for a plan year. */
  function prepare(data, year) {
    return {
      data: data,
      year: year,
      guides: data.guides.map(function (g) {
        return { scope: g.scope, kind: g.kind, area: g.area, rows: g.rows.map(function (r) { return stamp(r, data.seasonRisk, year); }) };
      })
    };
  }

  function guideOf(prep, site) { return site.guide === null ? null : prep.guides[site.guide]; }

  /* The colour token and the closure flag for a site: the page's pin colour. */
  function siteView(prep, site, month, species) {
    var g = guideOf(prep, site);
    var r = g ? areaRating(g.rows, month, species) : null;
    if (r === null) return { r: 'unrated', rating: null, closure: false };
    return { r: TOKEN[r], rating: r, closure: closurePlausible(g.rows, month, species) };
  }

  /* Every species row for a site's sheet: in-season first (the app's order), then the rest as declared. */
  function siteRows(prep, site, month) {
    var g = guideOf(prep, site);
    if (!g) return [];
    var first = inSeason(g.rows, month);
    var rest = g.rows.filter(function (s) { return first.indexOf(s) < 0; });
    return first.concat(rest).map(function (s) {
      var r = speciesRating(s, month);
      return {
        species: s.species, r: TOKEN[r], rating: r, best: s.best, good: s.good, note: s.note,
        verify: has(s.riskMonths, month) ? (s.riskReason || 'Season varies; verify') : null,
        offYear: s.offYear
      };
    });
  }

  function monthsText(list) {
    if (!list.length) return 'none listed';
    return list.slice().sort(function (a, b) { return a - b; }).map(function (m) { return MONTHS[m - 1].slice(0, 3); }).join(', ');
  }

  var KIND_LABEL = { pier: 'Pier', launch: 'Boat launch', access: 'Shore access' };

  return {
    POOR: POOR, FAIR: FAIR, GOOD: GOOD, EXCELLENT: EXCELLENT, TOKEN: TOKEN, LABEL: LABEL, SHORT: SHORT, RANK: RANK, MONTHS: MONTHS, KIND_LABEL: KIND_LABEL,
    circularMonthDistance: circularMonthDistance, riskMatches: riskMatches, resolveRisk: resolveRisk, offYear: offYear, stamp: stamp,
    speciesRating: speciesRating, breadthRating: breadthRating, areaRating: areaRating, closurePlausible: closurePlausible,
    inSeason: inSeason, prepare: prepare, siteView: siteView, siteRows: siteRows, monthsText: monthsText
  };
});
