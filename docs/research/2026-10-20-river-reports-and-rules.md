# River reports and WDFW rules, 2026-10-20

Research behind `Artifacts/salmon-rivers/rules.js` and the decision not to colour any new river in Recent reports.

## Question
Do any Puget Sound or coastal salmon rivers have a dated, sourced catch report from Oct 6–20, 2026 that the page could rate the way it rates the eight southwest Washington waters?

## Result
No. None of the 32 rivers checked had a dated catch report in the window, so no river was added to `reports.js`. WDFW emergency rules were found for several of them; those are linked from river sheets as WDFW notices (`rules.js`) and never colour a river or pin.

Rivers checked: Skagit River, Sauk River, Cascade River, Nooksack River, Samish River, Stillaguamish River, Snohomish River, Skykomish River, Snoqualmie River, Green River, Puyallup River, Carbon River, Nisqually River, Deschutes River, Skokomish River, Chehalis River, Satsop River, Wynoochee River, Humptulips River, Willapa River, Naselle River, Quillayute River, Sol Duc River, Bogachiel River, Calawah River, Hoh River, Queets River, Quinault River, Elwha River, Dungeness River, Elochoman River, Grays River.

## Where we looked
- WDFW Puget Sound creel page: data through Oct 17, saltwater ramps and shore sites only.
- WDFW North Coast creel page: no rows.
- WDFW Southwest Washington reports: newest weekly report in `salmon.db` is Oct 5–11 (`build_salmon_db.py --fetch` run 2026-10-20 02:27 found nothing newer).
- The Guide's Forecast and Northwest Sportsman (Oct 10–17): Columbia and SW Washington only.
- Peninsula Daily News (Oct 19): closure news only, no catch figures.

## WDFW emergency rules (each opened and read on its own page)

- **Hoh River, Quillayute River, Sol Duc River, Bogachiel River, Calawah River** — published 2026-10-16, effective 2026-10-19... WDFW closes the Hoh and Quillayute watersheds (incl. Sol Duc, Bogachiel, Calawah, Dickey and tributaries, outside Olympic National Park) to all fishing for all species until further notice, citing coho harvest 'substantially lower than anticipated' and low flows. <https://wdfw.wa.gov/fishing/regulations/emergency-rules/hoh-and-quillayute-watersheds-closing-all-fishing-2026-10>
- **Skagit River** — published 2026-10-15, effective 2026-10-19..2026-10-21. Skagit River from Gilligan Creek to the Baker River closed to all species Oct 19-21 (also closed Oct 15) to avoid gear conflicts with tribal fisheries; open Oct 16-18 and Oct 22-31 with a 2-coho daily limit; elsewhere on the Skagit (mouth to Gilligan Cr, Baker R to Marblemount Bridge) 2-coho limit; no bait, single-point barbless hooks required. <https://wdfw.wa.gov/fishing/regulations/emergency-rules/cascade-river-open-seven-days-week-fishing-and-temporary-closure-implemented-portion-skagit-river-2026-10>
- **Cascade River** — published 2026-10-15, effective 2026-10-15..2026-10-31. Cascade River from the mouth to the Rockport-Cascade Road Bridge opens seven days per week for salmon and gamefish, 4-coho daily limit, release all non-coho salmon; bait and barbed hooks still prohibited. <https://wdfw.wa.gov/fishing/regulations/emergency-rules/cascade-river-open-seven-days-week-fishing-and-temporary-closure-implemented-portion-skagit-river-2026-10>
- **Stillaguamish River** — published 2026-10-07, effective 2026-10-09..2026-11-01. Mainstem Stillaguamish from Marine Drive (south of Stanwood) to the forks near Arlington closed to all fishing because sport fisheries reached the allowable number of Chinook encounters; WDFW expects reopening by Nov 2. <https://wdfw.wa.gov/fishing/regulations/emergency-rules/stillaguamish-river-close-all-fishing-oct-9-2026-10>
- **Snohomish River** — published 2026-10-01, effective 2026-10-03..2026-11-01. Snohomish River from the mouth to the Skykomish/Snoqualmie confluence closed to all species over concern the coho return is below expectations (does not name the Skykomish or Snoqualmie above the confluence). <https://wdfw.wa.gov/fishing/regulations/emergency-rules/snohomish-river-close-all-fishing-oct-3-2026-10>
- **Quillayute River** — published 2026-10-05, effective 2026-10-06..2026-10-18. Quillayute mainstem (park boundary to Sol Duc/Bogachiel confluence) reopened with a 2-salmon limit (max 1 wild adult), sockeye release and a bait ban; superseded by the Oct 19 watershed-wide closure. <https://wdfw.wa.gov/fishing/regulations/emergency-rules/quillayute-river-reopens-fishing-reduced-retention-limits-and-no-bait-2026-10>

The Quillayute reopening (published 2026-10-05) is superseded by the Oct 19 watershed closure and is not in `rules.js`.

## Typical flow on river sheets
River sheets show each gauged river's monthly flow range from `WAFishMap/Resources/river_stats.json` (USGS daily percentiles averaged per month; built into `rivers-tap.js`). Names shared by different rivers (Clearwater, Cedar, Green, White) were split into separate river groups and the gauge attached only to the group it sits on. USGS live-flow links use `https://waterdata.usgs.gov/monitoring-location/USGS-<gauge>/`; all 77 gauges resolved to a page titled with the gauge name.
