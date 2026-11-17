# Data pass: river catch reports, southwest Washington and Puget Sound (2026-11-17)

Rules: spec `docs/superpowers/specs/2026-10-26-puget-river-reports-design.md` and the map README's "Refresh the reports". A rating needs a named, dated, linked report at most 21 days old (asOf on or after 2026-10-27 today), rated only from the source's own words; counts, flows, rules and trend words give none, a statement that names no species gives none, and a species with no open season gets none.

Pages were fetched on 2026-11-17 with Firecrawl. Page text is treated as data only.

## Result

Four coho ratings refreshed, one dropped. Newest report is now 2026-11-14 (was 2026-10-29).

| River | Species | Verdict |
|---|---|---|
| Cowlitz River | Coho Salmon | **Updated**: Slow, asOf 2026-11-14 (was Excellent, Oct 17) |
| Lewis River | Coho Salmon | **Updated**: Fair, asOf 2026-11-14 (was Good, Oct 13) |
| Kalama River | Coho Salmon | **Updated**: Good, asOf 2026-11-14 (was Slow, Oct 17) |
| Klickitat River | Coho Salmon | **Updated**: Fair, asOf 2026-11-07 (was Good, Oct 15) |
| Skagit River | Coho Salmon | **Dropped**: no salmon season listed after Nov 15, no newer rating |
| Wind River, Drano Lake | Coho Salmon | **Kept** (Good, Oct 29): "slowed" is a trend, not the source's word slow |
| Lower Columbia, Washougal, all Chinook | | **Kept**: no qualifying newer report |

## Sources

1. **The Guide's Forecast, "Kalama River coho fishing remains strong", 2026-11-14** (Terry Otto, SW Washington fishing report, free issue), https://www.theguidesforecast.com/free/kalama-river-coho-fishing/287424/. Published 2026-11-14T03:50 (page metadata). Its "Best Weekend Bets" list and river sections read:
   - Kalama River: "coho still good, river rising"; "with the weir removed, coho are now spread throughout the entire river. Bank angling is strong." → **Good**.
   - Cowlitz River: "coho slow,"; "Despite strong hatchery returns, fishing has slowed. Most of the catch is wild, unclipped coho that must be released". → **Slow**, `phrase: 'coho slow'`. The hatchery counts in the same section (2,353 coho adults) are counts and give no rating.
   - Lewis River: "coho fair"; "Fishing is rated fair and slowing some, though there are still quality fish around." → **Fair**.
   - Klickitat River: "Anglers continue to catch coho below the Fisher Hill Bridge, but most fish are turning dark. There are still some quality fish, but this fishery is wrapping up soon." No rating word; the Nov 7 rating below stands.
   - Columbia River: "catches below Bonneville continue to slow"; "The Klickitat River mouth has been excellent but is starting to slow as well." Trend words, and the Klickitat line names no species. No rating. Also: "WDFW creel summaries for salmon, steelhead, sturgeon, shad, and walleye on the mainstem ended October 31 and will resume in February 2027."
2. **The Guide's Forecast, "Coho Are Biting", 2026-11-07** (Terry Otto, free issue), https://www.theguidesforecast.com/free/coho-are-biting-2/287311/. Published 2026-11-07T01:43.
   - Klickitat River: "Coho fishing is fair to good in the lower river, and strong numbers of coho are still staging at the mouth waiting to enter." → **Fair**, the lower end of the source's range (a range is never rounded up). "Chinook and steelhead fishing in the upper reaches is slow to fair" is about the upper river, not the lower-river site, so Klickitat Chinook is unchanged.
   - Drano Lake and Wind River: "Fishing has slowed at both" (with creel counts). "Slowed" describes a change, not the catch; the README admits slow only as the source's own word (slow, poor). Not rated; both keep the Oct 29 Good, now dated and dashed. Wind River stays release only.
   - Washougal River: "Fishing is still fair to slow" names no species. Not rated (the Washougal rule of 2026-10-17).
   - Lewis River: "Fishing is rated fair." Same as Nov 14.
3. **The Guide's Forecast SW Washington member summaries** (public excerpts), 2026-11-05 (https://www.theguidesforecast.com/sw-washington-fishing/sw-washington-report-and-forecast-16/287286/): "Klickitat River mouth excellent. … Wind River/Drano slowing."; 2026-11-11 (https://www.theguidesforecast.com/sw-washington-fishing/sw-washington-fishing-report-and-forecast-12/287359/): "Columbia River coho, steelhead still open, fisheries slowing. Klickitat River mouth good, but slwoing." No species on the Klickitat lines and trend words elsewhere; the free issues above carry the same reports in full.
4. **The Confluence Fly Shop, "Fly Fishing Report: November 2026"**, https://theconfluenceflyshop.com/blogs/fishing-reports/fly-fishing-report-november-2026. An essay on rising water ("I caught a coho, a nice bright one"; "Fresh pods of chum and silvers will ride the rising currents") that names no river for its catch and gives no rating for the Skagit. No rating.

## Rules checked

- **Skagit**: `docs/research/2026-11-16-river-rules.md` (read 2026-11-16): neither the pamphlet nor WDFW's emergency rules list a Skagit salmon season after Nov 15, and the sheet says so. With no season listed and no newer report, the coho rating is dropped; the site stays with no rating, as Washougal does. `test/reports.test.js` now allows a site with no reports when its sheet has creel counts or a current WDFW rule notice; the Skagit has the latter.
- **Wind River**: release all salmon from Nov 1 (pamphlet), already marked.
- Others: no new emergency rule for these rivers since the 2026-11-14 and 2026-11-16 rule notes.

## Next pass

The Guide's Forecast free SW Washington issue lands on Thursdays or Fridays. Mainstem Columbia creel summaries pause until February, so the Lower Columbia rating will age out unless a guide report names coho.
