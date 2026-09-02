# WAFishMap — Status

## Confirmed working

- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; only
  the "Oregon" polygon is unseeded) plus 12 freshwater counties. WDFW-checked
  2026-08-30. FisheryTests + FishingMapModelTests green (13/13).
- `fisheries.json` v1 Puget Sound seed cross-checked against WDFW; corrections
  applied (see decision log).
- Dawn/dusk comes from real sun times: `SolarTimes` (NOAA equations, pure, no
  network) at the map's camera center, with the fixed hour buckets kept as the
  fallback. Full suite green: 35 tests, 8 suites, iPhone 17 sim.
- Season/closure capping ships: a curated `seasonRisk` table in fisheries.json
  is matched to species by case-insensitive substring at load, stamping
  `riskMonths` that clamp a species to `.fair`, so a fishery whose season is set
  annually can never render as Prime. Capped species carry a "Season varies —
  verify" badge and their reason. 11 table rows cover the 42 entries whose notes
  already described a closure. Full suite green: 65 tests, 11 suites.
- Ratings run a thermal ramp — Slow azure, Fair amber, Good orange, Prime red —
  as four explicit stops. Above 150km altitude a site draws as an 11pt dot
  instead of a balloon pin.
- The heat overlay draws each grid cell as a tiling MapPolygon, ranked against
  the other cells rather than normalised to the densest one, in four violet
  bands over a muted basemap. Cell size follows the camera.
- The map opens on the user's location when a fix lands inside Washington and
  they have not moved the camera; a denied permission now says so and links to
  Settings.
- Marine launch and pier sheets show that day's NOAA high/low tides for the
  nearest bundled station (170 WA + Columbia-mouth). Follows the map date;
  next extreme after the plan time is highlighted. Full suite: 73 tests, 12 suites.
- Zoomed-out pins cluster on the same grid as the heat overlay. Count and best
  rating; tap zooms into the cell. Heat stays a toggle. 78 tests, 13 suites.
- Species-first picker recolours pins, clusters, heat, and area fills by an
  exact species name from the guide; missing listings stay gray. Date picker
  unchanged. 80 tests, 13 suites.

## Known broken

- The verify badge (Task 5) has not been seen on screen. Injected simulator taps
  were unreliable all session, so it is proven by tests and by reading the diff,
  not by observation.
- The camera guard has a disclosed residual: a genuine user gesture made BEFORE
  the WDFW load completes is misclassified as non-user, so a later location fix
  would still recentre. Narrower than the bug it replaced, and documented in the
  code. Narrower again as of the `isCameraMove` fix below: tap-driven zooms are
  now recognised at all, so only the pre-load window remains.

## Next Up

- Verify remaining default-covered counties if desired (Pierce, Mason, Kitsap,
  Thurston left on the statewide default by design — add only if distinct).
- WeatherKit wind/precip at plan time — likely blocked on a paid-account
  entitlement.

## Decision log

### 2026-09-01 (camera gestures, protected-area default)

- Decided: `SiteDetailSheet.protectedAreaCheck` defaults to `.unavailable`, not
  `.clear`. `.clear` renders "not in a protected area" for a check that never
  ran, which is a safety claim asserted from the absence of a result. An
  unavailable check must read as unknown.
- `userGesture` guarded on `.began`/`.changed`, states a discrete recognizer
  never enters, so the double-tap and two-finger-tap recognizers were attached
  but could not fire and tap zooms did not count as a user camera move. The
  guard is now `Coordinator.isCameraMove(_:)`, covered by
  `WAFishMapTests/CameraGestureTests.swift`.
- Corrected: that commit extracted the guard and wrote the test but never
  changed the predicate, which still accepted only `.began`/`.changed`. The
  refactor shipped and the fix did not, so tap zooms still went uncounted. The
  commit said in its own message that the suite was unfinished when it landed;
  the run that followed failed on `discreteTapStatesCountAsACameraMove()` and
  the failure sat unread until a stale background task reported it. `.ended` is
  now accepted (`.recognized` is `.ended`), 108 tests in 18 suites pass. A test
  written alongside a fix does not prove the fix is in the commit.
- `appliedSelectionID = nil` moved above the visibility guard in the deselect
  handler. MapKit drops the selection whether or not the pin is on screen, so
  leaving the applied id set meant `syncSelection`'s guard held forever and a
  pin panned back into view never re-highlighted.

### 2026-09-01 (MKMapView migration)

