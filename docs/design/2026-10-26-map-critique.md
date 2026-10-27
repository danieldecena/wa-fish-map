# Design critique: Washington Fishing Map, one-map page (2026-10-26)

Captures: local server on the repo at map version 33, `?today=2026-10-26`, 8 PNGs
(390x844 Reports light/dark, Typical, Spawning, a site sheet, a river sheet; 1024x768
Reports light, Typical dark). Positions below are measured from the DOM, not estimated.
Fixed constraints (not findings): the rating ramp, the guidance-not-regulation lines,
the WDFW links.

## Overall read

Desktop and dark mode are in good shape, and the sheets read well: name, one rating
chip, Directions, then what's biting with dated chips. The phone layout is where
the page breaks down: a blank control, a squeezed one, a map that sits in the
bottom half of the screen in two of the three modes, and Reports mode where the
coloured rivers compete with about 150 solid black layer glyphs.

## Findings, ranked by user impact

### 1. The Key button is an empty circle on phones (all modes)
- Seen in: `typical-390-light.png`, `spawning-390-light.png` (right end of the bar).
- Cause: the phone block shows the icon (`#keybtn .ki { display: block; }`, line 327,
  inside `@media (max-width: 520px)`), but a later rule outside any media query,
  `#keybtn .ki { display: none; }` (line 377), has the same specificity and wins on
  source order. The label is visually hidden on phones, so nothing is drawn.
- Fix: move the line-377 rule above the phone media block (or into
  `@media (min-width: 521px)`).
- Assertion: at 390 px, `#keybtn .ki` has a computed `display` other than `none` and a
  non-zero box.

### 2. Reports bar on a phone: the species button is 22 px wide and Key is off-screen
- Measured at 390: the bar scrolls (content 415 px in a 372 px box), the species
  button spans x 117 to 139 (22 px, under the 44 px target), and Key sits at x 372 to
  416, past the edge with no cue that the bar scrolls. Typical and Spawning fit
  (species 54 px), because Reports carries the extra Rivers button.
- Fix: let the species button keep its 44 px minimum (`min-width: 44px` or
  `flex-shrink: 0` on `#spbtn`) and fold Rivers into the Layers menu on phones, or
  show a right-edge fade when the bar scrolls.
- Assertion: at 390 in Reports, every bar control is at least 44 px wide and
  `bar.scrollWidth <= bar.clientWidth`.

### 3. Typical and Spawning on a phone: the state sits in the bottom half
- Measured at 390x844: Washington spans y 450 to 691, so about 380 px of empty
  background sits above it (Reports, with its glance panel, starts at y 271). The
  fit appears to reserve space for a top panel that these modes do not show.
- Fix: in the initial fit, reserve only the height of panels actually visible.
- Assertion: at 390x844 in Typical, the state's vertical centre is within 60 px of
  the visible map area's centre.

### 4. Reports on a phone: the "at a glance" panel covers the top third of the map
- Seen in: `reports-390-*.png`. The panel runs to y 297 and is open on load; the
  Skagit report pin sits right under its bottom edge, and the panel itself is cut
  off on the right ("2 seas...").
- Fix: start it collapsed to its one-line summary on phones (the counts row), with
  the month chart on tap.

### 5. Layer glyphs out-shout the catch reports (Reports mode)
- Seen in: `reports-1024-light.png`, `reports-390-*.png`. The two default layers
  draw about 150 solid black squares, circles and diamonds. The mode's subject, nine
  coloured report rivers, is lighter on the page than the reference layers.
- Fix: draw layer glyphs as mid-grey outlines (or at reduced opacity) so they sit
  behind the coloured rivers, keeping their shapes for the key.

### 6. Desktop Typical: pins slide under the control bar
- Seen in: `typical-1024-dark.png`. "Silver Lake · Prime" and two pins at the top
  edge are clipped by the bar. The fit uses the full window height, not the area
  below the bar.
- Fix: pad the fit's top by the bar's height.

### 7. Smaller items
- The Layers button's text reads "Layers · 22" to a screen reader (the hidden
  label "Layers · 2" plus the visible count "2").
- A selected site's label can sit under a neighbouring pin (`site-390-light.png`,
  "Sedro-Woolley · Good").

## What works and should stay

- Sheets: clear order, one rating chip, dated report chips, honest "Release only"
  and "9 days ago" labels.
- Dark mode: muted basemap, coloured rivers and pins stay readable.
- The "Most sites rate the same this month" hint answers the obvious question about
  a map of mostly identical colours.
