// Artifacts/salmon-rivers/spots.js
/* Spot guides for the map's Spot guides layer. Hand-written and dated: the rules in them go stale, so each carries `updated`.
   Text is carried over verbatim from the old Spots page (test/spots.test.js checks it against a saved copy).
   Points come from docs/research/2026-10-26-three-friends-location.md and 2026-10-26-puget-spot-guides.md. */
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
  },
  {
    id: 'waterman-point-pier',
    tide: true,
    name: 'Waterman Point Pier',
    sub: 'Puget Sound (Sinclair Inlet) · Port Orchard · Public pier',
    lat: 47.5731, lon: -122.5812,
    updated: '2026-10-26',
    intro: 'A 230-foot public fishing pier rebuilt in 2015 on the site of a 90-year-old wooden one, with a lit end section and slotted rails for wheelchair anglers. A winter squid spot.',
    closure: null,
    timing: {
      cols: ['Early Nov', 'Late Nov', 'Dec'],
      rows: [{ species: 'Squid', cells: ['Fair', 'Good', 'Good'] }],
      note: 'Our reading of WDFW guidance (adult squid reach central and south Sound from late November), not a report from this pier. Salmon is open here, but no source grades it.'
    },
    tips: [
      ['Time of day', 'Squid feed at night and come to light: they start just after dark and often taper off by midnight. Bring a lantern.'],
      ['Where', 'The end of the pier is lit. WDFW lists parking, ADA access and railings.'],
      ['Gear', 'Squid jig with up to 4 lures on 6 to 20 lb line. Hooks are barbless, so keep the line tight.']
    ],
    rulesTitle: 'Rules on the pier (Marine Area 10)',
    rules: [
      ['Salmon', 'Open at the pier Oct 1 to Apr 30: 2 a day, no more than 1 Chinook, Chinook at least 22 in. The rest of Sinclair Inlet has different rules.'],
      ['Squid', 'Shellfish licence; 5 quarts or 10 lb a day; one line per person.'],
      ['Hooks', 'Barbless in Marine Areas 5 to 13.'],
      ['Other fish', 'Rockfish closed; surfperch limit 10; sea-run trout release only.']
    ],
    sources: [
      { label: 'WDFW: Waterman Point Pier', url: 'https://wdfw.wa.gov/places-to-go/fishing-piers/waterman-point-pier-sinclair-inlet' },
      { label: 'WDFW: catching squid', url: 'https://wdfw.wa.gov/fishing/basics/squid' },
      { label: 'eRegulations: Marine Area 10', url: 'https://www.eregulations.com/washington/fishing/marine-area-10' },
      { label: 'Kitsap Daily News, Dec 4 2015', url: 'https://www.kitsapdailynews.com/?p=16828' }
    ]
  },
  {
    id: 'fox-island-pier',
    tide: true,
    name: 'Fox Island Fishing Pier',
    sub: 'Puget Sound (Hale Passage) · Fox Island · Public pier',
    lat: 47.2287, lon: -122.5905,
    updated: '2026-10-26',
    intro: 'An ADA-accessible pier at the east tip of Fox Island, built by WDFW in 1995 and run by PenMet Parks, with beach access beside it. Open 7 a.m. to dusk, so no night squid jigging.',
    closure: null,
    timing: {
      cols: ['Nov', 'Dec'],
      rows: [{ species: 'Sea-run cutthroat (release)', cells: ['Good', 'Good'] }],
      note: 'Our reading of WDFW guidance for Marine Area 13 (cutthroat best fall through spring), not a report from this pier. Salmon is open here, but no source grades it.'
    },
    tips: [
      ['Hours', 'The park is open 7 a.m. to dusk; plan a daylight trip.'],
      ['Tide', 'For cutthroat, fish soft tides and slack water; strong exchanges scatter fish. Small spoons or size 2 to 3 spinners.'],
      ['Parking', 'WDFW lists a parking fee and the park lists none; bring a way to pay.']
    ],
    rulesTitle: 'Rules on the pier (Marine Area 13)',
    rules: [
      ['Salmon', 'Open at the pier Oct 1 to Jun 30: 2 a day, no more than 1 Chinook, Chinook at least 22 in; release chum.'],
      ['Crab', 'Closed in Marine Area 13 in 2026.'],
      ['Trout', 'Sea-run cutthroat are release only.'],
      ['Nearby', 'Z’s Reef Marine Preserve off Fox Island is closed to all harvest except fly fishing for salmon.']
    ],
    sources: [
      { label: 'WDFW: Fox Island Fishing Pier', url: 'https://wdfw.wa.gov/places-to-go/fishing-piers/fox-island-fishing-pier' },
      { label: 'PenMet Parks: Fox Island Fishing Pier', url: 'https://penmetparks.org/parks/fox-island-fishing-pier/' },
      { label: 'WDFW: Marine Area 13', url: 'https://wdfw.wa.gov/fishing/locations/marine-areas/south-puget-sound' },
      { label: 'eRegulations: Marine Area 13', url: 'https://www.eregulations.com/washington/fishing/marine-area-13' }
    ]
  },
  {
    id: 'browns-point',
    tide: true,
    name: 'Browns Point Lighthouse Park',
    sub: 'Puget Sound (Dalco Passage) · Tacoma · Shore access',
    lat: 47.3059, lon: -122.4443,
    updated: '2026-10-26',
    intro: 'A small Tacoma park around the Browns Point lighthouse. Park there and walk northwest to the beach; WDFW lists cutthroat and resident coho here in fall and winter.',
    closure: null,
    timing: {
      cols: ['Early Nov', 'Late Nov', 'Dec'],
      rows: [
        { species: 'Sea-run cutthroat (release)', cells: ['Good', 'Good', 'Good'] },
        { species: 'Coho', cells: ['Fair', 'Closed', 'Closed'] }
      ],
      note: 'Our reading of WDFW guidance for Marine Area 11, not a report from this beach. Salmon closes in Area 11 on Nov 16.'
    },
    tips: [
      ['Getting there', 'Park at the lighthouse park and walk northwest to the beach. Stay off the private tidelands beside it.'],
      ['Hours', 'The park is open from half an hour before sunrise to half an hour after sunset, and the lot gate may lock earlier. Check before you go.'],
      ['Gear', 'For cutthroat: small spoons, size 2 to 3 spinners, or a marabou Clouser on a fly rod, on soft tides.']
    ],
    rulesTitle: 'Rules on the beach (Marine Area 11)',
    rules: [
      ['Salmon', 'Open Oct 1 to Nov 15: 2 a day, release Chinook. Closed Nov 16 to Mar 30.'],
      ['Commencement Bay', 'The bay has its own season, closed from Nov 1. Fish outside the bay line.'],
      ['Trout', 'Sea-run cutthroat are release only.'],
      ['Hooks', 'Barbless in Marine Areas 5 to 13.']
    ],
    sources: [
      { label: 'WDFW: Marine Area 11', url: 'https://wdfw.wa.gov/fishing/locations/marine-areas/tacoma-vashon-island' },
      { label: 'eRegulations: Marine Area 11', url: 'https://www.eregulations.com/washington/fishing/marine-area-11' },
      { label: 'Parks Tacoma: Browns Point Lighthouse Park', url: 'https://www.parkstacoma.gov/place/browns-point-lighthouse-park/' }
    ]
  },
  {
    id: 'tolmie',
    tide: true,
    name: 'Tolmie State Park',
    sub: 'Puget Sound (Nisqually Reach) · Olympia · Shore access',
    lat: 47.1204, lon: -122.7758,
    updated: '2026-10-26',
    intro: 'A state park beach on Nisqually Reach, reached by a trail with stairs and a footbridge. The public beach ends at the park boundary.',
    closure: { title: 'Winter hours', text: 'Closed Mondays and Tuesdays through the winter, open 9 a.m. to dusk. The lower lot is closed through Nov 30; park in the upper lot.' },
    timing: {
      cols: ['Nov', 'Dec'],
      rows: [{ species: 'Sea-run cutthroat (release)', cells: ['Good', 'Good'] }],
      note: 'Our reading of WDFW guidance (Area 13 cutthroat among the best in Puget Sound, from boat or shore), not a report from this beach.'
    },
    tips: [
      ['Pass', 'A Discover Pass is needed to park.'],
      ['Where', 'Rocky beaches with larger gravel in 15 to 20 ft of water suit cutthroat; fish soft tides or slack.'],
      ['Boundary', 'The beach past the park boundary is private.']
    ],
    rulesTitle: 'Rules on the beach (Marine Area 13)',
    rules: [
      ['Salmon', 'Open year-round in Area 13: 2 a day, no more than 1 Chinook, Chinook at least 22 in; release chum and wild fish as posted.'],
      ['Crab', 'Closed in Marine Area 13 in 2026.'],
      ['Trout', 'Sea-run cutthroat are release only.'],
      ['Hooks', 'Barbless in Marine Areas 5 to 13.']
    ],
    sources: [
      { label: 'Washington State Parks: Tolmie', url: 'https://parks.wa.gov/find-parks/state-parks/tolmie-state-park' },
      { label: 'WDFW: Marine Area 13', url: 'https://wdfw.wa.gov/fishing/locations/marine-areas/south-puget-sound' },
      { label: 'eRegulations: Marine Area 13', url: 'https://www.eregulations.com/washington/fishing/marine-area-13' }
    ]
  },
  {
    id: 'codiga-park',
    tide: true,
    name: 'Codiga Park',
    sub: 'Green (Duwamish) River · Tukwila · River bank',
    lat: 47.4906, lon: -122.2701,
    updated: '2026-10-26',
    intro: 'A small park on a tidal stretch of the Duwamish, on a restored wetland, with river access and a natural shoreline. A local salmon spot in season.',
    closure: { title: 'Chinook are closed this year', text: 'An August emergency rule closed Chinook retention on this part of the river. Coho and chum stay open within the limit below.' },
    timing: {
      cols: ['Early Nov', 'Late Nov', 'Dec'],
      rows: [{ species: 'Chum', cells: ['Good', 'Good', 'Fair'] }],
      note: 'Our reading of when chum run up the Green (October to December), not a report from this park.'
    },
    tips: [
      ['Daylight only', 'A night closure and anti-snagging rule apply through Dec 31: fish in daylight and hook fish in the mouth.'],
      ['Tide', 'This stretch is tidal, so the tide changes the water.'],
      ['Gear', 'Older reports from nearby Tukwila banks used corky and yarn and gold spoons.']
    ],
    rulesTitle: 'Rules on the lower Green',
    rules: [
      ['Salmon limit', '6 a day, no more than 3 adult coho and chum combined'],
      ['Chinook', 'Retention is closed', 'Release'],
      ['Night closure', 'Night closure and anti-snagging rule Aug 20 to Dec 31'],
      ['Eating fish', 'The state health department advises against eating resident fish or shellfish from the Lower Duwamish. Check its advice for salmon.']
    ],
    sources: [
      { label: 'WDFW emergency rule: Green (Duwamish) Chinook', url: 'https://wdfw.wa.gov/fishing/regulations/emergency-rules/green-duwamish-river-chinook-retention-closed-2026-08' },
      { label: 'eRegulations: Puget Sound rivers D-K', url: 'https://www.eregulations.com/washington/fishing/puget-sound-coastal-rivers-special-rules-d-k' },
      { label: 'Seattle Southside: Codiga Park', url: 'https://www.seattlesouthside.com/directory/codiga-park/' }
    ]
  }
];
