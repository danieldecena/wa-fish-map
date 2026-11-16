# Skagit salmon rule after Nov 15, read 2026-11-16

Follow-up to `2026-11-14-river-rules.md`. The Skagit emergency rule (Nov 1 to 15) ended yesterday and its three rows dropped off the sheet. This pass asked what WDFW says for Nov 16 onward.

## What was read

- WDFW emergency rules list, fetched live 2026-11-16 (`https://wdfw.wa.gov/fishing/regulations/emergency-rules`, page text). November entries: Lower Columbia steelhead update, Upper Green (Duwamish) closure rescinded, Lower Nooksack smelt, Marine Area 12 salmon close. October entries touching Puget Sound rivers: Skykomish remains closed to salmon, Dungeness hatchery coho limit. No Skagit or Cascade entry is listed; the Oct 30 notice that ran the Skagit to Nov 15 has left the "in effect" list.
- WDFW pamphlet on eRegulations, "Puget Sound & Coastal Rivers Special Rules: S-Z", page marked "Last Updated: October 5, 2026" (`https://www.eregulations.com/washington/fishing/puget-sound-coastal-rivers-special-rules-s-z`), Skagit River section read in full from the page text. Salmon rows: mouth to Hwy. 536 runs Aug 16 to Oct 31; Hwy. 536 to Concrete July 1 to 31; Concrete to Rockport Sept 16 to Sept 30; Rockport to the Marblemount Bridge July 1 to 15 and Sept 16 to Oct 31. None runs past Oct 31. The only Nov 1 rows are Dolly Varden/bull trout (min. size 20 in, part of the trout limit) and a game-fish note, not salmon.

## Carried to the map

One row on the Skagit sheet, "All salmon", mouth to the Marblemount Bridge, through 2026-12-31: "WDFW lists no salmon season here after Nov 15, in the pamphlet or in its emergency rules. Check WDFW before you fish." That states what was observed (an absence in both sources), not that the river is closed. The three Nov 1 to 15 rows are removed from `river-rules.json` (the builder refuses a row that ended before its water's `checked` date; they had already dropped from the sheet at runtime).

## Not confirmed

- The pamphlet page is dated Oct 5; a rule WDFW published after that and not yet on the emergency list would not show here.
- The Dolly Varden / bull trout rule: the Nov 1 to 15 notice said release; the pamphlet row for Nov 16 on reads "min. size 20 in". Not carried (the sheets are salmon rules).
- Re-read the Skagit when WDFW next posts, or by Dec 31, whichever comes first.
