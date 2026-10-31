# Spike: depth shading from open bathymetry (2026-10-29)

Question: can open bathymetry give the web map a Fish Deeper or Navionics look (colour
relief, smooth contours, whole-coast coverage) when the published page cannot make a
single network request, so everything has to be baked into its files? This is research and
a prototype. Nothing under `Artifacts/salmon-rivers/` was changed and nothing was published.

**Short answer.** Yes for the shading, with a datum caveat. NOAA's CUDEM (public domain, 3 m
grid) bakes into a small raster that shows real seabed shape the current contour lines do not.
Puget Sound alone fits the 2 MB budget; the Strait, San Juans and outer coast do not, unless
they are cut to a coarser grid. It is a model of the seabed, not a survey, and it is not sonar.

## Files

| Path | What it is |
| --- | --- |
| `index.html` | The demo. Three areas, side by side: (A) today's ENC lines from `depth-data.js`, (B) the baked shading with smoothed DEM contours, (C) both. Wheel to zoom, drag to pan, "Show raster pixels" shows the texels. Open it from a checkout (it reads `../../../Artifacts/salmon-rivers/depth-data.js`, unchanged, and makes no network request). |
| `*-relief.png`, `*-mask.png`, `shading-data.js` | The baked product: 512 px indexed-colour relief per area (land is transparent), a water mask for panel A, and the smoothed contours in the page's own path format plus legend and stats. Generated; do not hand-edit. |
| `metrics.json` | Every number quoted below, per area. |
| `screenshots/` | The demo as rendered by Playwright (1x and 4x). |
| `../../../scripts/spike_depth_shading.py` | `fetch` (download) and `build` (bake and measure). Its docstring has the venv recipe; the numpy stack never goes in the repo or the system python. |
| `../../../scripts/test_spike_depth_shading.py` | Unit tests (the ENC path parser, datum sign, contour rings, the colour rule). They skip under the system python and run in the spike venv. |

Re-run: create a venv outside the repo, `pip install numpy pillow scipy scikit-image tifffile`, then
`python -I scripts/spike_depth_shading.py fetch --work <dir>` and `... build --work <dir>`.
`fetch` takes about 20 s per area (three DEM windows, 146 MB in all, refused above 80 MB each)
plus about a minute for the ENC soundings, because NOAA's encdirect services answer "Could not
find service" at random and the script retries. `build` takes about 1 s per area.

## Licence and data table

Quotes are one short phrase each, from the page named. "Bake a derived product" means a
raster or contour set computed from the data and published inside the page.

