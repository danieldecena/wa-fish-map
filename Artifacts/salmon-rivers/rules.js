(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Rules = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* WDFW emergency rules linked from river sheets in Recent reports. Hand-written from WDFW's own rule pages, each opened and read
     on 2026-10-20 (see docs/research/2026-10-20-river-reports-and-rules.md). A rule is shown as WDFW's notice with its published date
     and a link: the sheet never restates it as the current regulation, and it never colours a river or a pin. Rules are not ratings. */
  var CHECKED = '2026-10-20';
  var RULES = [
    { rivers: ['Hoh River', 'Quillayute River', 'Sol Duc River', 'Bogachiel River', 'Calawah River'], published: '2026-10-16',
      d: 'WDFW is closing the Hoh and Quillayute watersheds outside Olympic National Park to all fishing, citing a coho catch well below what was expected and low flows.',
      url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules/hoh-and-quillayute-watersheds-closing-all-fishing-2026-10' },
    { rivers: ['Skagit River', 'Cascade River'], published: '2026-10-15',
      d: 'Opens the lower Cascade River seven days a week for coho and sets temporary closures on the Skagit between Gilligan Creek and the Baker River, with coho limits on the rest of the Skagit.',
      url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules/cascade-river-open-seven-days-week-fishing-and-temporary-closure-implemented-portion-skagit-river-2026-10' },
    { rivers: ['Stillaguamish River'], published: '2026-10-07',
      d: 'Closes the mainstem Stillaguamish, Marine Drive to the forks, to all fishing because sport fisheries reached their limit of Chinook encounters.',
      url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules/stillaguamish-river-close-all-fishing-oct-9-2026-10' },
    { rivers: ['Snohomish River'], published: '2026-10-01',
      d: 'Closes the Snohomish from the mouth to the Skykomish and Snoqualmie confluence to all fishing over concern about the coho return.',
      url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules/snohomish-river-close-all-fishing-oct-3-2026-10' }
  ];
  function forRiver(name) { return RULES.filter(function (r) { return r.rivers.indexOf(name) >= 0; }); }
  return { CHECKED: CHECKED, RULES: RULES, forRiver: forRiver };
});
