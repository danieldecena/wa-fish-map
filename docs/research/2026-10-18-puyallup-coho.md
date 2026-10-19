# Data pass: Puyallup River coho, byWaterbody row (2026-10-18)

New row: `freshwater.byWaterbody["Puyallup River"]` = Coho Salmon, best [10], good [11].
Key is the exact river name in `rivers.json`. Weiss (50 m from the line) and Sumner Sportsmen's (143 m) are the WDFW launches that resolve to it, so `NoteScopeTests.everyWaterbodyRowIsReachable` should pass; distances were computed from the bundled `rivers.json` and `site/data/sites.json`, not by running the Swift tests (they cannot run on Linux).
`seasonRisk` "Coho" (Sep-Nov) stamps the row at load, so the rating is capped at Fair and the sheet tells the reader to confirm.

Format: field | value | verdict | source + quote

1. months | best [10], good [11] | SUPPORTED, thin | Two earlier seasons kept coho from October into December. 2016: https://wdfw.wa.gov/fishing/regulations/emergency-rules/puyallup-river-will-open-retention-hatchery-coho-2016-10 : "Oct.16, 2016 through Dec. 31, 2016", reach "from the 11th Street Bridge to the mouth of the Carbon River", hatchery coho may be retained. 2013: https://wdfw.wa.gov/fishing/regulations/emergency-rules/puyallup-river-oct-through-dec-fishing-seasons-set-2013-09 : "Oct. 1 to Dec. 31, 2013", coho among the species, minimum size 12 inches.
2. note: "the 2026 season is set to end Oct. 31" | SUPPORTED (proposal) | https://wdfw.wa.gov/sites/default/files/2026-04/2026-2027-proposed-recreational-puget-sound-freshwater-fisheries-updated-april-14-2026.pdf : Puyallup "Aug. 19 to Oct. 31 (closed Tuesdays Aug. 19 to Sept. 30)", "Release wild Chinook and chum." This is the April draft, not the final pamphlet.
3. note: "11th Street Bridge up to the Carbon River" | SUPPORTED | same pages. The row names the reach, so it stays true at a launch above or below it: it says where the fishery is, not that the launch is in it.

## Not added

- **September.** The 2026 draft opens Aug 19 but does not name coho for the Puyallup, and no source read this pass ties September to coho, so September is not in the months.
- **Bait, lure and time of day.** Nothing sourced this pass.
- **Green River.** Its rules change by reach (one reach closed to salmon, another opening Nov. 1), so a whole-river row would be false somewhere. Refused for the same reason as the Spokane.
- **Snoqualmie and Skykomish.** WDFW closed both for summer and fall 2026 (https://wdfw.medium.com/snohomish-basin-salmon-steelhead-fisheries-limited-to-protect-wild-chinook-2026-e0d1400a9f38). A coho row would send people to a closed river. Revisit if WDFW reopens them.
- **2026 limits.** The final rule text was not available in the pages read, so no limit is shown. The row claims timing only.

## Also in this PR: two Skagit launches added to `waterbodySites`

`waterbodySites["Skagit River"]` = ["Gilligan Creek", "Lyman Ferry"] (both copies of `fisheries.json`).
Why: a reach check against the bundled `rivers.json` put Gilligan Creek 230 m and Lyman Ferry 204 m from the Skagit line, past the 150 m match (`waterbodyMatchMeters`), so the Skagit coho row (PR #54) would not show at them. Spud House (88 m), Sedro-Woolley (135 m), Young's Bar (63 m), Hamilton (11 m) and Baker River (120 m) already match.
Curated list resolves before the geometry, per `FreshwaterGuide.waterbody(forFacility:at:rivers:)`. The names are the WDFW `FacilityName` values from `site/data/sites.json` ("Gilligan Creek", "Lyman Ferry").
Source for the sites being on the Skagit: WDFW's access layer lists them in Skagit County, and an angler thread on r/Bellingham names the WDFW lower-river sites (https://www.reddit.com/r/Bellingham/comments/cfvarf/skagit_river_trout_fishing/, search excerpt only; the thread itself was not readable). The distances were computed on Linux from the bundled files, not by running the Swift tests.
Not added: a McMillin Bridge trailhead on the Puyallup (Google Places, not a WDFW site). The app draws only WDFW layer 0 and 1 launches, so a non-WDFW point has nowhere to live without a new curated-sites list. That is a design decision, not a data pass.