| Source | Terms (quote) | Attribution | Resolution | Vertical datum | Washington marine coverage | Bake a derived product? |
| --- | --- | --- | --- | --- | --- | --- |
| **NOAA NCEI CUDEM 1/9 arc-second tiles** (used for the prototype) | NCEI metadata: "Not subject to copyright protection within the United States." Also "Not to be used for navigation" and a no-warranty liability clause | A citation is requested, not a licence condition: CIRES / NCEI, doi:10.25921/ds9v-ky35, "[indicate subset used]" | 1/9 arc-second: measured 2.3 m E-W by 3.4 m N-S at 47 N. Coarser 1/3 and 3 arc-second bands telescope outward | NAVD88, metres (NAD83 horizontal). Not MLLW | Yes at the three test windows and at 7 more marine points I probed: Hood Canal, mid-Strait, Bellingham Bay, Grays Harbor, off Westport, off Cape Flattery, the Columbia at Astoria (tiles dated 2017 to 2025). Not exhaustively checked | Yes. US government work with no licence; keep the citation and the "not for navigation" text |
| **NOAA ENC** (already in the page) | Coast Survey Data Licensing page: "dedicated to the public domain via the Creative Commons Zero 1.0 Universal" | None required under CC0 | Vector contours and spot soundings, not a grid | MLLW (feet below low tide on the page) | The harbour and coastal bands used here; the page's contours stop at 60 ft in Commencement Bay | Yes (CC0) |
| **Seascape** (`openwatersio/seascape`, was `gebco-tiles`; tiles at tiles.openwaters.io) | Code is BSD-3-Clause (GitHub's "NOASSERTION" is two stacked notices). Tiles: CC BY 4.0, "free for any use" with the credit "(c) Open Waters". Underlying data keep their own terms | `(c) Open Waters (https://openwaters.io/charts/seascape#license)`. Its README says the TileJSON carries every source's credit, but the `raster.json` I fetched carried only "(c) Open Waters" | Terrarium raster DEM; z13 tiles at the three windows I pulled (about 6.5 m per pixel at 47 N, source about 10 m). Its catalogue lists S-102 to z15 where NOAA has it; I did not check that | Per source. CUDEM is corrected to MLLW with a VDatum grid; GEBCO and EMODnet are about MSL. A source seam is a datum seam | Yes, where CUDEM or S-102 is the winner. Verified at the three test areas only | Yes with the CC BY credit. I did not find or read terms of service for bulk tile pulls; the README invites use. Pull politely and cache |
| **GEBCO grid** | gebco.net: "placed in the public domain and may be used free of charge", acknowledge the source | Acknowledge GEBCO; wording is in the grid's documentation | 15 arc-second: about 460 m N-S by 310 m E-W at 47 N. See "How coarse" below | About mean sea level (per Seascape's README) | Global, but a 9 km window is a 29 by 19 grid | Yes |
| **EMODnet Bathymetry DTM 2024** | Not read in this spike. Moot: it does not cover Washington | n/a | 1/16 arc-minute, about 115 m | LAT | European seas and a piece of the Caribbean only (box 36 W to 43 E, 15 N to 90 N). Nothing in Washington | n/a |
| **prozessor13/seamap** | Repo is MIT, `LICENSE.md`, "Copyright (c) 2026 Max Demmelbauer" | Credit OSM (ODbL) for the seamarks | Bathymetry is not in the repo. Its viewer points at third-party PMTiles of EMODnet and GEBCO (max zoom 11, and 9 for GEBCO); GEBCO's own 460 m is the floor in Washington | LAT for EMODnet, about MSL for GEBCO | EMODnet part: none. GEBCO part: coarse | The code, yes. The hosted bathymetry tiles carry no stated terms in the README; unclear, so do not rely on them. Its contours come from maplibre-contour running in the browser, which needs network tiles |

Lakes and the Columbia (page covers both), probed once each with the CUDEM service and not studied:

- **Lake Washington**: lakebed elevations are in CUDEM (a 7 by 22 km window has 41% of its area below -2 m NAVD88, minimum -62 m). Depth would be lake surface minus bed, and the DEM does not carry the surface height, so each lake would need its own constant.
- **Lake Union**: also has bed values, but see "Where it is wrong".
- **Lake Sammamish**: flat at 1.5 m, so no bed. **Lake Chelan**: no data (east of the coastal coverage). So lake coverage is patchy and per-lake.
- **Columbia**: the channel shows up (a Longview to Kalama window dips to -37 m NAVD88; Astoria reads -8.9 m). Its datum is a river datum that moves with flow and tide, so an MLLW shift is not right there. Not studied further.
- Nothing I found gives open gridded bathymetry for the other inland lakes.

Not evaluated: NOAA S-102 bathymetric surfaces directly, the NCEI Coastal Relief Model, WDFW lake maps.

## What was built

For three windows, from 3 m CUDEM: a 512 px wide indexed PNG (17 to 23 m per pixel) with a
calm blue ramp and a hillshade, land transparent, and contours at the ENC's own 16 levels
(3 ft to 600 ft), smoothed (Gaussian, 1.2 px at 2x the output grid), traced with marching
squares and simplified to 0.6 px, written in the page's `M x y l dx dy` path format.

