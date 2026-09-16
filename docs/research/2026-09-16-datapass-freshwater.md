# Freshwater data pass: fisheries.json `freshwater` (checked 2026-09-16)

Species-presence counts below ("N/M lakes") come from the repo's own
`WAFishMap/Resources/lakes.json`, a snapshot of WDFW's FishWA lowland-lakes layer
(geodataservices.wdfw.wa.gov .../FishWA_2014_AllLakes_PROD). It is a 2014 snapshot:
fine for "common vs rare", not for exact current stocking.

Format: tier | species | field | current | proposed | verdict | source + quote

## WRONG

1. Baker Lake | Sockeye Salmon | note | "Baker Lake sockeye run on a WDFW trap-and-haul quota, so the fishery opens only when enough fish are passed above the dams." | "Opens on a set date each summer (July 11-Aug 31 in 2026); fish reach the lake by PSE's Baker River trap-and-haul. Confirm dates with WDFW." | WRONG | https://wdfw.wa.gov/fishing/reports/counts/baker-river : "Baker Lake will open for sockeye fishing July 11 through Aug. 31, with the opening occurring regardless of how many fish are in the lake."
2. Baker Lake | Sockeye Salmon | goodMonths | [6] | [] (best [7,8] is fine) | WRONG | same page: season opens July 11; June is closed.
3. Chelan | Chinook Salmon | note + row | "Upper Columbia summer runs." | move to marine/Columbia-mainstem handling or drop; not a county row | WRONG (scope) | The summer run is the Columbia mainstem (Rocky Reach-Chelan Falls-Wells). Lake Chelan/Lake Wenatchee launches get it too. https://wdfw.wa.gov/fishing/locations/lowland-lakes/lake-chelan : "landlocked Chinook are in relatively lower abundance ... occasionally and incidentally caught"
4. Chelan | Chinook Salmon | goodMonths | [6,9] | [9] | WRONG | https://wdfw.medium.com/summer-of-salmon-2024-5310d8426f01 (search excerpt): "the Chinook season has opened on July 1"; Rock Island-Wells "July 1 through Oct. 15".
5. King | Coho Salmon | row + bait | bait "Cut-plug herring or spinners, north end"; note "Fall run only in years the return supports it..." | remove from byCounty (Lake Washington/Sammamish basin + Green/Snoqualmie rivers only; "north end" names one lake) | WRONG (scope) | Shown at every King launch incl. Lake Dolloff, Angle Lake. WDFW 2026-09-15 rule change (via https://www.kirklandreporter.com/2026/09/15/no-fishing-for-coho-salmon-in-lake-washington/ ; counts https://wdfw.wa.gov/fishing/reports/counts/lake-washington): "fishing for coho salmon is closed until further notice, starting Sept. 16 ... north of the Highway 520 Bridge"
6. Snohomish | Smallmouth Bass | note | "Lowland lakes across the county." | drop row (statewide Largemouth already covers bass) | WRONG | WDFW lowland-lakes layer: smallmouth in 2/47 Snohomish lakes (largemouth 31/47, perch 18/47).
7. Spokane | Redband Trout | note + row | "Native redband trout in the county's rivers, catch-and-release..." | remove; this is the Spokane River fishery, already refused as byWaterbody on 2026-09-16 | WRONG (scope) | Shown at every Spokane launch incl. Medical, Clear, Liberty lakes. "the county's rivers" = one river whose rules change reach by reach (Upriver Dam section keeps hatchery rainbows; Little Spokane differs).
8. Stevens | Kokanee | note + bait | note "Trophy kokanee on the county's Columbia-system reservoirs; best in winter and spring."; bait "...near the dam" | remove from byCounty (Lake Roosevelt only; Loon/Deer Lake kokanee are a spring-summer lake fishery) | WRONG (scope) | Columbia-system reservoir in Stevens = Lake Roosevelt only. Note quoted.
9. Stevens | Kokanee | bestMonths | [1,2,3,11,12] | [5,6,7] with good [4,8,9,10] | WRONG | https://wdfw.wa.gov/fishing/locations/lowland-lakes/franklin-roosevelt-lake : "The Kokanee fishery typically lasts from April-October before the adults leave the lake to spawn"
10. Stevens | Walleye | note | "Columbia-system reservoirs; a mercury advisory applies - limit consumption." | remove from byCounty (advisory is Lake Roosevelt's) | WRONG (scope) | Walleye in 2/32 Stevens lowland lakes. Note quoted.
11. Stevens | Walleye | bestMonths/goodMonths | best [4,5,6], good [7,8] | best [5,6,7,8], good [3,9] | WRONG | franklin-roosevelt-lake page: "Fishing peaks before and after the spawn, with the spawning period (April) being more difficult. Summer fishing is excellent."
12. Stevens | Rainbow Trout | row (overrides statewide) | best [3,4,10,11], good [1,2,12]; note "Net-pen triploids on the county's Columbia-system reservoirs; best in cool months." | remove; statewide Rainbow row should apply | WRONG (scope) | Replaces the statewide rainbow at 28/32 Stevens trout lakes (Waitts, Rocky, etc.), rating May-June as off-season at lakes stocked for the 4th-Saturday-April opener. https://wdfw.wa.gov/newsroom/news-release/wdfw-opens-lowland-lakes-april-25-trout-derby-returns-900-prizes
13. Ferry | Kokanee | note + months | same as Stevens #8/#9 | remove | WRONG (scope + months) | Kokanee in 0/11 Ferry lowland lakes; Lake Roosevelt "April-October" (source #9).
14. Ferry | Walleye | note + months | same as Stevens #10/#11 | remove | WRONG (scope + months) | sources #10/#11.
15. Ferry | Rainbow Trout | row (overrides statewide) | same as Stevens #12 | remove | WRONG (scope) | Replaces statewide rainbow at Curlew/Ellen/Swan/Trout lakes.
16. Douglas | Rainbow Trout (triploid) | note + row | "Trophy triploids on the county's Columbia-system reservoirs; a cold-weather fishery - spring is poor."; bait "...near the net pens" | remove from byCounty (Rufus Woods only; one net-pen site) | WRONG (scope) | Shown at Jameson/Grimes lakes too. Also "spring is poor" contradicted: https://wdfw.medium.com/head-to-north-central-washington-for-winter-trout-fishing-1ebfff9030aa (search excerpt; page 403 to fetch): "Rufus Woods sport fishery ... in winter and early spring"
17. Douglas | Walleye | note + bait | "Good winter walleye on the county's Columbia-system reservoirs."; bait "...near the net pens" | remove from byCounty | WRONG (scope) | "near the net pens" names one reservoir. Walleye 2/9 Douglas lowland lakes.
18. Yakima | Smallmouth Bass | note + row | "The county's warm rivers; peaks at the spawn, good into fall." | remove | WRONG (scope) | Means the lower Yakima River; shown at Rimrock/Bumping launches. Smallmouth 0/27 Yakima lowland lakes. Also "good into fall" contested: https://www.yakimaherald.com/sports/outdoors/rob-phillips-smallmouth-bass-can-be-found-in-great-numbers-on-lower-yakima-river-this/article_d4f56284-fc11-11ee-9c2e-33b5c46dd11a.html : smallmouth "stay in the Yakima until late June or early July, when they migrate back into the Columbia River"
19. Kittitas | Rainbow Trout (wild) | note + row | "Wild river rainbows; catch-and-release, selective gear rules apply." | remove (Yakima River Keechelus-Roza only) | WRONG (scope) | "catch-and-release, selective gear" shown at stocked-lake launches (Easton, Mattoon, Cle Elum). Rule reach: Keechelus Dam to Roza Dam.
20. Kittitas | Cutthroat Trout | note + row | "Alpine lakes; best after ice-out through summer." | remove (overrides statewide cutthroat at Yakima River and lowland launches) | WRONG (scope) | Launches are lowland/river; cutthroat 0/22 Kittitas lowland lakes.

## UNSUPPORTED

21. statewide | Kokanee | row | present at every inland launch | consider dropping from statewide (keep via county/waterbody) | UNSUPPORTED | kokanee 65/653 lowland lakes statewide (10%). Note "Troll deeper as water warms." itself is fine.
22. statewide | Cutthroat Trout | row | every inland launch | none required; note 104/653, mostly westside | UNSUPPORTED (minor) | lakes.json counts.
23. Pierce | Rock Bass | note | "Uncommon statewide but established in this county's lowland lakes..." | drop, or "Present in a few of the county's lakes" | UNSUPPORTED | https://wdfw.wa.gov/species-habitats/species/ambloplites-rupestris lists Pierce: "American Lake, Lake Kapowsin, Spanaway Lake" (3/24 lakes); "none of the three is common in the state".
24. Thurston | Rock Bass | note | same text | same | UNSUPPORTED | same page, Thurston: "Black Lake, Long Lake, Pattison Lake, Ward Lake" (4/16).
25. Grant | Walleye | row | shown at all Grant launches; note "The county's big reservoirs" | acceptable (several reservoirs: Potholes, Moses, Banks, Billy Clapp) but rates walleye at 56 trout-only lakes | UNSUPPORTED | walleye 9/65 Grant lakes.
26. Grant / Okanogan | Smallmouth Bass | row (no note) | present county-wide | consider dropping | UNSUPPORTED | 7/65 Grant, 7/68 Okanogan lakes.
27. Yakima | Channel Catfish | row (no note) | county-wide | remove | UNSUPPORTED | 0/27 Yakima lowland lakes; fishery is lower Yakima River "downriver in Benton County" (yakimaherald / bestfishinginamerica excerpts).
28. Kittitas | Rainbow Trout (wild) | bestMonths | [7,8,9] | if kept anywhere: best spring+fall | UNSUPPORTED | Non-WDFW guide excerpt: low wadeable flows "usually occurs in spring and fall"; summer is irrigation high water.
29. Mason | Yellow Perch | note | "In the county's lowland lakes alongside the trout" | "In some of the county's lowland lakes" | UNSUPPORTED (minor) | perch 8/27 Mason lakes.

## OMISSION

30. statewide | Yellow Perch, Black Crappie | missing | add statewide rows (summer perch, spring crappie) | OMISSION | perch 200/653, crappie 134/653, both more common than kokanee (65).
31. Okanogan / Stevens | Brook Trout | missing | optional county row | OMISSION (minor) | brook trout 22/68 Okanogan, 13/32 Stevens.

## Re-checked, no change

- statewide Rainbow Trout months/note: WDFW "Spring fishing actually kicks off in March on year-round lakes and runs through the fourth Saturday in April opener and well into May" (wdfw.medium.com opener articles). OK.
- statewide Largemouth: OK.
- King / Pierce / Thurston Yellow Perch (25/49, 12/24, 12/16), Pierce Black Crappie (10/24) months and notes: OK.
- Chelan, Okanogan, Grant, Spokane Rainbow Trout rows: OK.