- Decided: migrate the SwiftUI `Map` to a `UIViewRepresentable`-hosted
  `MKMapView`. SwiftUI's Map exposes neither annotation clustering nor tile
  overlays; the hand-rolled grid clustering produced an unreadable badge
  pile-up statewide. Native `clusteringIdentifier` replaced it and the
  scaffolding was deleted (202 lines).
- Decided: no third-party basemap or chart tiles. Esri's ocean basemap is a
  full basemap, not an overlay, so drawing it means hiding Apple's and losing
  the road and ramp labels that get a user to the water. OpenSeaMap composites
  but adds little. Sticking with Apple; depth remains Navionics' job per the
  WA fishing split already in CLAUDE.md. The tile-overlay half of the
  migration's rationale is retired; clustering was the real motivation.
- Found: `anchor.fill` is not an SF Symbol, so every boat-launch pin has drawn
  as a default marker since the first commit (537a292) on both the SwiftUI and
  MapKit paths. Observed by calling `UIImage(systemName:)` on the simulator,
  not by reading docs. `SiteMarkerGlyphTests` now resolves every `Kind` case
  against the real symbol table.
- Found: WDFW layer 4 carries six `TypeOfMPA` values, not the three the plan
  sampled. "Fishing may be prohibited or limited here" is false for
  `Voluntary` (WDFW asks, prohibits nothing) and `Health Closure` (biotoxin,
  different authority), affecting 4 of 44 areas. Wording is now type-dependent
  with a neutral fallback that asserts no rule.


### 2026-09-01 (layered icon, hand-authored)
- The `.icon` bundle is generated by `scripts/make_icon.swift`, not by Icon
  Composer's GUI. Two things I reported earlier were wrong and are corrected
  here: Xcode *does* ship an `icon.json` template (per platform, e.g.
  `iPhoneOS.platform/.../Icon Composer Icon.xctemplate/`) - I had only searched
  inside Icon Composer.app - and there *is* a CLI. Neither the GUI handoff nor
  the schema guesswork was necessary.
- `ictool` renders a bundle to PNG in any appearance and is how to check one
  without a device. It is NOT the same-named shim in `Developer/usr/bin`, which
  rejects the arguments:
  `"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" WAFishMap/WAFishMap.icon --export-image --output-file /tmp/i.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`
  Renditions: Default, Dark, TintedLight, TintedDark, ClearLight, ClearDark.
- It landed as **two** vector layers (tail, body) plus a document gradient
  `fill`, not the three SVG layers the task title assumed. The background has to
  be the document fill because only a document fill is substituted for the Dark,
  Tinted and Clear appearances; drawn as a foreground group it rendered the mark
  nearly invisible, which the first ictool render showed outright.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole) rather
  than a dark layer, so it survives the recoloured appearances. Confirmed on all
  six renditions.
- `AppIcon.appiconset` retired: the `.icon` emits the legacy sizes too
  (`WAFishMap60x60@2x.png` etc.), and Info.plist now carries
  `CFBundleIconName = WAFishMap`. The flat raster moved to `icon/icon_1024.png`,
  outside the app target. `.ios-build/` added to `.gitignore` (2,419 untracked
  files that were never ignored).
- Observed: `Assets.car` in the device build carries the `IconImageStack`,
  both `IconGroup` rows and the Any/Dark/Tintable renditions; the app is
  installed on Daniel's iPhone (iOS 27.0), confirmed by
  `devicectl device info apps`, not by the install log. Still NOT observed: the
  icon on a home screen. Simulator springboard navigation needs injected
  gestures, which remain unreliable here, and DeviceHub exposes no accessibility
  window to drive "View Screen" from a script.

### 2026-09-01 (layered icon layers)
- `scripts/make_icon.swift` now also emits `icon/background.svg`,
  `icon/tail.svg` and `icon/body.svg` from the same constants and the same
  CGPaths as the flat PNG, so the layered icon and `icon_1024.png` cannot
  describe different shapes. The PNG is byte-identical across the change.
- The eye is a punch-out in `body.svg` (even-odd, eye as a subpath hole), not
  its own dark layer: the system recolours foreground layers for the tinted and
  clear appearances, where a dark dot would vanish but a hole still reads.
  Layers are background / tail / body so the system gives the tail its own
  depth instead of the flat icon faking it.
