# Coast data pass (Areas 1, 2, 2-1, 2-2, 3, 4 + seasonRisk) - 2026-09-16

File: WAFishMap/Resources/fisheries.json (worktree wa-fish-map-lakes, HEAD 08dd6d8). Read-only.
Resolution note: `SpeciesSeason.resolvingSeasonRisk` UNIONS months of every matching row, so
"Chinook Salmon (ocean)" gets 6,7,8 + 7,8,9 = 6-9 and "Coho Salmon (ocean)" gets only 9,10,11.

## WRONG (contradicted by cited source)

1. Area 2-1 (Willapa Bay) / Fall Chinook / bestMonths+goodMonths
   - current: best [9], good [8,10]
   - proposed: best [8], good [9]
   - src: https://wdfw.wa.gov/fishing/locations/marine-areas/willapa-bay - "Willapa Bay is a very popular small boat fishery especially for large Chinook salmon ... Most fishing occurs in August and early September before the commercial fishery commences."

2. Areas 2-1 and 2-2 / Dungeness Crab / goodMonths (and best 9)
   - current: best [7,8,9], good [10]
   - proposed: best [7,8], good [6,9]  (Oct is pot-closed; Sept only through the 15th)
   - src: https://wdfw.wa.gov/fishing/shellfishing-regulations/crab - "Westport/Ocean Shores, Willapa Bay, Grays Harbor: Pots open Dec. 1 through Sept. 15; other gear year-round" and "pot gear season closes in several areas for a portion of September, October, and November to reduce soft-shell crab mortality."

3. Areas 1, 2, 2-2 / Razor Clams / bestTime
   - current: "Evening low tides (dig openers set by WDFW)" while bestMonths include 3 and goodMonths include 4
   - proposed: "Evening low tides Oct-mid-Mar, morning tides in spring (dig openers set by WDFW)"
   - src: https://wdfw.wa.gov/fishing/shellfishing-regulations/razor-clams - "The best low tides...always occurs during afternoon/evening (PM) hours in the fall and winter (between October and mid-March) and during morning (AM) tides in the spring (after mid-March)."

4. Area 1 / Buoy 10 Salmon (Columbia mouth) / goodMonths
   - current: good [7]
   - proposed: good [] (keep best [8,9]; Chinook retention ends Sep 2-3, hatchery coho continues into Sept)
   - src: https://wdfw.wa.gov/fishing/reports/creel/buoy10 - creel data every year starts "01-Aug... Opening Day"; 2026 Columbia summer/fall plan (https://wdfw.wa.gov/sites/default/files/2026-05/2026-wdfw-odfw-columbia-river-summer-fall-fishery-plan.pdf): Buoy 10 "open August 1 to September 2" for Chinook, "September 3 through December 31, retention of adult hatchery coho is allowed but Chinook retention will be closed."
   - caveat: July could be open under lower-Columbia summer rules in some years; no source shows a July Buoy 10 fishery, so at minimum UNSUPPORTED.

## UNSUPPORTED

5. seasonRisk "Coho" months [9,10,11] vs "Coho Salmon (ocean)" rows (Areas 1-4, best [8,9], good [7])
   - Ocean coho is quota-managed June 20-Sept 30 and Areas 3/4 close "until the ... marked coho subarea quota is met"; the row leaves Jul/Aug uncapped and caps Oct/Nov when the ocean is closed anyway.
   - proposed: add row {match: "Coho Salmon (ocean)", months: [7,8,9], reason: "Ocean coho quota can close areas in-season; confirm with WDFW"}
   - src: https://wdfw.wa.gov/newsroom/news-release/ocean-salmon-fishing-ilwaco-westport-ocean-shores-la-push-and-neah-bay-marine-areas-1-2-3-and-4 - areas "could close earlier if the respective guideline or quota is met."

6. seasonRisk "Halibut" months [4,5,6,7,8] - missing 9
   - All four coastal areas have in-season Aug/Sept openers (2026: Areas 1-2 Aug 8-Sep 30, Areas 3-4 Aug 16-Sep 30, seven days/week, if quota remains).
   - proposed: months [4,5,6,8,9] (July is closed on the coast; 7 adds nothing but is harmless)
   - src: https://wdfw.wa.gov/fishing/regulations/halibut/north-coast - "August 16 through September 30 (seven days per week)"; https://wdfw.wa.gov/fishing/regulations/halibut/columbia-river - "August 8 through September 30 (seven days per week)"; news release https://wdfw.wa.gov/newsroom/news-release/halibut-fishing-starts-april-2-puget-sound-marine-areas-and-april-30-coastal-marine-areas - "If quota remains after June 30, then the fishery may be open up to seven days per week in August and September."

