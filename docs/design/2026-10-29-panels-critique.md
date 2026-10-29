# Design critique: the map's side panels (2026-10-29)

Scope: the three panels that open beside or over the map on `Artifacts/salmon-rivers/`:
the Layers menu, the Key, and the site sheet (a 380 px side panel at 1280x800, a bottom
sheet at 390x844). Captured from the all-layers-on default (PR 110) in headless Chromium,
`?today=2026-10-27`. Not covered: the iOS app's sheets, and the page in Safari.

Two things in the captures are artifacts of the capture setup, not findings: the garbled
`Â·` (the capture's static server sent no charset) and a "Tap the map where you are"
prompt ghosting over the month card (headless Chromium has no location permission).

## Overall read

The site sheet is the strongest of the three: name and Done, one rating chip, Directions,
then dated "What's biting" cards and the creel week. The Layers menu and the Key are
correct but were sized for a default with two layers on. With six on, both are long
and neither helps you turn things back down.

## Findings, ranked by user impact

### 1. Layers menu has no way to turn everything off or back to default
- Six rows of 68 px make a 488 px panel, 61 percent of an 800 px window. With every layer
  on by default (PR 110), the menu is now how you reduce clutter, one toggle at a time.
- Fix: a header row with "All on" / "All off" (the page already writes `layers=none`).
  Order the rows to match the Key (reports first, then season layers, then sites).
- Assertion: with all six on, one tap on "All off" leaves `#layl` empty and the button
  reading "Layers".

### 2. The rules line is below the fold in the site sheet
- At 1280x800 the panel (776 px) ends inside the creel table; "Before you go: Rules change
  in season... Confirm this water's rules on WDFW" is after it, behind a scroll. The app
  never hides its guidance-not-regulation line; the page should not either.
- Fix: move the WDFW rules line directly under Directions, or pin it to the sheet's foot.
- Assertion: on Cowlitz at 1280x800 and 390x844, the WDFW line's top is inside the
  sheet's visible area without scrolling.

### 3. The Key lists all fourteen lines as one undifferentiated list
- 363 px tall with every layer on. Only the first group has a heading ("Recent catch
  reports"); the layer lines under it read as more of the same. Catch colours and
  neutral shapes are different kinds of mark, and the page's own rule is that they never
  share a reading.
- Fix: two headings, "Catch reports" (coloured) and "Layers" (neutral shapes), with the
  disclaimer line last.
- Assertion: the Key has two headings, and no layer line sits under "Recent catch reports".

### 4. Creel rows show "– kept · 4 released" when kept is not reported
- In the Cowlitz sheet, two rows read as a dash followed by "kept". The words "not
  reported" are in the markup but not on screen. A dash before a word reads as a glitch,
  and silence about missing data is the failure the project's rules warn about.
- Fix: show "Kept not reported · 4 released".
- Assertion: no creel row's visible text starts with a dash.

### 5. The bottom sheet on phones covers two thirds of the map
- At 390x844 the sheet is 557 px tall and sits at y 287; the river you tapped is behind
  it. Done is at the top right, away from the thumb.
- Fix: open at about half height with the header and rating chip, and expand on drag; or
  keep the tapped river's centre above the sheet's top edge.
- Assertion: after opening a river sheet at 390x844, the river's centre is above the
  sheet's top.

### 6. Reports, Typical and Spawning are modes and layers at once
- Typical season and Spawning appear in the mode switch and again in the Layers menu,
  where they draw neutral shapes over Reports. With all layers on, the same sites are
  drawn by a layer in Reports and by the mode itself.
- What the modes add is a month control and a colour ramp over the sites. That is why they
  are not just layers: catch colours and seasonal colours never share a view.
- Recommendation, not yet applied: merge Typical season and Spawning into one
  "Seasonal timing" mode with one month slider, keep Reports as the other mode, and keep the
  neutral-shape layers for the Reports view. Needs Daniel's decision.

## What works and should stay

- The site sheet's order and its dated chips (dashed when over a week old).
- Switch semantics on the Layers rows (`role="switch"`, `aria-checked`).
- "Layers add to the mode you are in. They never change a pin colour." at the menu's foot.