The ramp (feet below low tide): 0 `#e8f3f6`, 6 `#d6eaf1`, 18 `#badbe8`, 30 `#a0cde0`, 60 `#80b7d2`,
120 `#609bc0`, 240 `#447aa8`, 480 `#2e5a8a`, 800 `#1e3e6c`. Nothing is red, orange, amber or
yellow, and no stop is within 100 RGB units of the rating blue `#0088ff`; the unit test checks
that, and that the check rejects the four rating colours.

Datum step: CUDEM is NAVD88, the page is MLLW. Each window is shifted by the NAVD88-MLLW
separation at its nearest tide station (CO-OPS datums API, fetched 2026-10-29): Tacoma 0.729 m,
Seattle 0.715 m, Port Angeles 0.129 m. See the first finding below for what that costs.

## Measurements

Sizes and time (`metrics.json`; build time is per area on this Mac, download excluded):

| Area | Window | Water | Output | m per px | PNG 512 | WebP q80 512 | PNG 256 | PNG 1024 | DEM contours | ENC lines, same box (est.) | Build |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Commencement Bay, Tacoma | 80 km2 | 37% | 512x500 | 17.7 | 33.1 KB | 9.4 KB | 8.8 KB | 89.1 KB | 20.7 KB | 5.4 KB | 1.2 s |
| Port Angeles harbour | 105 km2 | 47% | 512x381 | 23.2 | 22.2 KB | 4.5 KB | 5.7 KB | 59.3 KB | 11.7 KB | 3.9 KB | 0.7 s |
| Elliott Bay, Seattle | 90 km2 | 50% | 512x566 | 17.6 | 49.3 KB | 12.2 KB | 13.8 KB | 131.1 KB | 27.6 KB | 14.3 KB | 1.1 s |

The ENC column is a rough count (vertices in the box times 6 bytes); the DEM contours are in
5.5 m path units, the page's are 11 m.

**Extrapolation.** Per square kilometre of water (all three windows pooled, 124 km2):
PNG 512 0.84 KB, WebP 0.21 KB, PNG 256 0.23 KB, contours 0.48 KB (0.24 to 0.28 KB with more
simplification: path unit 0.01, tolerance 1.2 to 1.5 px, smoothing 1.5 to 2 px). Puget Sound
is about 2,600 km2 of water (Wikipedia and Encyclopedia of Puget Sound agree on 2,600 to 2,632).
At this pixel size and linear scaling:

| Product for Puget Sound | Size |
| --- | --- |
| Relief as lossy WebP | about 0.5 MB |
| Relief as indexed PNG | about 2.1 MB (over budget) |
| Relief as indexed PNG at half the resolution (35 to 45 m) | about 0.6 MB |
| Smoothed contours, finer / coarser | about 1.2 MB / 0.6 to 0.7 MB |
| **WebP plus coarser contours** | **about 1.1 to 1.2 MB** |

I did not measure the Strait, San Juans or outer coast, and I have no sourced water area for
them. Treat them as roughly doubling the area, so they would not fit unless the grid goes to
about 40 m per pixel. Hillshade texture costs bytes; WebP at q80 looked clean in the demo
panel but I only judged it by eye (the screenshots use the PNG).

**Against the ENC spot soundings** (NOAA's own SOUNDG points from the encdirect harbour and coastal
bands, metres to MLLW, converted to feet; 880, 1,065 and 2,069 points after de-duplication; 4,
0 and 11 where the DEM says land are counted apart, and 219 in Lake Union and Portage Bay are
left out). CUDEM may well contain the same surveys, so this is a check on consistency, not
independent truth.

| Area | Median DEM minus ENC | Mean abs. error | Within 3 ft | After removing the median: MAE / within 3 ft | Soundings over 150 ft: median (p10 to p90) |
|---|---|---|---|---|---|
| Tacoma | +1.57 ft | 2.78 ft | 72% | 2.05 ft / 82% | +1.29 (+0.1 to +6.3) |
| Port Angeles | +1.86 ft | 2.66 ft | 66% | 1.92 ft / 84% | +1.60 (-0.8 to +4.0) |
| Elliott Bay | +1.74 ft | 2.67 ft | 72% | 1.86 ft / 87% | +1.62 (+0.2 to +4.1) |

