# WAFishMap — Status

## Confirmed working

- `fisheries.json` now seeds all 16 statewide marine areas (1-8-2 + 9-13; only
  the "Oregon" polygon is unseeded) plus 12 freshwater counties. WDFW-checked
  2026-08-30. FisheryTests + FishingMapModelTests green (13/13).
- `fisheries.json` v1 Puget Sound seed cross-checked against WDFW; corrections
  applied (see decision log).

## Known broken

## Next Up

- Verify remaining default-covered counties if desired (Pierce, Mason, Kitsap,
  Thurston left on the statewide default by design — add only if distinct).
- Season/closure (open-window) modeling so ratings never show "best" during a
  closure — separate feature, not started.

## Decision log

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
