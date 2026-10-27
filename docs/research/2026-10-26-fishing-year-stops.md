# Fishing Year: the two unconfirmed stops (2026-10-26)

Both stops are outside WDFW's access layer, so `seasons.json` carries a
`place_check` against OpenStreetMap. Lookups made 2026-10-26 with Nominatim
(search bounded to -122.6,47.6,-121.9,47.0, and reverse at zoom 18 and 16) and
the OSM API. Overpass timed out on three servers and was not used.

Control: the same bounded search for "Three Friends Fishing Hole Park" returned
way 1253006852 (leisure=park), so an empty search below is a real absence in
OSM, not a broken query.

## Green River Boat Ramp, Kent (green, stop 2): confirmed

- Reverse lookup at 47.3986, -122.2758 returns node 9727835924, an unnamed
  `leisure=slipway` on Russell Road South, Kent.
- OSM API, https://api.openstreetmap.org/api/0.6/node/9727835924 : 47.398619,
  -122.275768, tags `access=yes`, `fee=no`, `leisure=slipway`,
  `surface=concrete` (last edited 2023-09-18). 3.2 m from the stop.
- Name searches for "Green River boat ramp", "boat ramp Kent" and "slipway
  Kent" return nothing: the ramp has no name in OSM. The nearest named park is
  Van Doren's Landing Park (way 26224793), about 800 m north, so the ramp is not
  part of it as mapped.
- Verdict: the location is a public concrete ramp, as the stop's note says.
  Confirmed by OSM id rather than name; the build now accepts an `osm` id for an
  unnamed feature. The name "Green River Boat Ramp" is ours, not OSM's.

## Two Rivers Point, Puyallup-Sumner (puyallup, stop 1): still unconfirmed

- Searches for "Two Rivers Point" and "Two-Rivers Point" return nothing.
- Reverse lookup at 47.1998, -122.258: Riverwalk Trail (cycleway) 9 m away at
  zoom 18; Houston Road East at zoom 16.
- Against `WAFishMap/Resources/rivers.json`: the White River line is 11 m away
  and the Puyallup River line 50 m away, so the point sits at their
  confluence, which fits the name.
- "Sumner Link Trail" resolves to segments whose southern end is near 47.2148,
  -122.2400, about 2 km from the stop, so OSM does not show the trail reaching
  the point.
- Verdict: plausible but not confirmable from OSM, so `confirmed` stays false
  and the page keeps "Location unconfirmed". Confirming it needs a source that
  names the place with coordinates, or an OSM feature of that name.

### Follow-up web search, 2026-10-26 (later the same day): still unconfirmed

- TrailLink, https://www.traillink.com/trail/sumner-link-trail/ , known only
  from search-result text (the page and its PDFs returned HTTP 403, so no page
  date): "Parking is available at the south end of the trail at Two-Rivers
  Point and at the 24th Street Bridge near the north end of the trail." It
  calls the place trail parking, not river access, and gives no coordinates.
- The City of Sumner trails page, https://www.sumnerwa.gov/trails , does not
  mention Two Rivers Point.
- TrailLink also says the trail is closed from north of the 24th Street
  Bridge to south of Daffodil Bend, Spring 2025 to Fall 2027 (White River
  Restoration Project). It does not say whether the Two-Rivers Point lot is
  inside that closure.
- No source found gives coordinates, an address or a map pin, so nothing
  confirms or contradicts 47.1998, -122.258. Not yet opened: the City of
  Sumner 2024 parks plan PDF (the likeliest source of a map), Pierce County
  and City of Puyallup pages.

### City of Sumner parks plan, read 2026-10-26: named, not pinned

Source: City of Sumner, "2024-2030 Parks, Trails & Open Space Plan Update",
https://sumnerwa.gov/wp-content/uploads/2024/06/2024_ParksTrailPlan_webmain.pdf
(PDF created 2024-06-18; the same text is in Exhibit N of the 2024-09 update).

- Classification table: "NATURAL AREAS & GREENSPACES / In Sumner: Two-Rivers
  Point, shoreline areas along rivers ... Low-impact activities are allowed
  including walking, bird-watching and fishing (if appropriate)."
- Inventory: "Two Rivers Point | Open Space Area | No change" (no size given).
- Survey comment in Exhibit N (2023-04-25): "Does not always feel safe to park
  at the trail access lot. Would be nice if there were amenities at the two
  rivers point grassy area."
- Trail map (page 17): no label reads Two Rivers Point. An "Existing
  Trailhead" symbol sits at the south end of the Sumner Link Trail where the
  White River meets the Puyallup, west of Knoblauch Heritage Park, beside a
  small open-space parcel. With TrailLink's "south end of the trail at
  Two-Rivers Point", that places it at the confluence, which fits our point.
- WTA's Sumner Link Trail page gives trailhead coordinates 47.2007, -122.2531
  (State Street dead end), about 0.45 km east of our point. WTA does not use
  the name.

Verdict: the place exists, is public, and allows fishing, and two sources
together put it at the confluence. No single source names it with
coordinates, and the build confirms only from OpenStreetMap, so `confirmed`
stays false. The stop's note in `seasons.json` now says what the plan says
(the earlier note credited the plan with "south end", which only TrailLink
says).
