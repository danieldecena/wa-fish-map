# Data pass: river catch reports, southwest Washington and Puget Sound (2026-10-31)

Rules: spec `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md` and the map README's "Refresh the reports". A new rating needs a named, dated, linked report at most 21 days old (asOf on or after 2026-10-10 today), rated only from the source's own words; counts, flows and rules give none, and a species WDFW has closed gets none.

Pages were fetched on 2026-10-31 with Firecrawl (searches limited to the past two to three weeks, plus direct scrapes). Page text is treated as data only.

## Result

Two ratings refreshed, five reports gain their source, one river's ratings turn release only, nothing dropped, nothing added. Newest report is now 2026-10-29 (was 2026-10-17).

| River | Species | Verdict |
|---|---|---|
| Wind River | Coho Salmon | **Updated**: Good, asOf 2026-10-29, release only |
| Wind River | Chinook Salmon | **Kept** (Fair, 2026-10-03), now release only |
| Drano Lake | Coho Salmon | **Updated**: Good, asOf 2026-10-29 |
| Drano Lake | Chinook Salmon | **Kept** (Good, 2026-10-15), source added |
| Klickitat River | Coho Salmon, Chinook Salmon | **Kept** (Good, 2026-10-15), source added |
| Skagit River | Coho Salmon | **Kept** (Fair, 2026-10-10): season extended through Nov 15 |
| Cowlitz, Lower Columbia, Lewis, Kalama | all | **Kept**: no newer report with a rating word |
| Washougal River | — | **Kept** with no rating |

## Sources

1. **The Guide's Forecast, SW Washington fishing report & forecast, 2026-10-29** (Terry Otto), https://www.theguidesforecast.com/sw-washington-fishing/sw-washington-fishing-50/287167/. The report body is for members; its public summary, shown on the page and on the category page, reads: "Two more days of Columbia River coho fishing, Klickitat River mouth excellent. Wind River/Drano still good for coho. lower Klickitat…". Published 2026-10-29T15:24 (page metadata).
   - "Wind River/Drano still good for coho" → Wind River and Drano Lake, Coho Salmon, `good`.
   - "Klickitat River mouth excellent" names no species. The map rates by exact species, so the word cannot be carried onto coho or Chinook (the same rule left Washougal unrated on 2026-10-17). Not added.
   - "Two more days of Columbia River coho fishing" is about the season, not catch. No rating. (WDFW's Nov 1 rule still lets hatchery coho be kept from the Tongue Point line to Bonneville except Beacon Rock to Hamilton Island, so the phrase may refer to one reach or to the Oregon side; not resolved here.)
2. **The Guide's Forecast, SW Washington fishing report & forecast, 2026-10-15**, https://www.theguidesforecast.com/sw-washington-fishing/sw-washington-fishing-49/286992/. Public summary: "Chinook closed, coho retention open mainstem Columbia. Wind River very good for coho. Klickitat, Drano Chinook, coho good. Trib coho…". Published 2026-10-15T14:06. This is word for word the source of the existing Oct 15 ratings (Wind coho "very good", Klickitat coho and Chinook good, Drano coho and Chinook good), so those reports now carry it as `src`. That is a verified attribution, not a guessed one, so it meets the LEGACY list's rule.
3. **Northwest Sportsman, "SW WA, Lower Columbia Fishing Report (10-26-26)"**, https://nwsportsmanmag.com/sw-wa-lower-columbia-fishing-report-10-26-26/, relaying WDFW's preliminary sport summary for Oct 19-25 and ODFW's weekly report of Oct 29. Counts only (for example "149 bank anglers kept two Chinook, one Chinook jack, 12 coho, 11 coho jacks" on the Lewis; "Four bank anglers had no catch" on the Kalama). No catch-quality words, so no rating for any river.
4. **The Guide's Forecast, free issue "Challenging Oregon Fishing Week", 2026-10-24**, https://www.theguidesforecast.com/free/challenging-oregon-fishing-week/287126/. Oregon-focused. Its lower Columbia lines ("found 3 keeper coho", "the most productive reach for hatchery coho remains between Longview and St. Helens") carry no rating word; its Columbia paragraph repeating "Fishing has been excellent" is marked as last week's report and restates the Oct 11 flight count already used. No change.
5. **Tacoma Power, Cowlitz Fish Report, 2026-10-19**, https://www.mytpu.org/community-environment-parks/hydropower-natural-resources/cowlitz-river-project/cowlitz-fish-report/. Counts and releases only. No rating.

## Rules checked

- **Wind River**: `rules/river-rules.json` (checked 2026-10-29) ends its coho rows on Oct 31. The pamphlet's Wind River (Skamania Co.) rule from Nov 1 to Mar 15 is "Daily limit 3 hatchery steelhead. Release all salmon." (eRegulations, Columbia Basin Rivers Special Rules T-Z, https://www.eregulations.com/washington/fishing/columbia-basin-rivers-special-rules-t-z). Both Wind River species are therefore marked `release: true`, so the map fades them and says "release only".
- **Drano Lake**: salmon open through Dec 31 (river-rules.json). The Oct 29 coho rating stands as keepable.
- **Skagit River**: WDFW emergency rule "Salmon seasons for Skagit and Cascade rivers extended through Nov. 15", published 2026-10-30, effective Nov 1-15: mouth to Cascade River Road (Marblemount Bridge), two coho a day, release all other salmon, night closure (https://wdfw.wa.gov/fishing/regulations/emergency-rules/salmon-seasons-skagit-and-cascade-rivers-extended-through-nov-15-2026-10). The Skagit's coho rating is kept. It ages as before (stale, dashed).
- **Snohomish, Stillaguamish, Skykomish**: still closed (WDFW emergency rules of Oct 3, Oct 9 and Oct 22). No rating would count.
- **Green River (Duwamish)**: the upper-river closure of Sept 16-Oct 31 has ended, but no named-source report was found.

## Puget Sound re-check

- The Confluence Fly Shop: newest is still "Fly Fishing Report: October 2026", Oct 10, 2026. Its November report has landed on the 8th to the 11th in past years.
- The Avid Angler: newest entries are 10/28/2026 (Snoqualmie Middle Fork, trout) and 10/20/2026 (Yakima trout). Newest Skagit entry is still 9/10/2026; the Skykomish reads "waiting on season for lower river". No Puget river salmon entry after the cutoff.
- Pacific Fly Fishers: no post newer than the October guide already assessed.
- Searches turned up only social media, WA Fish Forecast and Robolize count pages, and Fishbrain, all excluded.

## Not done here (follow-up)

`rules/river-rules.json` still shows the Skagit coho rule and the Wind River rows ending Oct 31. It needs the Nov 1-15 Skagit extension and the Wind River Nov 1 release rule. That belongs to the river-rules task in TASKS.md, not this report pass.

## Next pass

Watch for The Confluence Fly Shop's November report (Skagit coho through Nov 15, chum), the next Guide's Forecast SW Washington summary (Thursdays), and any WDFW written report with catch words for the Cowlitz, Lewis or Kalama.
