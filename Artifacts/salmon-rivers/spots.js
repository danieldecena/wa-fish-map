// Artifacts/salmon-rivers/spots.js
/* Spot guides for the map's Spot guides layer. Hand-written and dated: the rules in them go stale, so each carries `updated`.
   Text is carried over verbatim from the old Spots page (test/spots.test.js checks it against a saved copy).
   Three Friends' point comes from docs/research/2026-10-26-three-friends-location.md. */
window.SPOTS = [
  {
    id: 'three-friends',
    name: 'Three Friends Fishing Hole',
    sub: 'Green River · Kent, WA · Bank access',
    lat: 47.4231, lon: -122.2643,
    updated: '2026-10-19',
    intro: 'Lower river bank access close to the S 212th St line where the rules change. Check the reach before you cast.',
    closure: { title: 'Chinook are closed this year', text: 'An August emergency rule closed Chinook retention on the Green. The upper Green is also closed to all fishing Sept 16 to Oct 31.' },
    timing: {
      cols: ['Now–Oct 31', 'Nov 1–14', 'Nov 15–30', 'Dec'],
      rows: [{ species: 'Coho', cells: ['Prime', 'Good', 'Fair', 'Slow'] }, { species: 'Chum', cells: ['Fair', 'Good', 'Prime', 'Slow'] }],
      note: 'Typical run timing from angler reports, not a WDFW forecast. A good rain brings a fresh push of fish, so the ratings can jump a step.'
    },
    tips: [
      ['Time of day', 'Dawn and the last hour of light. One local coho report was a hookup at about 7 a.m.'],
      ['Day of week', 'Weekdays. Weekend crowds on the Kent bank spots spook fish. The best single day is the one after a rain.'],
      ['Water', 'Rising or freshly raised water fishes best. Low, clear, shallow water with no rain is the slowest.'],
      ['Coho tactics', 'Local anglers call Green coho lockjawed. Go smaller on baits and lighter on leaders.'],
      ['Chum tactics', 'November is the month. Anglers have called the Green chum bite fantastic, with the best days right after rain.']
    ],
    rulesTitle: 'Rules for the lower Green',
    rules: [
      ['Salmon limit', '6 a day, no more than 3 adult coho and chum combined'],
      ['Minimum size', '12 in'],
      ['Chinook', 'Retention is closed', 'Release'],
      ['S 212th St', 'Below the S 212th St bridge the season opened Aug 20. Above it, up to the Hwy 18 bridge, it opened Sept 16. Both are open now through Dec 31.'],
      ['November', 'The Green has had a night closure and anti-snagging rule in November before. Confirm for this year.']
    ],
    sources: [
      { label: 'WDFW emergency rules', url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules' },
      { label: 'eRegulations, Green (Duwamish) special rules', url: 'https://www.eregulations.com/washington/fishing/puget-sound-coastal-rivers-special-rules-d-k' },
      { label: 'WDFW rule #26-155', url: 'https://wdfw.wa.gov/about/regulations/rule-changes/green-duwamish-recreational-fishing-2026-08' },
      { label: 'Northwest Fishing Reports', url: 'https://northwestfishingreports.com/Forum/viewtopic.php?p=244027' }
    ]
  }
];