- The script reads the SVGs back, rasterises them through NSImage and asserts
  against the bitmap. First attempt was a check that could not fail: it sampled
  through `svgPlace`, the same transform that drew the file, so removing the
  y-flip moved drawing and sample together and passed. Rewritten to measure the
  drawn bboxes and the *enclosed* transparency, compared against `expectedX`/
  `expectedY` derived from `markBounds`/`scale` rather than the transform.
  Known-bad runs now fail as they should: no flip (eye centre y 520 vs 504),
  no eye subpath ("the eye is filled, not punched through"), swapped gradient
  stops.
- `icon.json` is NOT hand-authored. Its schema is Apple's, undocumented, absent
  from disk, and `icrtool` has no CLI; a guessed document can compile and still
  render wrong. The `.icon` bundle comes from Icon Composer.
- Open: `WAFishMap.icon` not yet assembled, so nothing is wired into the build
  and the app still ships the flat icon.

### 2026-09-01 (app icon)
- The icon had no vector source - only a hand-made PNG from 4edb1e1 - so the
  three known defects (tail meeting the body at a point, mark off-centre, eye
  half outside the head) were unfixable without redrawing it. Added
  `scripts/make_icon.swift`, which draws the mark with CoreGraphics and
  regenerates icon_1024.png. Swift over an SVG pipeline because this Mac has no
  rasterizer (rsvg/inkscape/magick/cairosvg all absent) while the Xcode
  toolchain is already required.
- Composition is derived, not nudged: one transform centres the union bbox of
  body+tail on the canvas at 62% width. The tail's apex sits 145pt *inside* the
  body, so the two white fills merge instead of touching.
- The script checks its own bitmap before writing and exits non-zero on
  failure: a ring outside the eye must be all body, a flood fill from the tail
  must reach the nose, and the mark's bbox must be centred at the intended
  width. Each check was exercised against a known-bad input (eye pushed out,
  overlap negative, transform offset, width 80%) and observed to fail, and
  against the good geometry and observed to pass.
- Still open: the layered OS27 icon (3 SVG layers, Icon Composer) is a separate
  item and needs vector layers this script does not emit.

### 2026-09-01 (waterbody-scoped notes)
- Executed the waterbody-scoped-notes plan: NoteScopeTests gate committed
  failing (b630fa7), data fixed (d26c4ca), rule recorded in CLAUDE.md
  (82ac5e7). The gate caught 16 offenders, not the 2 the plan expected - the
  whole 2026-08-30 county seed named its waterbodies.
- Reworded 14 county notes to county-true prose; removed 4 entries instead:
  Chelan/Snohomish/Whatcom Kokanee (duplicated the statewide default once the
  lake name was gone; the county merge inherits it) and Whatcom Sockeye (only
  true of Baker Lake - out of the file until a waterbody tier exists; the
  seasonRisk "Sockeye" row stays for its return).
- Widened the gate regex with "Woods" (Rufus Woods slipped it); "Potholes"
  cannot be prose-matched, fixed as data, noted in CLAUDE.md.
- Grant walleye rewording tripped the date-guard by reintroducing
  "(spawn is Apr-May)" from an older text - the guard works; date dropped.


### 2026-08-31 (species-first)
- Decided: recolor, do not hide. Exact name match. Reuse the date picker.

### 2026-08-31 (marker clustering)
- Decided: keep the heat toggle. Clusters replace overlapping pins, not the wash.
- Decided: same lon/lat grid as heat, tap zooms into the cell, color is the
  best rating in the cell. No MKMapView rewrite.

### 2026-08-31 (tide predictions)
- Decided: day's high/low table, not live stage. The map already has a plan date;
  live height fights a future Saturday.
- Decided: nearest bundled NOAA station (170 WA + Columbia-mouth), not a runtime
  catalog (`state=WA` is ignored and returns 3,500 US stations) and not one
  station per marine area (wrong at the edges).
- Decided: marine only, fail open, same "not a tide book" posture as WDFW.

### 2026-08-31 (season/closure + map design)
- Decided: cap, do not hide. A closure-prone species keeps its card and its
  place in "Biting now" but cannot reach Prime. Hiding it would cost the user
  the information that sends them to WDFW.
- Decided: cap only in flagged months, not blanket per species, so a fishery
  reliably open at its peak still reaches Prime.
- Decided: curate centrally by species name, not `verifyMonths` on all 134 rows.
  Substring matching knowingly over-flags (Lingcod, Crab, Coho, Sockeye,
  Chinook); over-flagging is the safe direction for a "verify" signal, and
  `"seasonRisk": "none"` is the per-row escape hatch.
