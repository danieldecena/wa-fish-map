# River rules re-read for the Lower Columbia, Drano Lake and the Kalama, 2026-11-17

Follow-up to `2026-11-14-river-rules.md`, which left these three out of scope. Five rows in `Artifacts/salmon-rivers/rules/river-rules.json` ended on Oct 31 and had dropped off the web map's sheets. Each page below was fetched on 2026-11-17 and its rule rows were quoted verbatim (page text, not a model summary). All three pamphlet pages are marked "Last Updated: October 5, 2026".

## Lower Columbia, Tongue Point line to Bonneville Dam

Source: WDFW pamphlet on eRegulations, Columbia Basin Rivers Special Rules: Columbia River, `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-columbia-river`.

Every stretch from the Rocky Point / Tongue Point line up to Bonneville (west end of Puget Island, Longview Bridge, Warrior Rock line, I-5 Bridge, Fir Point line, Beacon Rock, the Hamilton Island shore reach) has the same salmon row for Nov 1 to Dec 31: "Salmon min. size 12”. Daily limit 6 including no more than 2 adult salmon or 2 hatchery steelhead or 1 of each. Release all salmon other than hatchery coho." The two shore-only reaches near the dam read "up to 2 adult salmon" with the same meaning. The Oct rows (Sept 3 to Oct 31 below Puget Island; Oct 1 to 15 and Oct 16 to 31 above) have ended.

Carried to the map: the existing Nov 1 to Dec 31 coho row now gives the limit, "Nov 1 to Dec 31: 6 salmon a day, with no more than 2 adult salmon or 2 hatchery steelhead, or 1 of each (salmon 12 in or longer). Only hatchery coho may be kept." The two coho rows that ended Oct 31 are removed. Unchanged: release all Chinook, closed waters Beacon Rock to the Hamilton Island line (Nov 1 to Dec 31), night closure and barbless hooks, the closed water at the dam, the endorsement.

Note: The Guide's Forecast of Oct 29 said "Two more days of Columbia River coho fishing". The pamphlet keeps hatchery coho open to Dec 31, and no emergency rule closes it, so the map follows the pamphlet.

## Drano Lake

Source: WDFW pamphlet, Westside Lakes Special Rules: A-E, `https://www.eregulations.com/washington/fishing/westside-lakes-special-rules-a-e`, entry "DRANO LAKE - SKAMANIA CO.":

- "Mar. 16-Oct. 31 | Night closure." Ended.
- "Oct. 1-Oct. 31 | CLOSED from 6:00 p.m. Tuesdays to 6:00 p.m. Wednesdays during October." Ended.
- "Aug. 1-Dec. 31 | Anti-snagging rule." Continues.
- Salmon and hatchery steelhead, "Aug. 1-Oct. 31 | Min. size 12". Daily limit 6. Up to 1 adult salmon may be retained. Closed to fishing for or retaining steelhead." Ended. "Nov. 1-Dec. 31 | Min. size 12". Daily limit 6. Up to 1 adult salmon or hatchery steelhead may be retained."
- Also listed, not carried (the sheets carry salmon rules): two-pole rules for Oct 1 to Dec 31.

Carried to the map: the limit row now reads "Nov 1 to Dec 31: 6 salmon a day (12 in or longer), with no more than 1 adult salmon or hatchery steelhead in total."; the night-closure row becomes "Anti-snagging rule through Dec 31."; the October Tuesday closure row is removed.

## Kalama River

Source: WDFW pamphlet, Columbia Basin Rivers Special Rules: D-K, `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-d-k`, "KALAMA RIVER - COWLITZ CO.":

- Railroad bridge below I-5 up to the Fallert Creek Hatchery intake (three stretches): "Apr. 1-Oct. 31 | Anti-snagging rule. Night closure." Ended.
- Natural gas pipeline crossing to the Fallert Creek intake: "Sept. 1-Oct. 31 | Fly fishing only, except use of barbed hooks is allowed." Ended.
- Salmon, all stretches from the mouth to 1,400 ft below the Kalama Falls fishway: "Aug. 1-Dec. 31 | Min. size 12”. Daily limit 6 including no more than 3 adults. Release all salmon other than hatchery Chinook and hatchery coho." Already on the map as its two Aug 1 to Dec 31 rows.
- No Kalama row begins on Nov 1.

Carried to the map: nothing new. The two rows that ended Oct 31 are removed. The salmon limit, closed waters and endorsement rows stay.

## Checked for anything newer

WDFW's emergency rules list (`https://wdfw.wa.gov/fishing/regulations/emergency-rules`, fetched 2026-11-17). November entries: Lower Columbia River steelhead fishery update, Upper Green (Duwamish) River fishing closure rescinded, Lower Nooksack smelt fishery opens, Marine Area 12 (Hood Canal) salmon seasons close. None names Drano Lake or the Kalama; the Lower Columbia steelhead update (Nov 13, read on Nov 14) covers The Dalles Dam to Highway 730 from Jan 1 and does not change these rows.

## Result

`checked` is 2026-11-17 for all three waters. `scripts/build_river_rules.py` rebuilt `river-rules.js`. `test/river-rules.test.js` used Drano's October row to test the end-of-row boundary; it now uses a Drano row that ends Dec 31. Re-read all river rows before Dec 31, when most of them end.
