// Artifacts/salmon-rivers/season-places.js
/* Where each Washington Fishing Year season goes on the map's Seasons layer. Hand-maintained, like rules.js: when
   seasons-data.js gains or loses a season, test/season-places.test.js fails until this table matches.
   A place is drawn only when the season's own `where` text names it, and `evidence` is that phrase. Vague text such as
   "some Puget Sound rivers" names no place, so it stays in the season's sheet and is never guessed onto the map.
   `river` is a report river id from reports.js or a river id from rivers-tap.js; `point` is [lon, lat]. */
window.SEASON_PLACES = {
  'skagit-coho': [{ river: 'skagit', evidence: 'Skagit River' }],
  'chum': [{ point: [-123.06, 47.42], label: 'Hood Canal', evidence: 'Hood Canal south of Ayock Point' }],
  'steelhead': [{ point: [-124.38, 47.95], label: 'Olympic Peninsula rivers', evidence: 'Olympic Peninsula rivers' }],
  'perch': [{ point: [-122.26, 47.62], label: 'Lake Washington', evidence: 'Lake Washington' }],
  'spring-chinook': [{ river: 'columbia', evidence: 'Columbia' }, { river: 'cowlitz', evidence: 'Cowlitz' }, { river: 'lewis', evidence: 'Lewis' }],
  'lingcod': [{ point: [-124.10, 46.90], label: 'Westport', evidence: 'Westport' }],
  'rockfish': [{ point: [-124.10, 46.90], label: 'Westport', evidence: 'Westport' }],
  'walleye': [{ river: 'columbia-river', evidence: 'Columbia River' }],
  'trout': [{ point: [-122.33, 47.61], label: 'Lowland lakes near Seattle', evidence: 'Lowland lakes near Seattle' }],
  'kokanee': [
    { point: [-122.33, 48.73], label: 'Lake Whatcom', evidence: 'Lake Whatcom' },
    { point: [-120.02, 47.84], label: 'Lake Chelan', evidence: 'Lake Chelan' },
    { point: [-118.06, 48.61], label: 'Lake Roosevelt', evidence: 'Lake Roosevelt' }
  ],
  'crab': [
    { point: [-122.20, 47.98], label: 'Everett', evidence: 'Everett' },
    { point: [-122.38, 47.81], label: 'Edmonds', evidence: 'Edmonds' },
    { point: [-123.02, 48.53], label: 'San Juan Islands', evidence: 'San Juans' }
  ],
  'sockeye': [{ point: [-121.66, 48.70], label: 'Baker Lake', evidence: 'Baker Lake' }],
  'pink': [
    { point: [-122.38, 47.81], label: 'Edmonds', evidence: 'Edmonds' },
    { point: [-122.30, 47.95], label: 'Mukilteo', evidence: 'Mukilteo' },
    { river: 'green-river-2', evidence: 'Green' },
    { river: 'nisqually-river', evidence: 'Nisqually' }
  ],
  'fall-chinook': [{ river: 'lewis', evidence: 'Lewis River' }],
  'fall-coho': [{ river: 'skagit', evidence: 'Skagit River' }]
};