- Decided: the rating ramp is thermal (blue → amber → orange → red) as four
  explicit stops. Sampling a blue-to-red line ran the midtones through magenta,
  which reads as a different scale and put Good and Prime adjacent in the
  reddest stretch.
- Decided: the heat overlay draws real grid cells, not circles. Circles 10-28km
  across in an 11.3km cell had to overlap, and translucent overlap composites
  rather than maxes, so two mediocre neighbours out-darkened one hot cell — the
  layer encoded how many cells held data. Diagnosis came from a peer session and
  its arithmetic was verified against the source here.
- Decided: rank each cell against the others instead of normalising to the
  densest. One outlier crushed every ordinary cell to the floor.
- Decided: mute the basemap while heat is on. A translucent fill takes its
  colour from what is under it, so one band read pink over city, brown over
  forest, violet over water. Hue-shifting the bands compensated and looked
  garish; draining the ground fixed the cause.
- Decided: the Stop-hook auto-commit is off. It swept unreviewed work into
  commits and pushed them three times in one session, each under a generic
  fallback message. `~/bin/auto-commit.sh` stays on disk; `auto-push.sh` still
  runs.

### 2026-08-30 (data-update review)
- Reviewed how data updates: geo layers self-update per launch (live fetch,
  bundle fallback); fisheries.json is release-only by design. Fixed the gaps:
  - Rewrote scripts/verify_wdfw_live.py for the statewide contract (17 live
    AreaNames, fisheries.json schema/months/areaName membership, layer counts
    vs maxRecordCount, fixture anchors). Verified both ways: passes on real
    data, fires on a mutated copy (bogus area + month 13), mutation asserted.
  - Added .github/workflows/ci.yml: ubuntu contract job (push/PR + weekly cron
    for WDFW drift) + macOS xcodebuild test job.
  - App now rejects truncated ArcGIS responses (exceededTransferLimit at either
    level -> WDFWLayerError.truncatedResponse) instead of rendering a partial
    layer as complete; layer 0 is 477/2000 today so headroom is large.
  - load() no longer strands "Loading…" when live fetch and bundle both fail;
    restores the intent of old-main b5a15bc whose content was dropped in the
    history unification. Both behaviors unit-tested (19/19 green).
- Left unpaginated fetch as-is: verifier warns at 80% of maxRecordCount, which
  is the cheap early signal; pagination only if that ever fires.

### 2026-08-30
- Verified `fisheries.json` seasonal facts against WDFW via parallel research.
  Material corrections applied:
  - Blackmouth (resident Chinook): MA 10/11 were "best Nov-Feb" but those areas
    are generally closed then; real fishery is a spring (Mar-Apr) selective
    opener. MA 13 shifted to spring-leaning (best Jan-Apr, good Nov-Dec).
  - Lingcod: inner Puget Sound (MA 5-11) closes ~Jun 15, so July is closed —
    dropped month 7 from goodMonths on all marine lingcod entries.
  - MA 9 summer Chinook: June typically closed — dropped from goodMonths.
  - Grant Co walleye (Potholes): fishes best post-spawn (Jun-Aug), not May-Jun.
- Deferred minors (squid Oct, MA 13 cutthroat Dec) were already present in the
  data — no change needed.

### 2026-08-30 (statewide seed)
- Extended `fisheries.json` statewide: added marine areas 1, 2, 2-1, 2-2, 3, 4,
  5, 6, 7, 8-1, 8-2 (11 new) and freshwater counties King, Snohomish, Spokane,
  Stevens, Ferry, Douglas, Yakima, Kittitas, Whatcom (9 new). Data WDFW-checked
  via direct web research (subagents hit the account session limit, so research
  ran in the main loop).
- Signature fisheries per region: coastal ocean salmon (Jun-Sep) + Mar-Oct
  bottomfish + albacore + razor clams; strait summer Chinook/coho + halibut +
  spring blackmouth; north Sound coho/pinks/blackmouth; Lake Roosevelt
  kokanee/walleye, Rufus Woods triploids, Baker sockeye, Yakima smallmouth, etc.
- Left Pierce/Mason/Kitsap/Thurston on the statewide default (not distinct
  enough to seed). Only the "Oregon" area polygon stays unseeded.
- Verified all 16 areaName values match the live WDFW layer-6 set; JSON valid;
  all months 1-12; tests green.