Five specific soundings per area (lat, lon; ENC sounding ft; DEM ft; DEM minus ENC):

| Area | Position | ENC | DEM | Diff |
|---|---|---|---|---|
| Tacoma | 47.27081, -122.42165 | 2.3 | 2.9 | +0.6 |
| Tacoma | 47.28607, -122.41530 | 33.8 | 34.9 | +1.1 |
| Tacoma | 47.26348, -122.43788 | 96.5 | 96.9 | +0.4 |
| Tacoma | 47.30822, -122.44904 | 366.8 | 367.9 | +1.1 |
| Tacoma | 47.30684, -122.45730 | 549.9 | 549.9 | +0.1 |
| Port Angeles | 48.11568, -123.39956 | 4.9 | 5.4 | +0.5 |
| Port Angeles | 48.14295, -123.41843 | 18.7 | 22.7 | +4.0 |
| Port Angeles | 48.12547, -123.44339 | 39.7 | 42.7 | +3.0 |
| Port Angeles | 48.13231, -123.43722 | 84.0 | 88.4 | +4.4 |
| Port Angeles | 48.14625, -123.39303 | 215.9 | 219.1 | +3.2 |
| Elliott Bay | 47.58525, -122.36772 | 3.0 | 4.7 | +1.8 |
| Elliott Bay | 47.59008, -122.34308 | 34.1 | 38.9 | +4.8 |
| Elliott Bay | 47.62663, -122.39595 | 65.9 | 66.2 | +0.3 |
| Elliott Bay | 47.60300, -122.38794 | 237.2 | 238.7 | +1.5 |
| Elliott Bay | 47.59933, -122.41316 | 569.9 | 569.0 | -0.8 |

**Against the page's contour lines.** At five contour labels per area (the ENC says the point is
on that contour; DEM depth at the label point, then the range within 12 m, because the page's
path units are 11 m and a steep bottom turns that rounding into feet):

| Area | Position | ENC contour | DEM at point (range within 12 m) | Diff |
|---|---|---|---|---|
| Tacoma | 47.28720, -122.48708 | 6 | 7.9 (4.8 to 14.5) | +1.9 |
| Tacoma | 47.29300, -122.49402 | 12 | 20.9 (15.7 to 25.7) | +8.9 |
| Tacoma | 47.28820, -122.48867 | 18 | 27.0 (16.5 to 31.3) | +9.0 |
| Tacoma | 47.27810, -122.46902 | 30 | 28.8 (24.3 to 35.1) | -1.2 |
| Tacoma | 47.27450, -122.45645 | 60 | 82.2 (71.7 to 93.0) | +22.2 |
| Port Angeles | 48.13990, -123.45494 | 6 | 7.3 (4.7 to 9.4) | +1.3 |
| Port Angeles | 48.13890, -123.46087 | 12 | 16.9 (15.6 to 18.1) | +4.9 |
| Port Angeles | 48.13350, -123.48673 | 18 | 17.5 (15.9 to 18.8) | -0.5 |
| Port Angeles | 48.13710, -123.49251 | 30 | 31.5 (31.2 to 31.7) | +1.5 |
| Port Angeles | 48.14950, -123.47951 | 60 | 65.0 (62.8 to 69.2) | +5.0 |
| Elliott Bay | 47.57080, -122.41600 | 6 | 7.7 (7.1 to 8.4) | +1.7 |
| Elliott Bay | 47.64250, -122.42235 | 12 | 15.8 (15.0 to 18.3) | +3.8 |
| Elliott Bay | 47.64200, -122.42264 | 18 | 19.3 (17.8 to 21.3) | +1.3 |
| Elliott Bay | 47.56770, -122.41210 | 30 | 37.7 (23.2 to 50.0) | +7.7 |
| Elliott Bay | 47.57280, -122.42235 | 60 | 62.3 (59.9 to 65.0) | +2.3 |

