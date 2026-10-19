# Data pass: Skagit River coho, byWaterbody row (2026-10-18)

New row: `freshwater.byWaterbody["Skagit River"]` = Coho Salmon, best [10, 11], good [9].
Key is the exact river name in `rivers.json` (id == name, so it resolves to launches within 150 m of the line).
`seasonRisk` "Coho" (Sep-Nov) stamps the row at load, so the rating is capped at Fair and the sheet tells the reader to confirm.

Format: field | value | verdict | source + quote

1. months | best [10, 11], good [9] | SUPPORTED | Skagit coho were open into November in both recent years. 2025: https://wdfw.wa.gov/fishing/regulations/emergency-rules/skagit-river-coho-fishery-extended-through-nov-30-temporary-fishing-closure-set-portion-river-2025-10 : "Oct. 28-Nov. 30, 2025", reaches "From mouth to Gilligan Creek", "From Gilligan Creek to the mouth of the Baker River", "From Baker River to Cascade River Road (Marblemount Bridge)". 2024: https://wdfw.wa.gov/fishing/regulations/emergency-rules/skagit-river-coho-season-extended-through-dec-31-temporary-closure-scheduled-between-gilligan-creek-2024-10 (title: "Skagit River coho season extended through Dec. 31").
2. note: "closed it early on Nov. 19, 2025" | SUPPORTED | https://wdfw.wa.gov/fishing/regulations/emergency-rules/skagit-and-cascade-river-salmon-fisheries-close-nov19-2025-11 : effective "Nov. 19, 2025-Jan. 31, 2026", "Skagit River, from mouth to the Cascade River Rd. Bridge (Marblemount Bridge)", "Catch estimates indicate harvestable coho catch guidelines will be reached."
3. note: "mouth up to the Marblemount Bridge" | SUPPORTED | same pages. The row names the reach, so it stays true at a launch above the bridge: it says where the fishery is, not that the launch is in it.

## Not added

- **Bait, lure and time of day.** Nothing sourced this pass, so the field is left out rather than guessed.
- **2026 season dates.** WDFW had not published the 2026 Skagit coho package in the pages read. The Skagit wild coho forecast is reported up for 2026, which is why the fishery is likely, but the row claims timing only.
- **Skagit access points.** The app already draws every WDFW launch from layer 0 (Young's Bar, Lyman Ferry, Hamilton, Concrete, Marblemount and others), so a separate list would only duplicate it.
- **Other Skagit species** (chum, pink, steelhead). Not sourced this pass.
