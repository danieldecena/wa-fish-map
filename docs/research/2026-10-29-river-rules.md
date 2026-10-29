# River rules for the web map's report-river sheets, 2026-10-29

Research behind `Artifacts/salmon-rivers/rules/river-rules.json` (built into `river-rules.js` by `scripts/build_river_rules.py`). Daniel decided on 2026-10-29 that the web page, and only the web page, shows each report river's WDFW rules as text. The app keeps its guidance-not-regulation stance. Source labels and URLs are not shown in the sheets; they live here.

Every page below was fetched and read on 2026-10-29 (the page text was pulled with a plain HTTP fetch and read in full, not summarised by a model; the two emergency rules were also read through a summarising fetch and agree). Summaries are in my own words.

## Where the rules come from

WDFW's rules page (`https://wdfw.wa.gov/fishing/regulations`) sends readers to the "Fishing in Washington" pamphlet, which WDFW publishes on eRegulations (`https://www.eregulations.com/washington/fishing/`). The pamphlet page for each region says its own emergency-rule check ("Emergency rules ... will supersede the rules contained in these eRegulations") and each Columbia Basin and Puget Sound/Coastal page here is marked "Last Updated: October 5, 2026". Emergency rules are on `wdfw.wa.gov` itself. The wdfw.wa.gov site has no per-river rule pages for these waters; the pamphlet is the rule text.

## Emergency rules in effect (WDFW list, read 2026-10-29)

`https://wdfw.wa.gov/fishing/regulations/emergency-rules` lists 34 rules from April to October 2026. Read in full from the page's own links (the HTML, not the search filter). Of those, only two touch the nine waters:

- Lower Columbia River salmon and steelhead fishery update, published 2026-09-24, in effect Sept 26 to Oct 31: `https://wdfw.wa.gov/fishing/regulations/emergency-rules/lower-columbia-river-salmon-and-steelhead-fishery-update-2026-09-0`
- Cascade River seven-day fishing and temporary Skagit closure, published 2026-10-15, in effect through Oct 31: `https://wdfw.wa.gov/fishing/regulations/emergency-rules/cascade-river-open-seven-days-week-fishing-and-temporary-closure-implemented-portion-skagit-river-2026-10`

No emergency rule is listed for the Cowlitz, Lewis, Wind, Klickitat, Little White Salmon or Drano Lake, Kalama or Washougal. The September 28 errata page (`.../errata-pamphlet-corrections-2026-09`) corrects only Smith Creek and Mineral Lake.

## Pamphlet pages used

| Page | URL | Waters read |
| --- | --- | --- |
| Columbia River special rules | `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-columbia-river` | Lower Columbia |
| Columbia Basin rivers A-C | `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-a-c` | Cowlitz |
| Columbia Basin rivers D-K | `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-d-k` | Kalama, Klickitat |
| Columbia Basin rivers L-N | `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-l-n` | Lewis (North Fork; the East Fork is a separate entry), Little White Salmon |
| Columbia Basin rivers T-Z | `https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-t-z` | Washougal, Wind |
| Westside lakes A-E | `https://www.eregulations.com/washington/fishing/westside-lakes-special-rules-a-e` | Drano Lake |
| Puget Sound and Coastal rivers S-Z | `https://www.eregulations.com/washington/fishing/puget-sound-coastal-rivers-special-rules-s-z` | Skagit |
| Definitions | `https://www.eregulations.com/washington/fishing/definitions` | adult, jack, hatchery, wild, night closure, anti-snagging |

Definitions used in the row text: an adult is a Chinook 24 in or longer or a coho 20 in or longer; "hatchery" salmon have a clipped adipose fin and a healed scar, "wild" ones an unclipped adipose fin; a night closure runs from one hour after official sunset to one hour before sunrise.

New for 2026, on every Columbia Basin page read: anglers 15 and older need the Columbia River Salmon and Steelhead Endorsement to fish for salmon or steelhead (Drano Lake, the Lower Columbia and each tributary listed below say so).

## Per water (what the rows say)

### Cowlitz (`cowlitz`)
Mouth to Lexington Bridge, Lexington Bridge to Mill Creek, and Mill Creek to 400 ft below the barrier dam carry the same salmon rule. Aug 1 to Dec 31: limit 6 salmon with no more than 3 adults, 12 in minimum, release all salmon other than hatchery coho. So Chinook are release-only. Mill Creek to the barrier dam: no fishing from a floating device, and a night closure and anti-snagging rule Apr 1 to Nov 30. CRSSE required.

### Lower Columbia (`columbia`)
Emergency rule (2026-09-24): from the Rocky Point/Tongue Point line up to the west end of Puget Island, Sept 28 to Oct 31, limit 6 salmon with up to 3 adults, release all salmon and steelhead other than hatchery coho. The printed pamphlet for that reach still says no more than 2 adults for Sept 3 to Oct 31; the emergency rule supersedes it. The emergency rule's text for Puget Island up to Pasco ends Sept 30, so from Oct 1 that reach follows the pamphlet.
Pamphlet, Puget Island line up to Bonneville Dam (every reach in between lists the same dates): Oct 1 to 15 limit 6 with up to 2 adults, release all but coho; Oct 16 to 31 release all but hatchery coho; Nov 1 to Dec 31 the limit is worded differently (adults or hatchery steelhead). Rows are written only for what is in effect now (through Oct 31). All reaches: night closure and barbless hooks for salmon. Closed waters at Bonneville Dam: inside the south navigation lock, and from 600 ft below the powerhouse fish ladder to the upstream line of the dam. CRSSE required.