Over every ENC contour vertex in the three boxes (926, 661 and 2,441): measured at the vertex
itself the DEM is a median 5.8, 3.2 and 4.9 ft away from the contour's value (28%, 48% and 33%
within 3 ft). Allowing the nearest DEM depth within 12 m of the vertex, the median is 1.0, 1.3 and
1.2 ft (79%, 74% and 72% within 3 ft; p90 is 5.0, 5.2 and 12.2 ft). Measured sideways, the median
distance from an ENC contour to my contour of the same level is 8 to 18 m in Tacoma and Elliott
Bay, 26 m at 18 ft and 60 m at 60 ft in Port Angeles (the ENC lines are sparser and more
generalised there). The page's lines and the DEM agree about where the bottom is; they differ
by the page's 11 m rounding, and the DEM reads about 1.6 ft deeper than the chart at the same spot
(datum shift and chart caution are both plausible causes; this spike does not separate them).

**How coarse GEBCO and its neighbours are here.** I did not download GEBCO. As a simulation I
averaged the 3 m DEM down to coarser grids and re-scored it against the same soundings with the
shared bias removed, so only the resolution effect shows:

| Grid | Cells in a Tacoma window | MAE (Tacoma / Port Angeles / Elliott) | Within 3 ft |
|---|---|---|---|
| 1/9 arc-second (3 m) | 3,888 x 2,592 | 2.1 / 1.9 / 1.9 ft | 82 / 84 / 87% |
| 1/3 arc-second (10 m) | 1,296 x 864 | 2.1 / 1.9 / 1.9 ft | 82 / 84 / 87% |
| 3 arc-second (90 m, Coastal Relief Model class) | 144 x 96 | 5.4 / 3.0 / 4.6 ft | 50 / 70 / 58% |
| 15 arc-second (GEBCO, 460 x 310 m) | 29 x 19 | 22.4 / 14.8 / 18.9 ft | 15 / 31 / 13% |

A whole 9 km window is 29 by 19 GEBCO cells. A pier, a launch ramp, Ediz Hook or a drop-off is
smaller than one cell. The real GEBCO grid has its own errors on top of this, so its numbers could
only be worse. GEBCO is not an option for this page.

**The other way to get the datum right: Seascape's z13 tiles.** I pulled 47 tiles (1.3 MB) and
scored them against the same soundings: median -0.7, +0.9 and -0.4 ft, MAE 2.1, 2.1 and 1.6 ft,
78 to 87% within 3 ft. That is not a like-for-like score (it uses every sounding where the tile
has a depth, so Lake Union is not filtered the way it is above), but it shows no systematic
offset where my station shift leaves one, with a 6.5 m pixel. Their
corrections come from NOAA's VDatum grid; mine is one constant per window.

## What the shading looked like

See `screenshots/`. At 1x (a window nine kilometres across on a 470 px panel) it reads like a
chart's depth fill: a pale shore running to blue ink in the basins, with the hillshade picking out
slopes, channels and the dredged waterways, and the smoothed contours sitting well on the colour.
Compared with the ENC lines on the same view it shows far more:

- **Real features the lines miss.** In Commencement Bay, a ring at about 47.3034, -122.4652 is a
  knoll: DEM 428 ft on top of a 540 ft floor, and two ENC soundings on its crest read 426 and 429
  ft. The published lines never draw it, because the baked bands stop at 60 ft in that bay.
  Counted over the three windows, 72%, 63% and 40% of the water deeper than 10 ft has no ENC
  contour within 250 m, and in 55%, 24% and 70% of that the DEM sees more than 15 ft of relief
  within 150 m: about 11, 7 and 12 km2 of seabed with structure and no line. Elliott Bay's biggest
  blobs are the deep basin and the steep western slope of the window (about 125 to 773 ft), and
  Port Angeles' are inside and just outside the harbour (about 50 to 350 ft).
