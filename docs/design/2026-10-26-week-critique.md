# Design critique: five-tab site (2026-10-26)

Captures: local server, `?today=2026-10-26`, 30 PNGs named `<page>-<width>-<scheme>.png`
(widths 320/390/1024, light/dark). Reviewed: all 390 and 1024 captures, plus Week and Map at 320.
Fixed constraints (not findings): the Prime/Good/Fair/Slow rating ramp, the "guidance, not
regulation" lines and the WDFW links. The `design:design-critique` skill was not installed in
this session, so the critique uses the same lenses by hand: first read, usability, hierarchy,
consistency across tabs, and readability/accessibility. Contrast figures come from pixels
sampled in the captures.

## Overall read

The five tabs now feel like one site: the tab bar is the same everywhere, both schemes are
clean, and body text contrast is comfortable (muted text measures about 6:1 in both schemes).
The Week page has the right content, but its order and emphasis work against the question
it exists to answer, "where can I fish this week, and what changed?". On a phone the 7-day
tide table is the tallest thing on the page (about 1,000 px at 390), so the WDFW closure
notices sit below it at about 1,800 px. The empty "Reported this week" section is a dead
end, even though the Map tab shows "Cowlitz · Excellent" one tap away. And the tide table's
"next" highlight disappears when the next tide is a low. Among the older tabs, Counts is the
outlier: at 390 px the counts themselves are off-screen, and it ignores the other pages' layout.

## Findings, ranked by user impact

### Top 1: closures are buried below the tide table (Week)
- Seen in: `week-390-light/dark.png` (New rules starts at ~1,790 px of 2,896),
  `week-320-*.png` (lower still), `week-1024-*.png` (below the fold).
- What is wrong: the sections run Open now, Reported, **Tides**, New rules. The tide table
  has seven rows of three or four extremes each, so the rules section, which this week says
  the Hoh and Quillayute watersheds are *closed to all fishing*, sits two and a half screens down.
- Why it matters: a closure decides whether a trip happens at all. Tides only refine the
  timing of a trip that is already allowed. Someone skimming on a phone stops at the tides.
- Fix: mount tides after Coming up instead of after Reported. In `week/index.html`, change the
  anchor in `Tides.mount(root, document.getElementById('reported'), …)` to `'upcoming'`. The
  order becomes open, reported, rules, upcoming, tides, spots. Update the section-order
  expectation in `check-week.mjs` to match.
- Playwright assertion: at a 390×844 viewport with `?today=2026-10-26`,
  `#rules.offsetTop < #tides.offsetTop` **and** `#rules.getBoundingClientRect().top + scrollY <= 1300`.

### Top 2: "Reported this week: Nothing this week" contradicts the Map and links nowhere (Week, Map)
- Seen in: `week-390-*.png`, `week-1024-*.png` (empty row) against `map-390-*.png` and
  `map-1024-*.png` (Cowlitz · Excellent, Lower Columbia · Excellent, reports through Oct 17).
- What is wrong: the newest report is 9 days old, so the 7-day rule empties the section. The
  row doesn't say that, though, and it has no link. Week therefore offers no deep link into
  the map this week, which is the feature this release adds.
- Why it matters: "nothing" reads as "no fish" or "no data". Then the Map shows two
  Excellent rivers, and the user can't tell which tab to trust.
- Fix: when `res.reported` is empty, the empty row in `#reported` (built by `empty()` in
  `week.js`) reads "No reports in the last 7 days. Newest: Oct 17 (9 days old)." followed by a
  link "See reports on the map" to `../index.html?mode=reports`. `Week.build` exposes the
  newest `asOf` across `Reports.SITES` (for example `reportedNewest`). Add a unit test for the
  empty case.
- Playwright assertion: with `?today=2026-10-26`, `#reported li.empty a[href*="mode=reports"]`
  is present and `#reported li.empty` text contains `"Oct 17"`.

### Top 3: the "next tide" highlight vanishes when the next tide is a low (Week)
- Seen in: `week-390-light/dark.png` and `week-1024-*.png`, Mon Oct 26 row. "L 11:29 am · 5.6 ft"
  is bold but stays muted grey, so it looks *weaker* than the regular-weight H lines around it.
