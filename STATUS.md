# WAFishMap — Status

## Confirmed working

- `fisheries.json` v1 seed cross-checked against WDFW (2026-08-30). Bulk of the
  seed timing held up; corrections applied (see decision log).

## Known broken

## Next Up

- Market squid peak is closer to Nov-Dec (add Oct as "good") — minor, deferred.
- Sea-run cutthroat MA 13 could extend to Dec — minor, deferred.

## Decisions

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
- Deferred as minor: squid Oct, MA 13 cutthroat Dec.
