// Artifacts/salmon-rivers/species-short.js
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.SpeciesShort = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Short display forms for the species names too long for a chip, a bar button or a sheet row. The exact app name stays in the data, in the
     filters, in a tooltip and in the accessible name; only the visible label is shortened. Any name over MAX characters needs an entry here:
     test/species-short.test.js fails when a new long species arrives without one. */
  var MAX = 18;
  var SHORT = {
    'Chinook Salmon (summer hatchery)': 'Summer Chinook',
    'Resident Chinook (Blackmouth)': 'Blackmouth',
    'Chinook Salmon (Tulalip)': 'Chinook (Tulalip)',
    'Crab Snaring (shore)': 'Crab snaring'
  };
  function short(name) { return Object.prototype.hasOwnProperty.call(SHORT, name) ? SHORT[name] : name; }

  return { MAX: MAX, SHORT: SHORT, short: short };
});