- What is wrong: CSS order bug in `week/index.html`. `table.tides .ex.next { color: var(--ink) }`
  (line 68) is overridden by `table.tides .ex.L { color: var(--soft) }` (line 69), which has
  the same specificity. Past extremes are not dimmed either, so nothing marks "now".
- Why it matters: bank and estuary anglers plan around the next change of tide. The one
  piece of emphasis the table offers points the wrong way half the time.
- Fix: make the rule `table.tides .ex.next, table.tides .ex.L.next { font-weight:700;
  color:var(--ink) }` and place it after the `.ex.L` rules. Optionally add the class `past`
  (with `opacity:.6`) to extremes before now in `Tides.render`.
- Playwright assertion: with the clock fixed to 2026-10-26 09:00 America/Los_Angeles and the
  tides route stubbed, there is exactly one `.ex.next`. Its computed `color` equals the computed
  color of `table.tides th` in a non-today row (rgb(29,29,31) light) and differs from
  `.ex.L:not(.next)`. Its contrast against the panel background is ≥ 12:1.

### 4. Counts on a phone hides the counts (Counts)
- Seen in: `counts-390-*.png`. Filter chips fill the first ~1,050 px. The table then shows only
  River and part of Species, and Anglers/Kept/Kept/100 sit off-screen with no scroll cue.
- Why it matters: the numbers are the only reason to open this tab.
- Fix: at ≤480 px, wrap the filter groups in a closed `<details>` ("Filters · 4 active"), make
  the River column sticky, and add a right-edge fade on the scroller.

### 5. Counts does not follow the site's page shell (Counts)
- Seen in: `counts-1024-*.png` vs `week/spots/year-1024-*.png`. It uses a full-bleed
  left-aligned layout, an all-caps title and monospace numerals. Its copy is
  developer-speak: "A mirror of salmon.db", "(not parsed)", "Showing 200 of 6089 rows (all of board)".
- Fix: use the same centred column and `h1` style as Week/Spots. Plain subtitle: "Weekly WDFW
  angler interviews, SW Washington. Counts people reported, not ratings." Rename "(not parsed)"
  to "Unclear species".

### 6. Tide rows wrap raggedly on desktop (Week)
- Seen in: `week-1024-*.png`. Three extremes on the first line and the fourth wrapped, so
  the times don't line up down the table.
- Fix: at ≥600 px, give `td` a `display:grid; grid-template-columns:repeat(4,1fr)` so each
  extreme has a fixed column.

### 7. Map overlays cover most of the map on phones (Map)
- Seen in: `map-390-*.png` (the panel plus legend cover ~55% of height) and `map-320-*.png`
  (about 170 px of usable map).
- Fix: collapse the legend to a "Key" button at ≤390 px. Hide the hint line "Tap any river…"
  after the first interaction.

### 8. Amber/orange used outside the rating ramp (Year, Week)
- Seen in: `year-*-*.png`. The "Open now" cards use a warm wash with an orange progress bar
  (the Good colour), and the calendar's orange Skagit bar means "selected". `week-*.png`: the
  "ends Oct 31 · 5 days" chip is red-orange on peach (contrast 4.63:1 light, just above the minimum).
- Fix: Year progress bars use `--accent` or a neutral colour. The Week chip adds the word "Ends soon".

### 9. Unexplained "Taste #3" chip (Week)
- Seen in: `week-*-*.png`, Open now rows. Week never says what Taste means (Year does).
- Fix: render "Taste #3 of 5" with `title="Taste order, richest first (see Year)"`.

### 10. Repeated generic link text (Week)
- Seen in: `week-*.png`, New rules. Every rule link reads "Read the rule".
- Fix: add `aria-label="Read the WDFW rule for Hoh River, Quillayute River…"`.

### 11. Small copy redundancies (Week)
- "TIDES · SEATTLE" repeats the picker value. Use the caption "Tides" and let the `<select>` name the station.
- The footer says "Seasons updated Oct 19. Seasons from Washington Fishing Year." Merge into
  "Seasons from Washington Fishing Year, updated Oct 19."

### 12. Open-now rows have no way onward (Week)
- Seen in: `week-*.png`. Skagit coho and Chum link only to WDFW sources. There is no link to
  Year's detail or to a map state. This is low impact while the map covers SW Washington only.
  File it with the Year-anchor follow-up already in TASKS.md.