### Lewis River, North Fork (`lewis`)
Mouth to the East Fork, East Fork to Johnson Creek, Johnson Creek to Colvin Creek, Colvin Creek to the power lines below Merwin Dam: Oct 1 to 31 limit 6, up to 3 adults including no more than 1 Chinook; release all salmon other than Chinook and hatchery coho. Johnson Creek upward: night closure and anti-snagging rule (through Nov 30 to Colvin Creek, through Oct 31 above it). Closed waters: power lines to Merwin Dam. CRSSE required. The upper stretch has no salmon dates for Nov 1 to Dec 15, so no rule is written past Oct 31.

### Wind River (`wind`)
Mouth to Highway 14 Bridge, Oct 1 to 31: limit 6 salmon with up to 2 adults, release wild coho (Chinook are not restricted). Highway 14 Bridge to Shipherd Falls fish ladder, Jul 1 to Oct 31: same limit, release wild Chinook and wild coho. Night closure for salmon Jul 1 to Oct 31, anti-snagging Aug 1 to Oct 31 in both. CRSSE required. The pamphlet lists no fall salmon season above Shipherd Falls (the Carson area): absence from a table is not a statement, so no row is written there.

### Klickitat (`klickitat`)
Mouth (BNSF bridge) to Fisher Hill Bridge, Aug 1 to Jan 31: limit 6 salmon with up to 2 adults, night closure and anti-snagging rule. The wild-Chinook release line in that table ends July 31. Fisher Hill Bridge to 400 ft above the Lyle Falls fishway is closed waters. CRSSE required.

### Drano Lake (`drano`)
Westside lakes page. Aug 1 to Oct 31: limit 6 salmon, up to 1 adult, 12 in minimum; no hatchery-only line is listed. Closed from 6 p.m. Tuesdays to 6 p.m. Wednesdays during October; night closure Mar 16 to Oct 31; anti-snagging Aug 1 to Dec 31. CRSSE required. Nov 1 to Dec 31 changes (up to 1 adult salmon or hatchery steelhead), so rows end Oct 31. The Little White Salmon River from Drano Lake to the hatchery intake is closed waters (not written as a row; the sheet is for Drano Lake).

### Kalama (`kalama`)
Mouth to 1,400 ft below the Kalama Falls Hatchery fishway: Aug 1 to Dec 31, limit 6 with up to 3 adults, release all salmon other than hatchery Chinook and hatchery coho. Railroad bridge below I-5 up to the Fallert Creek Hatchery intake: night closure and anti-snagging rule through Oct 31. Natural gas pipeline crossing to the Fallert Creek intake: fly fishing only Sept 1 to Oct 31, barbed hooks allowed. From Modrow Bridge down to markers about 1,000 ft below the temporary rack: closed waters while the rack is in the river. CRSSE required.

### Washougal (`washougal`)
Mouth to the County Line access ramp, and County Line to the Salmon Falls bridge: Aug 1 to Dec 31, limit 6, up to 3 adults including no more than 2 Chinook, release all salmon other than hatchery Chinook and hatchery coho. Night closure; anti-snagging rule Jul 1 to Oct 31 (Aug 1 to Oct 31 above County Line). Closed waters 1,000 ft below to 200 ft above the temporary weir when installed; closed from the Salmon Falls bridge upstream. CRSSE required.

### Skagit (`skagit`)
Pamphlet (Oct 1 to 31): limit 2, release all salmon other than coho, night closure. Emergency rule (2026-10-15, through Oct 31): 2 coho a day, 12 in minimum, release all salmon other than coho, bait prohibited, single-point barbless hooks required for salmon, from the mouth to the Marblemount Bridge. The Gilligan Creek to Baker River reach was closed Oct 15 and Oct 19 to 21 (past by 2026-10-29); the notice for it stays in `rules.js`.

## Not confirmed

- **Left out on 2026-10-29 before merge (the agent's own doubts, not verified):** Lower Columbia coho (both stretches: the Sept 24 emergency rule says up to 3 adults where the Oct 5 pamphlet still says 2, and the Oct 16 to 31 rows from Puget Island to Bonneville assumed one pamphlet table covers every reach) and the Wind River Chinook row from the mouth to the Highway 14 bridge (the "may be kept" wording was inferred from the coho release line). These waters now show only the rows that were read directly.

- **Wind River above Shipherd Falls (Carson area):** no fall salmon rule found in the table; not written.
- **Lower Columbia, Buoy 10 to the Tongue Point line, and Puget Island up to Pasco after Sept 30 outside the Bonneville stretch:** outside the page's Tongue Point to Bonneville range, not written.
- **Rules after the stated end dates** (Nov 1 onward for the Columbia, Lewis, Wind and Drano; the pamphlet gives different Nov 1 rules): not written. The page hides a row after its `through` date rather than show an expired rule.
- **Steelhead, trout, sturgeon and other species:** the report cards cover salmon only.
- **Kalama above the Kalama Falls Hatchery and the other tributaries:** outside the page's stretch.

## Less certain

- The Lower Columbia emergency rule and the printed pamphlet disagree on adults for the Tongue Point to Puget Island reach (3 against 2). The emergency rule is later in effect and WDFW says emergency rules supersede the pamphlet, so the row uses 3. The pamphlet "Last Updated Oct 5" is later than the emergency rule's publication date, yet does not show it.
- The Columbia emergency rule's Action line says coho retention runs to Oct 31 upstream of Puget Island, but its reach-by-reach text stops at Sept 30; the Oct rows for that reach come from the pamphlet.
- Rows for the whole Lower Columbia assume the reaches between Puget Island and Bonneville Dam share one October rule; the pamphlet tables are identical for all of them.
