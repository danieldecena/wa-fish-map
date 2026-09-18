# Web demo — spec

A browser preview of WA Fish Map. **Not a product.** Its job is to let someone
who is not holding an iPhone see that the app is real, then send them to the
App Store. Every exit leads there.

Audience is an Apple hiring manager first, an angler second. That ordering
decides several calls below.

## Non-goals

- Feature parity. Live weather, tides and buoys stay in the app.
- Accounts, catch logging, social. That is the crowded, spot-burning half of
  the category and is worthless without users.
- Being the canonical implementation. When the demo and the app disagree, the
  app is right and the demo is stale.

## Stack

**MapKit JS**, not MapLibre. Apple's own web SDK, free to 250k map views/month.
Rebuilding Apple's map on OSM tiles reads badly to the audience this page is
for; staying in the stack reads well.

Token: MapKit JS wants a JWT signed with the MapKit private key (ES256, kid =
key id, iss = team 877MLS29T9). Generate one with a long expiry and an `origin`
claim pinned to `danieldecena.github.io`, then embed it. Domain-restricted
tokens are meant to ship in client code — this is the documented pattern, not a
leak. Regenerate before expiry; note the date in this file when you do.

No framework. One HTML file, one JS module, one JSON payload. React earns
nothing here and costs load time.

## Data — build-time extract, not runtime fetch

`Resources/access-sites.sample.geojson` is a 4K sample; the real sites come
from the live WDFW ArcGIS fetch at runtime in the app. The demo must not depend
on that at page load — CORS, latency and WDFW's uptime are three failure modes
for a page whose whole job is a good first impression.

So: `scripts/build_web_data.py` runs once, on demand, and writes a single
`site/data/sites.json`:

- Sites: id, name, lat/lon, water type, county, launch type, amenities,
  the marine area or waterbody it resolves to. Source: the same ArcGIS
  endpoint the app uses (`geodataservices.wdfw.wa.gov/.../MajorFishingArea`)
  plus the access-site layers.
- Fisheries: `fisheries.json` verbatim — 16 areas, their species with
  `bestMonths`/`goodMonths`, and the 13 `seasonRisk` rows.
- Waterbodies: the `freshwater.byWaterbody` and `waterbodySites` lists.

Skip `rivers.json` (1.3M) and `river_stats.json` (940K) in v1. River rendering
is the heaviest thing in the app and the least legible at demo zoom levels.

Target payload: under 500KB gzipped. Check it; if sites.json alone blows that,
drop amenity fields before dropping sites.

## Rating — one port, kept honest

Port `Fishery` rating and the seasonRisk cap to JS. It is small:

1. For a site's area and the picked month, a species is `prime` if the month is
   in `bestMonths`, `good` if in `goodMonths`, else `slow`.
2. If any `seasonRisk.match` matches the species name (case-insensitive
   substring) and the month is in its `months`, cap at `fair` and carry the
   badge "Season varies — verify" with its `reason`.
3. A site with no listing for the picked species is grey, never guessed.

Colours are the app's: prime `#E4572E`, good `#EE8C2B`, fair `#EFC050`,
slow `#3D8BCD`, none `#9AA8A7`.

Write the JS port against the same cases the Swift tests cover, and put a
handful of assertions in a plain `test.html` — not because the demo needs a
suite, but because a visibly wrong rating on a public page is the one failure
that costs more than the demo is worth.

## Interaction

Two controls, nothing else:

- **Month** — a 12-stop selector, not a date picker. The demo has no tides or
  weather, so day precision would imply data it does not have.
- **Species** — from the fisheries list, plus "All species". Changing it
  recolours every pin.

Site tap opens a card: name, water body (named prominently — the state's own
app is criticised for leaving waters unlabelled), county, launch type,
amenities, what is biting that month with the bait note, and any season badge.
The card's primary action is **Get it on the App Store**.

## URLs

Deep-link every site: `?site=<slug>&species=<name>&month=<n>`. The page restores
map centre, selection and card from the query string on load.

This is the feature that makes the demo useful beyond looking at it — someone
can send a spot to a friend, and a résumé or application can link straight to a
good-looking card rather than a cold map.

## Page furniture

Reuse the landing page's SF Pro type and palette; the demo lives at
`/wa-fish-map/demo/` under the same site. A fixed bar carries the App Store
badge (TestFlight until release) and one line: "Preview of the iPhone app —
live conditions, tides and buoys are in the app." That line is the whole
positioning; do not let the demo read as the product.

## Build order

1. `scripts/build_web_data.py` → commit `site/data/sites.json`
2. Rating port + `test.html` assertions
3. MapKit JS shell, pins, colours, legend
4. Site card + App Store exit
5. Month and species controls
6. URL state
7. Ship to `danieldecena.github.io/wa-fish-map/demo/`

Stop after 7. Rivers, heat overlay and live conditions are the app's job.