- **Whole bays instead of shore hugging lines.** In Tacoma the page's lines stop at 60 ft; in Port
  Angeles they are a few fragments out to 240 ft. The shading fills the whole basin.

Where it is wrong or blurry:

- **Steep ground and structures.** Typical error is 2 to 3 ft, but the six worst misses per area
  are tens of feet: +132 ft against a 168 ft sounding at 47.27689, -122.45784 in Tacoma, +32 ft
  against a 6.9 ft sounding at 48.12586, -123.44646 in Port Angeles. I did not inspect each one;
  they sit where the bottom is steep or near the shore, and a 3 m grid still smears a wall. A pier
  deck or a berth dredged after the 2023 tile would read wrong the same way.
- **Lakes and non-tidal water.** In the Elliott window the Lake Union and Portage Bay corner is
  shaded as if tidal, with depths that mean nothing (219 ENC soundings there read 25 to 40 ft
  against DEM values near 0 to 13 ft). Fresh water held above sea level needs its own surface
  height. The demo leaves it visible so you can see the failure.
- **A tile seam.** The same corner has a straight rectangular edge that looks like where two
  source tiles meet (not confirmed).
- **Smoothing artefacts.** At 8x the smoothed contours show their facets (a 12-sided ring in the
  Tacoma knoll). Hillshade glints on lit slopes, so I capped the brightness.
- **Datum.** See the table: a station-based shift leaves 1.3 to 1.9 ft of bias in deep, flat water
  (soundings over 150 ft), the same in all three areas and in old and new survey years. I
  could not tell whether the cause is the station separation versus VDatum, chart shoal bias, or both.
  Seascape's VDatum-corrected tiles show no such offset, which points at the shift.

**Zoom.** It is a raster, so it softens before it breaks. On a 390 px phone, one 17.7 m
pixel is 0.3 screen px when the view is 22 km across, 0.8 when the 9 km window fills the screen,
1.5 at 4.5 km, 3 at 2.3 km and 6 at 1.1 km. In the demo, 1x to 2x is clean, 4x (3.7 screen px a
raster pixel, the Elliott 4x screenshot) is soft but still reads as relief, 8x is blurred, and the
"Show raster pixels" toggle shows blocks from about 4x. On a 1,500 px desktop screen every one of those
views has about four times as many screen pixels per raster pixel: a pier-level view of 1 km is
about 27, which is mush. The vector contours stay sharp at every zoom (the page already treats them that
way). Holding up at pier scale needs 3 to 5 m per pixel, which costs roughly 3 to 6 KB per
square kilometre of water (extrapolated from the 0.05 to 0.1 byte per water pixel of the WebP
above, not built): fine for a 1.5 km square around each of the roughly 90 marine sites in
`typical.js` (about 0.6 to 1 MB), not for the whole Sound (about 8 to 16 MB).

## Recommendation

**Worth integrating: the shading, from NOAA CUDEM, with the datum solved properly, as a new
layer or a sub-layer of Depth, keeping the ENC lines and labels on top.** Do not replace the
ENC lines: they are the chart (shoal-biased, with the page's wording and the `+` estimate built
around them), and the DEM contours are a second opinion that is not authoritative. Offer the DEM
contours, if at all, off by default.

Source choice, in order:
1. **CUDEM, with VDatum-corrected heights.** Either take Seascape's z12 or z13 tiles at build time
   (CC BY 4.0, a visible credit, MLLW already applied, tens of MB of build-time download for the
   Sound at z13 if resampled down: about 900 tiles in its box, many of them land, at the 27 KB
   average of the 47 I pulled; an estimate) or rebuild the datum step from NOAA VDatum ourselves. Seascape
   is the shortcut; its tile terms for bulk pulls are unstated, and it is a third party that can
   move or change. NCEI's ImageServer is stable and public domain but needs the datum work.
