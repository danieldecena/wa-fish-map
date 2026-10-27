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