7. seasonRisk "Crab" reason on coastal rows (2-1, 2-2)
   - reason "Season and areas set annually by WDFW" fits Puget Sound; coast is year-round with a fixed Sep 16-Nov 30 pot closure. Cap in 6-10 is harmless but the reason is wrong-shaped for the coast. Optional: per-row note "Pots closed Sept 16-Nov 30 on the south coast" instead.
   - src: crab page above.

8. seasonRisk "Rockfish" months [5,6,7] applied to coastal Black Rockfish (Areas 2, 3, 4)
   - Supported for Area 1 only ("copper, quillback, and vermilion rockfish possession is prohibited May-July" - columbia-river page). Black rockfish is open the whole bottomfish season Mar 14-Oct 17 (set annually, same as lingcod), so good months 4, 8, 9 escape the cap that Lingcod (3-10) gets.
   - proposed: add "Black Rockfish" months [3,4,5,6,7,8,9,10] reason "Coastal bottomfish season set annually; confirm dates" (or widen Rockfish row).
   - src: https://wdfw.wa.gov/fishing/regulations/halibut/south-coast - bottomfish "March 14 through Oct. 17, 2026".

9. Area 2-2 / Fall Chinook / note "marine area is often Chinook-release, best in the rivers"
   - Could not confirm 2026 2-2 Chinook rules (pamphlet-only; eRegulations 404). WDFW area page: "Chinook and coho are caught by mooching, trolling, and jigging inside the bay. Most fishing occurs in September and early October" - does not contradict, does not support "often Chinook-release". Verify against 2026-27 pamphlet before keeping.
   - src: https://wdfw.wa.gov/fishing/locations/marine-areas/grays-harbor

10. Area 2-2 / Razor Clams / note "Twin Harbors"
   - Twin Harbors runs "from Willapa Bay north to the south jetty at the mouth of Grays Harbor"; Copalis starts at the north jetty. Neither beach is inside Grays Harbor; both flank its mouth. Proposed note: "Twin Harbors (south of the harbor mouth) and Copalis (north); digs announced after toxin testing." Low priority.
   - src: razor clam page above.

## OMISSION (list only)

seasonRisk - set annually / in-season but matched by no row:
- "Buoy 10 Salmon (Columbia mouth)" (Area 1) - Chinook retention blocks and Sep 3 closure set annually (2026 plan above). Suggest months [8,9].
- "Fall Chinook" (Areas 2-1, 2-2) - does not contain "Chinook Salmon"; Willapa/Grays Harbor terminal seasons set annually in the pamphlet (North of Falcon). Suggest match "Fall Chinook" months [8,9,10].
- "Chum Salmon", "Pink Salmon" (other areas) - salmon seasons set annually; outside this scope, not checked.
- Kokanee/Walleye/trout etc. - freshwater, not checked. Albacore, Surfperch, Market Squid - no annual season; correctly unmatched.
- Razor Clams: spring digs run into May (2026: "final coastal razor clam digs of the spring season from April 30 through May 6"); neither goodMonths nor seasonRisk includes 5. https://wdfw.wa.gov/newsroom/news-release/wdfw-approves-final-coastal-razor-clam-digs-spring-season-april-30-through-may-6

Species rows:
- Area 1: no Halibut row (Columbia River subarea season Apr 30-Jun 28 + Aug 8-Sep 30).
- Area 1: no Black Rockfish row (bottomfish open Mar 14-Oct 17).
- Area 1 and 2-2 (Westport marina): no Dungeness Crab for Area 1 / Area 2 ocean (coast "Year-round").
- Area 2: no Surfperch (ocean beaches; Area 1 has it).
- Lingcod/Black Rockfish goodMonths omit March (season opens second Saturday in March) - minor.

Checked and fine: ocean Chinook/coho best/good months (season Jun 20-Sep 30 all four areas); Albacore; Areas 3/4 lingcod "summer depth limits" (20-fathom rule from June 1); yelloweye release-only; Halibut best 5 / good 6; razor clam beach names in Areas 1 and 2 (Long Beach; Twin Harbors/Copalis/Mocrocks all in Area 2); Grays Harbor Fall Chinook/Coho months (Sept-early Oct).