2. Seamap, GEBCO and EMODnet: no. EMODnet does not cover Washington, GEBCO is 460 m, and Seamap
   has no bathymetry of its own.

What it takes:
1. A build script `scripts/build_depth_shading.py` (this spike's script is the start): pull the
   source, shade, quantise, write one generated `depth-shading.js` (`window.DEPTHSHADE`) with
   WebP images as data URIs (or beside it) plus bounds and legend. Generated header, never
   hand-edited.
2. `index.html`: add the script, and in `depthBuild` an SVG `<image>` per tile inside the
   viewport group under the contour paths, with `preserveAspectRatio="none"` and the map-unit
   extents from the file; hide it above a zoom limit; update the layer key and sheet text and
   the credit line (NCEI citation, "Open Waters" if Seascape). Whether the publisher's frame
   loads images from sibling files is untested: inlining data URIs is the safe default.
3. Tests: generated-file header, total size under 2 MB, bounds inside Washington, the ramp rule
   (this spike's test), no `fetch(`, no network (the existing `tides.test.js` check and
   `check-week.mjs`), and a datum check against a few ENC soundings so the 1.5 ft class of bias
   cannot come back unseen.
4. Update `README.md` and the Web pages section of `CLAUDE.md`, then republish using the url
   recorded in `artifact.json`.

Optional, and probably the biggest practical win for a fisher: a small 8-bit depth grid beside
the colour raster so the `+` mark reads the DEM instead of interpolating between two contour
lines. That turns "about 30 ft" into a reading with a stated error.

Size and licence risks: Sound alone about 1.1 to 1.2 MB, outer coast and Strait not affordable at
this pixel size; CC BY credit has to be visible if Seascape is the source; CUDEM needs the
"not for navigation" text kept; the shading will look more authoritative than it is, so the layer
copy must keep saying "a guess from a model, not a survey". The ramp must stay off the rating
colours.

What it would not do: no sonar (Navionics SonarChart and Fish Deeper maps rest on boat sonar
logs; I did not verify how either is built, only that nothing in this data is that), no bottom
hardness or cover, no live tide (it is MLLW; the page already has tides and could add "depth now"
in the readout), no rocks, wrecks or pier structure, no change since the last survey (soundings
here run from 1995 to 2026), patchy lakes, and nothing for the rivers.

**MapLibre: not worth it for this.** The no-network rule is the blocker either way: its main
strengths (tile loading, on-the-fly contours from DEM tiles, smooth raster resampling) all want
network tiles, and you would bake the data the same way regardless. A baked image in an SVG
`<image>` gives the same picture. A MapLibre move would cost a rewrite of the pins, clustering,
sheets and layers, roughly a megabyte of library, and WebGL and worker behaviour inside the
publisher's frame that I have not tested. If a MapLibre move is ever wanted, it should be for
other reasons.

## Not downloaded, verified or measured

- The real GEBCO grid (the coarseness figure is a simulation from CUDEM). EMODnet's licence text.
- Seascape tile terms of service beyond its README. Seascape coverage outside these three windows.
- CUDEM coverage of every Washington marine water; I probed 14 points and the three windows.
- Whether the published frame loads sibling images, or how WebP decodes in every target browser.
- How Fish Deeper or Navionics build their maps (general knowledge only).
- Water areas for the Strait, San Juans and outer coast (no sourced figure), so no full-coast size.
- The shading as lossy WebP in the demo (the demo uses PNG; WebP sizes are measured, not looked at in page).
- Independent depth truth: the ENC soundings and CUDEM may share their surveys. Nothing here is
  a field check, and nothing is for navigation.
- NOAA's `enc_approach` service answered "Could not find service" on some calls and the other bands
  returned soundings only for the harbour and coastal bands; the build records any band it skipped.
