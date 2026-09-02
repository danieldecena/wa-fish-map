# WAFishMap — Decision log archive

Rotated out of `STATUS.md` to keep the live file readable. Append-only;
git holds the full history either way. Newest first.

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

Older entries: [STATUS-ARCHIVE.md](STATUS-ARCHIVE.md).

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
